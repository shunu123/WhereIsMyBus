import Foundation
import Combine
import SwiftUI
import CoreLocation
import MapKit

@MainActor
final class LiveTrackingViewModel: ObservableObject {
    @Published var bus: Bus

    @Published var traveledPath: [Coord] = []
    @Published var fullRoutePath: [Coord] = []
    @Published var currentIndex: Double = 0.0
    @Published var autoRecenter: Bool = true
    @Published var isLive: Bool = true
    @Published var isHistorical: Bool = false {
        didSet { loadHistoryData() }
    }
    @Published var selectedDate: Date = Date() {
        didSet { loadHistoryData() }
    }
    @Published var isHistoryEmpty: Bool = false
    @Published var isHistoryScheduled: Bool = false
    @Published var showScheduledStopsOnly: Bool = false {
        didSet { if showScheduledStopsOnly { populateScheduledHistory() } }
    }
    @Published var historyTripStatus: String? = nil
    @Published var historySearchRange: String? = nil
    @Published var currentSpeed: Int = 0
    @Published var speedKmph: Int? = nil // Requirement B: Live speed
    @Published var lastStopTime: String = "--:--"
    @Published var nearestStopName: String = ""
    @Published var nextStopName: String = ""
    
    var plannedPolyline: [Coord] {
        return fullRoutePath
    }

    var actualPolyline: [Coord] {
        let busToTrack = selectedBusForDetail ?? bus
        if busToTrack.id == bus.id {
            return traveledPath
        } else {
            let stopsCount = max(1, displayedStops.count)
            let pointsPerStop = Double(fullRoutePath.count) / Double(stopsCount)
            let stopIdx = busToTrack.currentStopIndex
            let count = Int(Double(stopIdx) * pointsPerStop)
            return Array(fullRoutePath.prefix(max(0, count)))
        }
    }

    // Phase 5: Dynamic Pin Detection
    var deviationStartCoord: Coord? {
        // First point of the first off-route segment
        return actualOffRouteSegments.first?.coords.first
    }

    var rejoiningCoord: Coord? {
        // First point of the last on-route segment, IF there was an off-route segment before it
        guard let firstOffEnd = actualOffRouteSegments.last?.coords.last else { return nil }
        // Find the first on-route point AFTER the last off-route point
        let onSegments = actualOnRouteSegments
        for seg in onSegments {
            if let first = seg.coords.first, actualPolyline.firstIndex(where: { $0.id == first.id }) ?? 0 > actualPolyline.firstIndex(where: { $0.id == firstOffEnd.id }) ?? 0 {
                return first
            }
        }
        return nil
    }
    
    var deviationStartStopIndex: Int? {
        guard let start = deviationStartCoord else { return nil }
        return bus.route.stops.enumerated().min(by: { 
            distance($0.element.coordinate, start) < distance($1.element.coordinate, start)
        })?.offset
    }
    
    @Published var displayedStops: [Stop] = [] { // Source-relative stops
        didSet {
            // Re-snap whenever stops change (e.g. async backend load)
            let stopsSnapshot = displayedStops
            Task {
                let snapped = await RoadSnapService.shared.snap(stops: stopsSnapshot)
                await MainActor.run {
                    self.fullRoutePath = snapped
                    print("Road snap updated: \(snapped.count) pts for \(stopsSnapshot.count) stops")
                }
            }
        }
    }

    @Published var otherBuses: [Bus] = []
    private var otherBusIndices: [Double] = []

    @Published var showUpcoming: Bool = true
    @Published var showDeparted: Bool = true
    @Published var showScheduled: Bool = false
    
    // alarm
    @Published var alarmStopName: String = ""
    @Published var alarmStopsBefore: Int = 2
    @Published var alarmEnabled: Bool = false
    private var wsSubscription: AnyCancellable?
    
    @Published var selectedBusForDetail: Bus?
    
    let sourceCoord: Coord?
    let destinationCoord: Coord?
    private let sourceStop: String?
    private let destinationStop: String?
    var isIsolatedMode: Bool {
        selectedBusForDetail?.isDeviated ?? false
    }

