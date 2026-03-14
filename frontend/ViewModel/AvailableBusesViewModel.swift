import SwiftUI
import Combine
import CoreLocation


class AvailableBusesViewModel: ObservableObject {

    // MARK: - SortOption
    enum SortOption: String, CaseIterable {
        case departureTime = "Departure Time"
        case duration = "Duration"
    }

    @Published var sortOption: SortOption = .departureTime
    @Published var allRoutes: [RouteModel] = []
    @Published var errorText: String? = nil
    @Published var buses: [Bus] = [] // Kept for compatibility if needed, but using visibleBuses for list

    // List Optimization (Lazy Loading)
    @Published var visibleBuses: [Bus] = []
    private var allFilteredBuses: [Bus] = []
    private let pageSize = 5
    private var currentPage = 1

    // Real-time Trackers
    @Published var liveBusesOnRoute: [Bus] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Filters
    @Published var showOnTime = true
    @Published var showDelayed = true

    init() {
        setupBusesSubscriber()
    }
    
    private func setupBusesSubscriber() {
        BusRepository.shared.$buses
            .receive(on: RunLoop.main)
            .sink { [weak self] allBuses in
                self?.filterLiveBusesForRoute(allBuses)
            }
            .store(in: &cancellables)
    }
    
    private func filterLiveBusesForRoute(_ allGlobalBuses: [Bus]) {
        // Filter buses that are actually on the route being viewed
        // Using headsign or route number if possible
        // This makes sure markers only show for relevant buses
        self.liveBusesOnRoute = allGlobalBuses.filter { bus in
            // Basic matching: either number matches or headsign contains keywords
            let isRelevant = bus.number == self.allRoutes.first?.route_id || 
                            bus.headsign.localizedCaseInsensitiveContains(self.allRoutes.first?.name ?? "")
            return isRelevant && bus.isRunning
        }
    }

    // Route Visualization Data
    @Published var routePolyline: [CLLocationCoordinate2D] = []
    @Published var estimatedDistance: String? = nil
    @Published var estimatedTime: String? = nil



    // Firebase ref removed

