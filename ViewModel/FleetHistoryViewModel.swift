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
            switch startCity {
            case "Kancheepuram":
                return StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [10, 5])
            case "Vellore":
                return StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            default:
                return StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            }
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
            // 1. Use BusRepository to get known vehicles (static + live updates)
            // This is more reliable than fetching from a potentially offline component
            let knownBuses = BusRepository.shared.allBuses
            
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
            
            var fetchedTrips: [HistoryTripDisplay] = []
            let dateFormatter = ISO8601DateFormatter()
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            
            for bus in knownBuses {
                // Logic:
                // 1. Try to fetch history from backend if available
                // 2. If it fails or returns empty (and we are in a demo/no-backend env),
                //    simulate a trip if one exists in the bus.tripHistory (from local data/demo data)
                
                var historyPoints: [VehicleHistoryPoint] = []
                var usedFallback = false
                
                let dateKey = DateFormatter()
                dateKey.dateFormat = "yyyy-MM-dd"
                let dateString = dateKey.string(from: date)
                
                do {
                    historyPoints = try await BackendAPI.shared.fetchVehicleHistory(busId: bus.number, date: dateString)
                } catch {
                    print("History fetch failed for \(bus.number), trying local fallback...")
                    usedFallback = true
                }
                
                if historyPoints.isEmpty && usedFallback {
                    // FALLBACK: Use local trip history if available for this date
                    if let record = bus.tripHistory[dateString] {
                        let trip = HistoryTripDisplay(
                            id: UUID(),
                            busNumber: bus.number,
                            busId: bus.id,
                            routeName: "\(bus.route.from) → \(bus.route.to)",
                            startCity: bus.route.from,
                            actualPolyline: record.actualPolyline,
                            isDeviated: record.isDeviated,
                            status: record.status,
                            startTime: "Simulated",
                            endTime: "Simulated",
                            reachedTime: "Simulated",
                            duration: bus.durationText
                        )
                        fetchedTrips.append(trip)
                    }
                    continue
                }
                
                // Process fetched points
                if !historyPoints.isEmpty {
                    let coords = historyPoints.map {
                        Coord(lat: $0.lat, lon: $0.lng)
                    }
                    
                    let firstPoint = historyPoints.first
                    let lastPoint = historyPoints.last
                    var firstTime = "--:--"
                    var lastTime = "--:--"
                    
                    if let firstStr = firstPoint?.timestamp, let firstDate = dateFormatter.date(from: firstStr) {
                         firstTime = displayFormatter.string(from: firstDate)
                    }
                    if let lastStr = lastPoint?.timestamp, let lDate = dateFormatter.date(from: lastStr) {
                         lastTime = displayFormatter.string(from: lDate)
                    }
                    
                    let trip = HistoryTripDisplay(
                        id: UUID(),
                        busNumber: bus.number,
                        busId: bus.id,
                        routeName: "\(bus.route.from) → \(bus.route.to)",
                        startCity: bus.route.from,
                        actualPolyline: coords,
                        isDeviated: false,
                        status: "COMPLETED",
                        startTime: firstTime,
                        endTime: lastTime,
                        reachedTime: lastTime,
                        duration: bus.durationText
                    )
                    fetchedTrips.append(trip)
                }
            }
            
            await MainActor.run {
                self.allTrips = fetchedTrips
                self.isLoading = false
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