    var reachedStops: [Stop] {
        let busToTrack = selectedBusForDetail ?? bus
        let stopsCount = max(1, displayedStops.count)
        let idx = (busToTrack.id == bus.id) ? Int(currentIndex) : (busToTrack.currentStopIndex * Int(Double(fullRoutePath.count) / Double(stopsCount)))
        let pointsPerStop = Double(fullRoutePath.count) / Double(stopsCount)
        let currentStopIdxInt = pointsPerStop > 0 ? Int(Double(idx) / pointsPerStop) : 0
        return Array(displayedStops.prefix(currentStopIdxInt + 1))
    }

    @Published var actualOnRouteSegments: [PathSegment] = []
    @Published var actualOffRouteSegments: [PathSegment] = []

    private func updatePathSegments() {
        let fullRoute = fullRoutePath
        let actualPath = traveledPath
        guard !actualPath.isEmpty else { 
            actualOnRouteSegments = []
            actualOffRouteSegments = []
            return 
        }
        
        // Use a simpler approach for segment calculation
        var onSegs: [PathSegment] = []
        var offSegs: [PathSegment] = []
        
        var currentOnCoords: [Coord] = []
        var currentOffCoords: [Coord] = []
        
        let tolerance = 0.0005 // Approx 50 meters
        
        for coord in actualPath {
            let isOffRoute = !fullRoute.contains(where: { abs($0.lat - coord.lat) < tolerance && abs($0.lon - coord.lon) < tolerance })
            
            if isOffRoute {
                if !currentOnCoords.isEmpty {
                    onSegs.append(PathSegment(coords: currentOnCoords, isDiverted: false))
                    currentOnCoords = []
                }
                currentOffCoords.append(coord)
            } else {
                if !currentOffCoords.isEmpty {
                    offSegs.append(PathSegment(coords: currentOffCoords, isDiverted: true))
                    currentOffCoords = []
                }
                currentOnCoords.append(coord)
            }
        }
        
        if !currentOnCoords.isEmpty { onSegs.append(PathSegment(coords: currentOnCoords, isDiverted: false)) }
        if !currentOffCoords.isEmpty { offSegs.append(PathSegment(coords: currentOffCoords, isDiverted: true)) }
        
        self.actualOnRouteSegments = onSegs
        self.actualOffRouteSegments = offSegs
    }

    private var timer: Timer?
    private var haltTicks: Int = 0

    var isFuture: Bool {
        Calendar.current.startOfDay(for: selectedDate) > Calendar.current.startOfDay(for: Date())
    }

    init(bus: Bus, isHistorical: Bool = false, date: Date? = nil, sourceStop: String? = nil, destinationStop: String? = nil, sourceCoord: Coord? = nil, destinationCoord: Coord? = nil) {
        self.bus = bus
        self.sourceStop = sourceStop
        self.destinationStop = destinationStop
        self.sourceCoord = sourceCoord
        self.destinationCoord = destinationCoord
        self.selectedDate = date ?? Date()
        
        // 1. Filter stops relative to source and destination if provided
        var displayStops = bus.route.stops
        if let source = sourceStop, let destination = destinationStop {
            displayStops = bus.stopsFromTo(sourceName: source, destinationName: destination)
        } else if let source = sourceStop {
            displayStops = bus.stopsFrom(sourceName: source)
        }
        self.displayedStops = displayStops
        
        // 2. Build path from relevant stops only
        let plannedPath = TrackingSimulationService.shared.buildPath(stops: displayStops)
        self.bus.route.plannedPolyline = plannedPath
        
        let path = plannedPath
        
        self.fullRoutePath = path
        if isHistorical || isFuture {
            self.traveledPath = isFuture ? [] : path
            let maxIndex = max(0, path.count - 1)
            self.currentIndex = isFuture ? 0.0 : Double(maxIndex)
        } else {
            self.traveledPath = []
            self.currentIndex = 0.0
            
            // Load other buses on the same route
            let all = BusRepository.shared.allBuses
            self.otherBuses = all.filter { b in
                b.id != bus.id && 
                b.route.from == bus.route.from && 
                b.route.to == bus.route.to &&
                b.trackingStatus != .scheduled && b.trackingStatus != .ended
            }
            self.otherBusIndices = Array(repeating: 0.0, count: self.otherBuses.count)
        }
        
        loadHistoryData()
        
        if self.bus.route.stops.isEmpty {
            print("LiveTrackingViewModel: Stops empty, fetching timeline...")
            loadTimelineIfNeeded()
        } else {
            // Trigger road snapping after loading stops
            print("LiveTrackingViewModel: Stops exist (\(self.bus.route.stops.count)), snapping...")
            snapToRoads()
            // Even if stops exist, refresh timeline to ensure it's up to date
            loadTimelineIfNeeded()
        }
    }