    func load(from: String, to: String, fromID: String? = nil, toID: String? = nil, fromCoord: CLLocationCoordinate2D? = nil, toCoord: CLLocationCoordinate2D? = nil, via: String? = nil) {
        Task { @MainActor in
            self.buses = []
            self.errorText = nil
            
            // 0. Prefetch live data for this specific route if via is provided
            if let via {
                _ = try? await APIService.shared.fetchBuses(forRoute: via)
            }
            
            // 4. Calculate Road-Snapped Route (Start early with passed coords)
            let (resolvedFrom, resolvedTo) = await calculateRoute(from: from, to: to, fromID: fromID, toID: toID, passedFrom: fromCoord, passedTo: toCoord)
            do {
                var searchResults: [SearchTrip]? = nil

                // 1. Try backend name-based search first (/api/routes/search)
                //    This works without needing a stop ID — just the text the user typed.
                if via == nil {
                    do {
                        let nameResults = try await APIService.shared.fetchRoutesSearch(fromName: from, toName: to)
                        if !nameResults.isEmpty {
                            searchResults = nameResults
                            print("Name-based /api/routes/search found \(nameResults.count) trips")
                        }
                    } catch {
                        print("Name-based search failed, falling back: \(error)")
                    }
                }

                // 2. If name-based had no results, try stop-ID based search (Delhi/legacy)
                if searchResults == nil || searchResults!.isEmpty {
                    let routeId = via ?? "20"
                    let stops = try await APIService.shared.fetchStops(routeId: routeId, dir: "Eastbound")

                    let fromStop = stops.first(where: {
                        (fromID != nil && $0.id == fromID) ||
                        (fromID == nil && ($0.name.localizedCaseInsensitiveContains(from) || from.localizedCaseInsensitiveContains($0.name)))
                    })
                    let toStop = stops.first(where: {
                        (toID != nil && $0.id == toID) ||
                        (toID == nil && ($0.name.localizedCaseInsensitiveContains(to) || to.localizedCaseInsensitiveContains($0.name)))
                    })

                    if let fs = fromStop, let ts = toStop {
                        // Save to backend recent searches
                        Task {
                            let user = SessionManager.shared.currentUser
                            let role = SessionManager.shared.userRole ?? "student"
                            print("Saving recent search: \(fs.name) (\(fs.id)) -> \(ts.name) (\(ts.id)) for user \(user?.id ?? 0)")
                            try? await APIService.shared.saveRecentSearch(fromStopId: fs.id, toStopId: ts.id, fromName: fs.name, toName: ts.name, userId: user?.id)
                        }

                        // Fetch search trips (Live/FastAPI)
                        do {
                            if let via {
                                searchResults = try await APIService.shared.searchRealtime(routeId: via, fromStopId: fs.id)
                            } else {
                                searchResults = try await APIService.shared.searchTrips(fromStopId: fs.id, toStopId: ts.id)
                            }
                        } catch {
                            print("Search API Error: \(error)")
                        }
                    }
                }
                
                if searchResults == nil || searchResults!.isEmpty {
                    if let start = resolvedFrom, let end = resolvedTo {
                         print("Trying RouteDiscoveryService fallback with resolved coords...")
                         if let matches = try? await RouteDiscoveryService.shared.findRoutes(from: start, to: end), !matches.isEmpty {
                             searchResults = matches.map { m in
                                 SearchTrip(
                                     tripId: m.bus.tripId,
                                     extTripId: m.bus.extTripId,
                                     busId: m.bus.busId,
                                     busNo: m.bus.busNo,
                                     label: m.bus.routeName,
                                     routeId: m.bus.routeId ?? 0,
                                     routeName: m.bus.routeName,
                                     extRouteId: m.bus.extRouteId,
                                     fromDeparture: nil,
                                     toArrival: nil,
                                     durationMinutes: m.bus.durationMinutes, // Map duration appropriately
                                     status: "Live",
                                     busLiveLocation: nil,
                                     nextStopName: nil,
                                     currentStopName: nil
                                 )
                             }
                         }
                    }
                }
                
                if searchResults == nil || searchResults!.isEmpty {
                    print("Found no live/scheduled buses via API, checking local repository...")
                    
                    let fromSearch = from.lowercased().trimmingCharacters(in: .whitespaces)
                    let toSearch = to.lowercased().trimmingCharacters(in: .whitespaces)

                    // Fallback to local repo if API fails or returns nothing
                    let repoBuses = BusRepository.shared.allBuses.filter { bus in
                        let searchByRoute = (via != nil && (bus.number.lowercased() == via!.lowercased() || (bus.headsign.lowercased().contains(via!.lowercased()))))
                        
                        let stops = bus.route.stops
                        let hasFrom = stops.contains { s in
                            let sName = s.name.lowercased()
                            return sName.contains(fromSearch) || fromSearch.contains(sName)
                        }
                        let hasTo = stops.contains { s in
                            let sName = s.name.lowercased()
                            return sName.contains(toSearch) || toSearch.contains(sName)
                        }
                        let isNotCompleted = bus.statusDetail?.lowercased() != "completed" && bus.statusDetail?.lowercased() != "ended" && bus.trackingStatus != .ended && !bus.hasReachedDestination
                        return (searchByRoute || (hasFrom && hasTo)) && isNotCompleted
                    }
                    
                    if repoBuses.isEmpty {
                        self.errorText = "No buses found for this route (\(from) to \(to)). Please ensure the server has seeded schedules or try different stops."
                        return
                    }
                    
                    self.buses = repoBuses
                    return
                }
                
                let results = searchResults!
                
                // 3. Map SearchTrip to Bus
                var loadedBuses: [Bus] = []
                for trip in results {
                    var departsAtStr = "--"
                    if let depTime = trip.fromDeparture {
                        let ds = depTime.replacingOccurrences(of: "Z", with: "")
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        var date = formatter.date(from: depTime)
                        if date == nil {
                            formatter.formatOptions = [.withInternetDateTime]
                            date = formatter.date(from: depTime)
                        }
                        if date == nil {
                            let f = DateFormatter()
                            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                            f.locale = Locale(identifier: "en_US_POSIX")
                            date = f.date(from: ds)
                        }
                        
                        if let d = date {
                            let tf = DateFormatter()
                            tf.timeZone = TimeZone(identifier: "America/Chicago")
                            tf.dateFormat = "hh:mm a"
                            departsAtStr = tf.string(from: d)
                        } else {
                            let parts = depTime.components(separatedBy: "T")
                            if parts.count > 1 {
                                let timeParts = parts[1].components(separatedBy: ":")
                                if timeParts.count >= 2, let hr = Int(timeParts[0]) {
                                    let ampm = hr >= 12 ? "PM" : "AM"
                                    let hr12 = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
                                    departsAtStr = String(format: "%02d:%@ %@", hr12, timeParts[1], ampm)
                                }
                            }
                        }
                    }
                    
                    let existingId = BusRepository.shared.allBuses.first(where: { 
                        $0.extTripId == trip.extTripId || ($0.vehicleId != nil && $0.vehicleId == trip.tripId)
                    })?.id ?? UUID()
                    
                    let bus = Bus(
                        id: existingId,
                        number: trip.busNo ?? trip.extRouteId ?? "Transit",
                        headsign: trip.label ?? trip.routeName ?? "Transit Bus",
                        departsAt: departsAtStr,
                        durationText: "\(trip.durationMinutes ?? 0)m",
                        status: .onTime,
                        statusDetail: trip.status?.capitalized ?? "Live",
                        trackingStatus: TrackingStatus(rawValue: trip.status?.capitalized ?? "Running") ?? .arriving,
                        etaMinutes: trip.durationMinutes,
                        route: Route(from: from, to: to, stops: []), // Stops load lazily now
                        vehicleId: trip.tripId,
                        busId: trip.busId,
                        extTripId: trip.extTripId,
                        currentStopName: trip.currentStopName,
                        nextStopName: trip.nextStopName
                    )
                    
                    // Filter out completed trips
                    let isCompleted = bus.statusDetail?.lowercased() == "completed" || bus.statusDetail?.lowercased() == "ended" || bus.trackingStatus == .ended || bus.hasReachedDestination
                    if !isCompleted {
                        BusRepository.shared.register(bus: bus)
                        loadedBuses.append(bus)
                    }
                }
                
                let activeBuses = loadedBuses.filter { $0.trackingStatus != .arriving } // Simplified check
                let offlineBuses = loadedBuses.filter { $0.trackingStatus == .scheduled }
                self.buses = activeBuses + offlineBuses
                
                self.updateFiltering()
            } catch let error as APIError {
                self.errorText = error.errorDescription ?? "Connection failed"
            } catch {
                self.errorText = error.localizedDescription
            }
        }
    }

