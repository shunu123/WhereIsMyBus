import SwiftUI
import MapKit
import Combine

@MainActor
final class FleetHistoryViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var allTrips: [HistoryTripDisplay] = []
    @Published var selectedTrip: HistoryTripDisplay? = nil
    @Published var isLoading: Bool = false
    @Published var showRouteList: Bool = false
    
    // Route filtering
    @Published var visibleRoutes: Set<String> = ["Chennai", "Kancheepuram", "Vellore"]
    
    // Destination hub
    let destinationHub = Coord(lat: 13.0287, lon: 80.0071) // Saveetha Engineering College
    let destinationName = "Saveetha Engineering College"
    
    // MARK: - Helper Structs
    struct RouteInfo: Identifiable, Equatable {
        let id: String
        let name: String
        let startCity: String
        let trips: [HistoryTripDisplay]
        let plannedPolyline: [Coord]
        
        static func == (lhs: RouteInfo, rhs: RouteInfo) -> Bool { lhs.id == rhs.id }
        
        var strokeStyle: StrokeStyle {
            return StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        }
        
        var routeColor: Color {
            let lower = startCity.lowercased()
            if lower.contains("chennai") { return .blue }
            if lower.contains("kancheepuram") { return .purple }
            if lower.contains("vellore") { return .orange }
            if lower.contains("thiruvallur") { return .green }
            if lower.contains("tambaram") { return .cyan }
            if lower.contains("poonamallee") { return .indigo }
            if lower.contains("avadi") { return .pink }
            return .red
        }
    }
    
    struct HistoryTripDisplay: Identifiable, Equatable {
        let id: UUID
        let busNumber: String
        let busId: UUID
        let routeName: String
        let startCity: String
        let actualPolyline: [Coord]
        let isDeviated: Bool
        let status: String
        let startTime: String
        let endTime: String
        let reachedTime: String?
        let duration: String
        let stops: [HistoryStop]
        
        var segments: [PathSegment] {
            guard !actualPolyline.isEmpty else { return [] }
            var segments: [PathSegment] = []
            var currentCoords: [Coord] = []
            var currentlyDiverted = actualPolyline.first?.isDiverted ?? false
            
            for coord in actualPolyline {
                if coord.isDiverted == currentlyDiverted {
                    currentCoords.append(coord)
                } else {
                    if !currentCoords.isEmpty {
                        segments.append(PathSegment(coords: currentCoords, isDiverted: currentlyDiverted))
                    }
                    currentCoords = [coord]
                    currentlyDiverted = coord.isDiverted
                }
            }
            if !currentCoords.isEmpty {
                segments.append(PathSegment(coords: currentCoords, isDiverted: currentlyDiverted))
            }
            return segments
        }
    }

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var groupedRoutes: [RouteInfo] {
        let grouped = Dictionary(grouping: allTrips) { $0.startCity }
        return grouped.map { city, trips in
            RouteInfo(id: city, name: "\(city) → Saveetha", startCity: city, trips: trips, plannedPolyline: trips.first?.actualPolyline ?? [])
        }.sorted { $0.startCity < $1.startCity }
    }
    
    var filteredTrips: [HistoryTripDisplay] {
        allTrips.filter { visibleRoutes.contains($0.startCity) }
    }
    
    var filteredBusesAtDestination: [HistoryTripDisplay] {
        filteredTrips.filter { $0.status == "COMPLETED" }
    }
    
    var filteredGroupedRoutes: [RouteInfo] {
        let grouped = Dictionary(grouping: filteredTrips) { $0.startCity }
        return grouped.map { city, trips in
            RouteInfo(id: city, name: "\(city) → Saveetha", startCity: city, trips: trips, plannedPolyline: trips.first?.actualPolyline ?? [])
        }.sorted { $0.startCity < $1.startCity }
    }
    
    // MARK: - Route Filtering
    func toggleRoute(_ routeName: String) {
        if visibleRoutes.contains(routeName) {
            visibleRoutes.remove(routeName)
        } else {
            visibleRoutes.insert(routeName)
        }
    }
    
    func showAllRoutes() {
        visibleRoutes = Set(groupedRoutes.map { $0.startCity })
    }
    
    func clearAllRoutes() {
        visibleRoutes.removeAll()
    }

    // MARK: - Init
    init() {
        loadHistory(for: selectedDate)
    }
    
    // MARK: - Functions
    func loadHistory(for date: Date) {
        isLoading = true
        allTrips = []
        selectedTrip = nil
        
        Task {
            let dateKey = DateFormatter()
            dateKey.dateFormat = "yyyy-MM-dd"
            let dateString = dateKey.string(from: date)
            
            do {
                let fleetData = try await APIService.shared.fetchFleetHistory(date: dateString)
                var fetchedTrips: [HistoryTripDisplay] = []
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let basicFormatter = ISO8601DateFormatter()
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "hh:mm a"
                
                for trip in fleetData {
                    var polyline: [Coord] = []
                    for pt in trip.actual_polyline {
                        polyline.append(Coord(lat: pt.lat, lon: pt.lng))
                    }
                    
                    var startTimeStr = "--"
                    if let st = trip.start_time {
                        if let d = isoFormatter.date(from: st) ?? basicFormatter.date(from: st) {
                            startTimeStr = displayFormatter.string(from: d)
                        } else {
                            // try naive fallback
                            let parts = st.components(separatedBy: "T")
                            if parts.count > 1 {
                                let timeParts = parts[1].components(separatedBy: ":")
                                if timeParts.count >= 2, let hr = Int(timeParts[0]) {
                                    let ampm = hr >= 12 ? "PM" : "AM"
                                    let hr12 = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
                                    startTimeStr = String(format: "%02d:%@ %@", hr12, timeParts[1], ampm)
                                }
                            }
                        }
                    }
                    
                    var endTimeStr = "Ongoing"
                    if let et = trip.end_time, trip.status == "COMPLETED" {
                        if let d = isoFormatter.date(from: et) ?? basicFormatter.date(from: et) {
                            endTimeStr = displayFormatter.string(from: d)
                        }
                    }
                    
                    var historyStops: [HistoryStop] = []
                    if let fetchedStops = trip.stops {
                        for fs in fetchedStops {
                            historyStops.append(HistoryStop(
                                stopName: fs.stop_name, 
                                coordinate: Coord(lat: fs.lat, lon: fs.lng),
                                reachedTime: fs.reached_time
                            ))
                        }
                    }
                    
                    // Fallback to BusRepository ID for deep linking
                    let knownBusId = BusRepository.shared.allBuses.first(where: { $0.vehicleId == trip.trip_id || $0.busId == trip.bus_id })?.id ?? UUID()
                    
                    let displayTrip = HistoryTripDisplay(
                        id: UUID(),
                        busNumber: trip.bus_number,
                        busId: knownBusId,
                        routeName: trip.route_name,
                        startCity: trip.start_city,
                        actualPolyline: polyline,
                        isDeviated: false, // Could compute from planned vs actual in future
                        status: trip.status ?? "SCHEDULED",
                        startTime: startTimeStr,
                        endTime: endTimeStr,
                        reachedTime: nil,
                        duration: trip.status == "COMPLETED" ? "Done" : "Live",
                        stops: historyStops
                    )
                    fetchedTrips.append(displayTrip)
                }
                
                await MainActor.run {
                    self.allTrips = fetchedTrips
                    self.visibleRoutes = Set(fetchedTrips.map { $0.startCity })
                    self.isLoading = false
                }
            } catch {
                print("Failed to fetch fleet history:", error)
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Timeline Generation
    func generateTimelineEvents(for trip: HistoryTripDisplay, historyStops: [HistoryStop]) -> [TripTimelineEvent] {
        var events: [TripTimelineEvent] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        if let startDate = dateFormatter.date(from: trip.startTime) {
            events.append(TripTimelineEvent(timestamp: startDate, title: "Trip started from \(trip.startCity)", subtitle: "Bus \(trip.busNumber) departed", eventType: .tripStart))
        }
        
        for (index, stop) in historyStops.enumerated() {
            if let timeStr = stop.reachedTime, let date = dateFormatter.date(from: timeStr) {
                let isLastStop = index == historyStops.count - 1
                events.append(TripTimelineEvent(timestamp: date, title: isLastStop ? "Reached destination" : "Reached \(stop.stopName)", subtitle: isLastStop ? stop.stopName : nil, eventType: isLastStop ? .tripEnd : .stopReached))
            }
        }
        
        return events.sorted { $0.timestamp < $1.timestamp }
    }
}