    private func snapToRoads() {
        let stopsSnapshot = displayedStops
        Task {
            let snapped = await RoadSnapService.shared.snap(stops: stopsSnapshot)
            await MainActor.run {
                if !snapped.isEmpty {
                    self.fullRoutePath = snapped
                    print("Road snapping success: \(snapped.count) points")
                }
            }
        }
    }
    
    private func loadTimelineIfNeeded() {
        Task {
            do {
                print("LiveTrackingViewModel: Fetching timeline for trip \(bus.vehicleId ?? 0) (ext: \(bus.extTripId ?? "nil"))...")
                let timelineStops = try await APIService.shared.fetchTimeline(tripId: bus.vehicleId, extTripId: bus.extTripId)
                print("LiveTrackingViewModel: Successfully fetched \(timelineStops.count) stops from timeline.")
                
                var newStops: [Stop] = []
                if timelineStops.isEmpty {
                    print("LiveTrackingViewModel: Timeline stops are empty.")
                    newStops = []
                } else {
                    newStops = timelineStops.sorted { $0.stopOrder < $1.stopOrder }.map { $0.toStop() }
                    print("LiveTrackingViewModel: Parsed \(newStops.count) stops into ViewModel.")
                }
                
                await MainActor.run {
                    self.bus.route.stops = newStops
                    
                    // Re-filter displayedStops
                    var displayStops = self.bus.route.stops
                    if let source = self.sourceStop, let destination = self.destinationStop {
                        displayStops = self.bus.stopsFromTo(sourceName: source, destinationName: destination)
                    } else if let source = self.sourceStop {
                        displayStops = self.bus.stopsFrom(sourceName: source)
                    }
                    self.displayedStops = displayStops
                    
                    // Repopulate historyStops now that we have real stops
                    if !self.isHistorical {
                        self.bus.historyStops = displayStops.map { HistoryStop(stopName: $0.name, reachedTime: nil) }
                    }
                    
                    // Re-build planned path
                    let plannedPath = TrackingSimulationService.shared.buildPath(stops: displayStops)
                    self.bus.route.plannedPolyline = plannedPath
                    
                    let path = plannedPath
                    
                    self.fullRoutePath = path
                    if !self.isHistorical && !self.isFuture {
                        self.traveledPath = []
                        self.currentIndex = 0.0
                    } else {
                        self.traveledPath = self.isFuture ? [] : path
                        self.currentIndex = self.isFuture ? 0.0 : Double(max(0, path.count - 1))
                    }
                    
                    self.snapToRoads()
                    
                    // Cache the stops globally so other views don't have to refetch
                    BusRepository.shared.register(bus: self.bus)
                }
            } catch {
                print("Failed to load timeline for bus \(self.bus.number):", error)
                // Fallback: If fetch fails, but we have original stops, don't clear them
                await MainActor.run {
                    if self.displayedStops.isEmpty && !self.bus.route.stops.isEmpty {
                        self.displayedStops = self.bus.route.stops
                        self.snapToRoads()
                    }
                }
            }
        }
    }