    @MainActor
    private func calculateRoute(from: String, to: String, fromID: String?, toID: String?, passedFrom: CLLocationCoordinate2D? = nil, passedTo: CLLocationCoordinate2D? = nil) async -> (CLLocationCoordinate2D?, CLLocationCoordinate2D?) {
        // Need to find coordinate for from and to
        // Check repo or API for coordinates
        var fromCoord: CLLocationCoordinate2D? = passedFrom
        var toCoord: CLLocationCoordinate2D? = passedTo
        
        // 1. Try to find in already loaded buses if not passed
        if fromCoord == nil || toCoord == nil {
            if let firstBusWithRoute = buses.first(where: { !$0.route.stops.isEmpty }) {
                let stops = firstBusWithRoute.route.stops
                fromCoord = stops.first(where: { $0.id == fromID || $0.name.localizedCaseInsensitiveContains(from) })?.coordinate.cl
                toCoord = stops.first(where: { $0.id == toID || $0.name.localizedCaseInsensitiveContains(to) })?.coordinate.cl
            }
        }
        
        // 2. If not found, try fetching stops from API (if possible) or look through repository
        if fromCoord == nil || toCoord == nil {
            let allStops = BusRepository.shared.allBuses.flatMap { $0.route.stops }
            
            if fromCoord == nil {
                fromCoord = allStops.first(where: { $0.name.localizedCaseInsensitiveContains(from) || from.localizedCaseInsensitiveContains($0.name) })?.coordinate.cl
            }
            if toCoord == nil {
                toCoord = allStops.first(where: { $0.name.localizedCaseInsensitiveContains(to) || to.localizedCaseInsensitiveContains($0.name) })?.coordinate.cl
            }
        }
        
        // 3. Last fallback: Try to get from current location if 'from' is current/near
        if fromCoord == nil && (from.lowercased().contains("current") || from.lowercased().contains("my loc")) {
            fromCoord = LocationManager.shared.userLocation?.coordinate
        }

        
        guard let start = fromCoord, let end = toCoord else { 
            print("Routing: Coordinates not found for \(from) -> \(to)")
            return (fromCoord, toCoord)
        }
        
        do {
            let result = try await RoutingService.shared.calculateRoute(from: start, to: end)
            self.routePolyline = result.polyline
            self.estimatedDistance = String(format: "%.1f km", result.distanceMeters / 1000.0)
            let mins = result.travelTimeSeconds / 60.0
            self.estimatedTime = String(format: "%.0f min", mins)
            
            // Update individual buses with this accurate estimation
            let roundedMins = Int(mins)
            for i in 0..<self.buses.count {
                self.buses[i].etaMinutes = roundedMins
                self.buses[i].durationText = "\(roundedMins)m"
            }
            updateFiltering()
            
        } catch {
            print("Routing: Failed to calculate route: \(error)")
        }
        
        return (start, end)
    }




    func loadMore() {
        guard visibleBuses.count < allFilteredBuses.count else { return }
        
        let nextIndex = currentPage * pageSize
        let remainingSize = allFilteredBuses.count - nextIndex
        let countToLoad = min(pageSize, remainingSize)
        
        if countToLoad > 0 {
            let nextBatch = allFilteredBuses[nextIndex..<(nextIndex + countToLoad)]
            visibleBuses.append(contentsOf: nextBatch)
            currentPage += 1
        }
    }
    
    func updateFiltering() {
        var result = buses
        if !showOnTime  { result = result.filter { $0.status != .onTime } }
        if !showDelayed { result = result.filter { $0.status != .delayed } }
        
        switch sortOption {
        case .departureTime: result.sort { $0.departsAt < $1.departsAt }
        case .duration:      result.sort { $0.durationText < $1.durationText }
        }
        
        self.allFilteredBuses = result
        self.currentPage = 1
        self.visibleBuses = Array(self.allFilteredBuses.prefix(pageSize))
    }

    func applyFilterState(from: String, to: String, fromID: String? = nil, toID: String? = nil, fromCoord: CLLocationCoordinate2D? = nil, toCoord: CLLocationCoordinate2D? = nil, via: String? = nil) {
        updateFiltering()
    }
}