    private func populateScheduledHistory() {
        let stopsToTrack = self.displayedStops.isEmpty ? self.bus.route.stops : self.displayedStops
        self.bus.historyStops = stopsToTrack.map { HistoryStop(stopName: $0.name, reachedTime: nil) }
        self.fullRoutePath = TrackingSimulationService.shared.buildPath(stops: stopsToTrack)
        self.traveledPath = []
        self.currentIndex = 0
    }

    private func loadHistoryData() {
        self.selectedBusForDetail = nil // Requirement: History mode tracks primary bus only
        self.showScheduledStopsOnly = false
        
        // Force live mode if today is selected
        if Calendar.current.isDateInToday(self.selectedDate) && isHistorical {
            self.isHistorical = false
            return
        }
        
        if isHistorical {
            // 1. Calculate IST Range (Requirement: 00:00:00 to 23:59:59 IST)
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: self.selectedDate)
            components.hour = 0
            components.minute = 0
            components.second = 0
            let start = calendar.date(from: components) ?? self.selectedDate
            components.hour = 23
            components.minute = 59
            components.second = 59
            let end = calendar.date(from: components) ?? self.selectedDate
            
            let df = DateFormatter()
            df.dateFormat = "MMM dd, HH:mm"
            self.historySearchRange = "\(df.string(from: start)) — \(df.string(from: end))"
            
            // 2. Check Schedule (Simulated: Scheduled for weekdays)
            // 3. Fetch History Record from Backend
            guard let tripId = bus.vehicleId else {
                self.isHistoryEmpty = true
                return
            }
            
            Task {
                do {
                    let gpsPoints = try await APIService.shared.fetchTripHistory(tripId: tripId)
                    await MainActor.run {
                        if gpsPoints.isEmpty {
                            self.isHistoryEmpty = true
                            print("No history GPS points found for trip \(tripId)")
                        } else {
                            self.isHistoryEmpty = false
                            self.historyTripStatus = "Completed"
                            self.traveledPath = gpsPoints.map { Coord(lat: $0.lat, lon: $0.lng) }
                            if let last = self.traveledPath.last {
                                if let closestIdx = findClosestIndex(on: fullRoutePath, to: last) {
                                    self.currentIndex = Double(closestIdx)
                                }
                            }
                            print("Loaded \(gpsPoints.count) history points for trip \(tripId)")
                        }
                    }
                } catch {
                    print("Failed to load history for trip \(tripId): \(error.localizedDescription)")
                    await MainActor.run { self.isHistoryEmpty = true }
                }
            }
        } else {
            self.isHistoryEmpty = false
            self.isHistoryScheduled = true
            self.historySearchRange = nil
            // Live mode starts with empty history, populated as it moves
            let stopsToTrack = self.displayedStops.isEmpty ? self.bus.route.stops : self.displayedStops
            self.bus.historyStops = stopsToTrack.map { HistoryStop(stopName: $0.name, reachedTime: nil) }
        }
    }

    var stops: [Stop] { displayedStops }

    var currentCoordinate: Coord {
        if fullRoutePath.isEmpty { return bus.route.stops.first?.coordinate ?? Coord(lat: 13.0287, lon: 80.0071) }
        let idx = Int(min(currentIndex, Double(fullRoutePath.count - 1)))
        return fullRoutePath[idx]
    }

    // Backend Integration
    // We now fetch directly from the Transit Proxy
    private func syncWithFullDetails() {
        if isHistorical { return }
        
        let rt = bus.extRouteId ?? String(bus.route.id.uuidString.prefix(2)) // Fallback or extracted
        let dir = bus.statusDetail?.contains("East") == true ? "Eastbound" : "Westbound" // Dynamic heuristic or from state
        let vid = String(bus.vehicleId ?? 0)
        
        let finalRt = rt
        let finalVid = vid
        
        Task {
            do {
                print("LiveTrackingViewModel: Syncing full details for Route \(finalRt), VID \(finalVid)...")
                let details = try await APIService.shared.fetchFullTripDetails(routeId: finalRt, direction: dir, vehicleId: finalVid)
                
                await MainActor.run {
                    // 1. Update Polylines
                    if !details.polyline.isEmpty {
                        self.fullRoutePath = details.polyline.map { Coord(lat: $0.lat, lon: $0.lng) }
                    }
                    
                    // 2. Update Timeline / Stops
                    let newStops = details.timeline.map { stop in
                        Stop(
                            id: stop.stop_id,
                            name: stop.stop_name,
                            coordinate: Coord(lat: Double(stop.lat) ?? 0, lon: Double(stop.lng) ?? 0),
                            timeText: stop.eta,
                            isMajorStop: stop.is_major,
                            stopOrder: 0
                        )
                    }

                    
                    self.displayedStops = newStops
                    self.bus.route.stops = newStops
                    
                    // 3. Update History Status
                    self.bus.historyStops = details.timeline.map { stop in
                        HistoryStop(
                            stopName: stop.stop_name, 
                            coordinate: Coord(lat: Double(stop.lat) ?? 0, lon: Double(stop.lng) ?? 0),
                            reachedTime: stop.status == "Reached" ? stop.eta : nil
                        )
                    }
                    
                    // 4. Update Current Location
                    if let liveLoc = details.live_location {
                        let point = Coord(lat: liveLoc.lat, lon: liveLoc.lon)
                        if self.traveledPath.isEmpty || distance(self.traveledPath.last ?? point, point) > 0.0001 {
                            self.traveledPath.append(point)
                        }
                        self.bus.actualPolyline = self.traveledPath
                        
                        // Find closest index on polyline to position marker
                        if let closestIdx = findClosestIndex(on: fullRoutePath, to: point) {
                             withAnimation(.linear(duration: 0.5)) {
                                 self.currentIndex = Double(closestIdx)
                             }
                             
                             let totalPoints = Double(fullRoutePath.count)
                             let stopsCount = Double(max(1, displayedStops.count))
                             let currentStopIdxInt = Int(Double(closestIdx) / max(1, (totalPoints / stopsCount)))
                             self.bus.currentStopIndex = currentStopIdxInt
                             
                             // Update labels
                             if currentStopIdxInt < displayedStops.count {
                                 self.nearestStopName = displayedStops[currentStopIdxInt].name
                             }
                             if currentStopIdxInt + 1 < displayedStops.count {
                                 self.nextStopName = displayedStops[currentStopIdxInt + 1].name
                             }
                        }
                    }
                }
            } catch {
                print("LiveTrackingViewModel: Full details sync failed:", error)
            }
        }
    }

    private func fetchBackendData() {
        syncWithFullDetails()
    }

    func start() {
        print("LiveTrackingViewModel: Starting... isHistorical=\(isHistorical)")
        stop()
        
        syncWithFullDetails()
        
        if isHistorical || isFuture {
            if isFuture {
                self.traveledPath = []
                self.currentIndex = 0.0
            } else if self.traveledPath.isEmpty {
                // If no real history was fetched, fallback to full route
                self.traveledPath = fullRoutePath
                self.currentIndex = Double(max(0, fullRoutePath.count - 1))
            }
            return
        }
        
        isLive = true
        
        // 1. WebSocket Subscription (Primary Data Source)
        WebSocketService.shared.connect()
        wsSubscription = WebSocketService.shared.gpsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (vehicles: [WSVehicle]) in
                guard let self = self else { return }
                // Filter for our specific bus (vid or route/number match)
                if let update: WSVehicle = vehicles.first(where: { ($0.vid ?? "") == (self.bus.extTripId ?? "") || ($0.rt ?? "") == self.bus.number }) {
                    // 1. Update Position & Path with smooth animation
                    let point = Coord(lat: update.latDouble, lon: update.lonDouble)
                    withAnimation(.linear(duration: 0.95)) {
                        if self.traveledPath.isEmpty || self.distance(self.traveledPath.last ?? point, point) > 0.0001 {
                            self.traveledPath.append(point)
                        }
                        self.bus.actualPolyline = self.traveledPath
                    }

                    // 2. Update Telemetry
                    self.bus.liveTelemetry.speed = Double(update.spd ?? 0)
                    self.bus.liveTelemetry.bearing = Double(update.hdg ?? "0") ?? 0
                    self.bus.liveTelemetry.speedKmph = Int(Double(update.spd ?? 0) * 1.60934)
                    self.bus.liveTelemetry.lastUpdate = Date()
                    
                    // 3. Find closest index on polyline to position marker
                    if let closestIdx = self.findClosestIndex(on: self.fullRoutePath, to: point) {
                         withAnimation(.linear(duration: 0.5)) {
                             self.currentIndex = Double(closestIdx)
                         }
                    }
                    
                    // Trigger state refresh logic
                    self.tick()
                }
            }
        
        // 2. Throttled Animation Timer (1.0s)
        // Every 1.0s we move bit by bit to reduce CPU load and keep movement smooth
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
                // Periodic full sync (REST fallback) every 10s if needed
            }
        }
    }
    
    func refresh() {
        Task { @MainActor in
            self.tick()
        }
        fetchBackendData()
        snapToRoads()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        wsSubscription?.cancel()
        wsSubscription = nil
    }

    private func tick() {
        updatePathSegments()
        
        // Fast polling for the specific bus we are tracking (every 15s as a fallback to websockets)
        if !isHistorical {
            fastPollingTick += 1
            if fastPollingTick >= 15 {
                fastPollingTick = 0
                syncWithFullDetails()
            }
        }

        if isHistorical { return }
        
        // Re-calculate last major stop time
        let currentStopIndexInt = bus.currentStopIndex
        let passedStops = displayedStops.prefix(currentStopIndexInt + 1)

        if let lastMajorStop = passedStops.last(where: { $0.isMajorStop }) {
            self.lastStopTime = lastMajorStop.timeText ?? "--:--"
        } else {
            self.lastStopTime = displayedStops.first?.timeText ?? "--:--"
        }
        
        // 7. Reached Destination Logic
        if !fullRoutePath.isEmpty && currentIndex >= Double(fullRoutePath.count - 1) && !bus.hasReachedDestination {
            self.bus.hasReachedDestination = true
            self.bus.trackingStatus = .ended
            self.bus.statusDetail = "Arrived"
        }
    }
    
    private func findClosestIndex(on path: [Coord], to target: Coord) -> Int? {
        var minDst = Double.greatestFiniteMagnitude
        var minIdx: Int? = nil
        let strideVal = 5
        for i in stride(from: 0, to: path.count, by: strideVal) {
            let dst = distance(path[i], target)
            if dst < minDst {
                minDst = dst
                minIdx = i
            }
        }
        return minIdx
    }
    
    // updateOtherBuses removed as we rely on backend data
    private func updateOtherBuses() {
        // No-op or removed. Keeping empty method if called elsewhere, 
        // but I removed the call in tick, so safe to remove.
        // Actually, ensuring filteredOtherBuses logic works without indices updates.
        // Since we update otherBuses in fetchBackendData, we don't need to simulate movement.
    }
    
    // Requirement B: Helper properties
    var nextStop: Stop? {
        guard !displayedStops.isEmpty, !fullRoutePath.isEmpty else { return nil }
        let busToTrack = selectedBusForDetail ?? bus
        let stopsCount = Double(max(1, displayedStops.count))
        let pathCount = Double(max(1, fullRoutePath.count))
        let liveIndexValue = (busToTrack.id == bus.id) ? Int(currentIndex / (pathCount / stopsCount)) : busToTrack.currentStopIndex
        let clampedIndex = min(max(0, liveIndexValue), displayedStops.count - 1)
        if clampedIndex + 1 < displayedStops.count {
            return displayedStops[clampedIndex + 1]
        }
        return nil
    }
    
    func etaToStop(index: Int) -> Int {
        guard !displayedStops.isEmpty, !fullRoutePath.isEmpty, index < displayedStops.count else { return 0 }
        
        // 1. If we have a real-time arrival date from the backend, use it
        if let arrivalDate = displayedStops[index].realtimeArrival {
            let diff = arrivalDate.timeIntervalSinceNow
            if diff > 0 {
                return Int(ceil(diff / 60.0))
            } else if diff > -30 { // Just arrived or within 30s
                return 0
            }
        }
        
        // 2. Fallback to distance-based calculation
        let busToTrack = selectedBusForDetail ?? bus
        let currentIdx = Int(currentIndex)
        
        let totalPoints = Double(fullRoutePath.count)
        let totalStops = Double(max(1, displayedStops.count))
        let targetPathIdx = Int(Double(index) * (totalPoints / totalStops))
        
        if targetPathIdx <= currentIdx { return 0 }
        
        let pathSlice = fullRoutePath[currentIdx...min(targetPathIdx, fullRoutePath.count - 1)]
        var totalDistMeters = 0.0
        
        if pathSlice.count >= 2 {
            let coords = Array(pathSlice)
            for i in 0..<coords.count - 1 {
                let loc1 = CLLocation(latitude: coords[i].lat, longitude: coords[i].lon)
                let loc2 = CLLocation(latitude: coords[i+1].lat, longitude: coords[i+1].lon)
                totalDistMeters += loc1.distance(from: loc2)
            }
        }
        
        let distKm = totalDistMeters / 1000.0
        
        // Use live speed if available, otherwise fallback to average city speed
        var speedInKmph = Double(busToTrack.liveTelemetry.speedKmph ?? 0)
        if speedInKmph < 5.0 {
            speedInKmph = 20.0 // Assume 20km/h average in traffic
        }
        
        let hours = distKm / speedInKmph
        let minutes = Int(hours * 60.0)
        
        // Buffer for stops and traffic
        let buffer = 1 
        return max(1, minutes + buffer)
    }

    func formattedETATime(at index: Int) -> String {
        let minutesRemaining = etaToStop(index: index)
        let etaDate = Date().addingTimeInterval(TimeInterval(minutesRemaining * 60))
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: etaDate)
    }
    
    var durationToDestination: Int {
        return etaToStop(index: displayedStops.count - 1)
    }
    
    private func updateNearestStopFallback() {
        let busToTrack = selectedBusForDetail ?? bus
        let currentCoord = (busToTrack.id == bus.id) ? currentCoordinate : (displayedStops.isEmpty ? currentCoordinate : displayedStops[min(busToTrack.currentStopIndex, displayedStops.count - 1)].coordinate)
        
        let sortedStops = displayedStops.sorted { s1, s2 in
            let d1 = distance(currentCoord, s1.coordinate)
            let d2 = distance(currentCoord, s2.coordinate)
            return d1 < d2
        }
        
        if let nearest = sortedStops.first, distance(currentCoord, nearest.coordinate) < 0.005 {
            if self.nearestStopName != nearest.name {
                withAnimation { self.nearestStopName = nearest.name }
            }
        }
    }
    
    private func distance(_ c1: Coord, _ c2: Coord) -> Double {
        let dLat = c1.lat - c2.lat
        let dLon = c1.lon - c2.lon
        return sqrt(dLat * dLat + dLon * dLon)
    }

    private var fastPollingTick: Int = 0
    private func syncActiveBusCoord() async {
        do {
            if let gps = try await APIService.shared.fetchLatestGPS(tripId: bus.vehicleId, extTripId: bus.extTripId) {
                let point = Coord(lat: gps.lat, lon: gps.lng)
                let spd = gps.speed ?? 0.0
                let ts = gps.ts
                
                await MainActor.run {
                    BusRepository.shared.updateBusTelemetry(id: self.bus.id, point: point, speed: spd, timestampRaw: ts)
                    print("syncActiveBusCoord [\(bus.number)]: Telemetry updated in repository")
                }
            } else {
                print("syncActiveBusCoord [\(bus.number)]: No GPS data found")
            }
        } catch {
            print("Fast syncActiveBusCoord failed: \(error.localizedDescription)")
        }
    }
}
