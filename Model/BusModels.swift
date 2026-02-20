import Foundation

enum BusStatus: String, Codable, CaseIterable {
    case onTime = "On Time"
    case delayed = "Delayed"
}

struct TripRecord: Codable, Hashable {
    var date: String // "yyyy-MM-dd"
    var isDeviated: Bool
    var status: String // "Normal", "Deviated", "Completed"
    var plannedPolyline: [Coord]
    var actualPolyline: [Coord]
    var historyStops: [HistoryStop]
}

struct StateInfo: Codable, Hashable {
    let fromState: String
    let fromCity: String
    let toState: String
    let toCity: String
}

struct Stop: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let coordinate: Coord
    let timeText: String?
    let isMajorStop: Bool
    let platformNumber: String?

    init(id: String = UUID().uuidString, name: String, coordinate: Coord, timeText: String?, isMajorStop: Bool = true, platformNumber: String? = nil) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.timeText = timeText
        self.isMajorStop = isMajorStop
        self.platformNumber = platformNumber
    }
}

struct HistoryStop: Identifiable, Hashable, Codable {
    let id: UUID
    let stopName: String
    let reachedTime: String? // "HH:MM" or nil

    init(id: UUID = UUID(), stopName: String, reachedTime: String?) {
        self.id = id
        self.stopName = stopName
        self.reachedTime = reachedTime
    }
}

struct Route: Identifiable, Hashable, Codable {
    var id: UUID
    var from: String
    var to: String
    var stops: [Stop]
    var plannedPolyline: [Coord] = []

    init(id: UUID = UUID(), from: String, to: String, stops: [Stop], plannedPolyline: [Coord] = []) {
        self.id = id
        self.from = from
        self.to = to
        self.stops = stops
        self.plannedPolyline = plannedPolyline
    }
}

enum TrackingStatus: String, Codable, CaseIterable {
    case scheduled = "Scheduled"
    case arriving = "Arriving"
    case arrived = "Arrived"
    case departed = "Departed"
    case halted = "Halted"
    case ended = "Ended"
}

struct TrackingMetadata: Codable, Hashable {
    var isHalted: Bool = false
    var lastUpdate: Date = Date()
    var speed: Double = 0.0
    var bearing: Double = 0.0
    var speedKmph: Int? = nil // Requirement B: Live Telemetry
    
    init(isHalted: Bool = false, lastUpdate: Date = Date(), speed: Double = 0.0, bearing: Double = 0.0, speedKmph: Int? = nil) {
        self.isHalted = isHalted
        self.lastUpdate = lastUpdate
        self.speed = speed
        self.bearing = bearing
        self.speedKmph = speedKmph
    }
}

struct Bus: Identifiable, Hashable, Codable {
    var id: UUID
    var number: String
    var headsign: String
    var departsAt: String
    var durationText: String
    var status: BusStatus
    var statusDetail: String?
    var trackingStatus: TrackingStatus
    var etaMinutes: Int?
    var route: Route
    var stateInfo: StateInfo?
    var vehicleId: Int? = nil // Backend ID
    
    // New fields for University Tracking
    var isDeviated: Bool = false
    var currentStopIndex: Int = 0 
    var liveTelemetry: TrackingMetadata = TrackingMetadata()
    
    var actualPolyline: [Coord] = [] // Requirement C: Actual path
    var historyStops: [HistoryStop] = [] // Requirement A: History binding
    
    // Phase 2: Reached State
    var hasReachedDestination: Bool = false
    var totalTripDuration: Int? = nil // in minutes

    // History Tracking
    var tripHistory: [String: TripRecord] = [:] // Map: "yyyy-MM-dd" -> TripRecord

    var isRunning: Bool {
        trackingStatus == .arriving || (trackingStatus == .halted && !isDeviated)
    }

    init(
        id: UUID = UUID(),
        number: String,
        headsign: String,
        departsAt: String,
        durationText: String,
        status: BusStatus,
        statusDetail: String?,
        trackingStatus: TrackingStatus = .scheduled,
        etaMinutes: Int? = nil,
        route: Route,
        stateInfo: StateInfo? = nil,
        isDeviated: Bool = false,
        currentStopIndex: Int = 0,
        speed: Double = 0.0,
        actualPolyline: [Coord] = [],
        historyStops: [HistoryStop] = [],
        hasReachedDestination: Bool = false,
        totalTripDuration: Int? = nil,
        tripHistory: [String: TripRecord] = [:]
    ) {
        self.id = id
        self.number = number
        self.headsign = headsign
        self.departsAt = departsAt
        self.durationText = durationText
        self.status = status
        self.statusDetail = statusDetail
        self.trackingStatus = trackingStatus
        self.etaMinutes = etaMinutes
        self.route = route
        self.stateInfo = stateInfo
        self.isDeviated = isDeviated
        self.currentStopIndex = currentStopIndex
        self.liveTelemetry = TrackingMetadata(speed: speed)
        self.actualPolyline = actualPolyline
        self.historyStops = historyStops
        self.hasReachedDestination = hasReachedDestination
        self.totalTripDuration = totalTripDuration
        self.tripHistory = tripHistory
    }

    func statusRelativeTo(stopName: String) -> TrackingStatus {
        if isDeviated { return .halted }
        
        let normalizedTarget = stopName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let targetIndex = route.stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedTarget) || normalizedTarget.contains(name)
        }) else {
            return trackingStatus
        }
        
        if currentStopIndex > targetIndex {
            return .departed
        } else if currentStopIndex == targetIndex {
            return trackingStatus
        } else {
            return trackingStatus == .scheduled ? .scheduled : .arriving
        }
    }

    var displayETA: Int? {
        if isDeviated { return nil }
        return etaMinutes
    }

    func stopsFrom(sourceName: String) -> [Stop] {
        let normalizedSource = sourceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let sourceIndex = route.stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedSource) || normalizedSource.contains(name)
        }) else {
            return route.stops
        }
        return Array(route.stops[sourceIndex...])
    }

    func timeAtStop(name: String) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return route.stops.first(where: { 
            let sName = $0.name.lowercased()
            return sName.contains(normalized) || normalized.contains(sName)
        })?.timeText
    }

    func durationBetween(from: String, to: String) -> Int {
        let stops = route.stops
        let normalizedFrom = from.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTo = to.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let fromIdx = stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedFrom) || normalizedFrom.contains(name)
        }) ?? 0
        
        let toIdx = stops.firstIndex(where: { 
            let name = $0.name.lowercased()
            return name.contains(normalizedTo) || normalizedTo.contains(name)
        }) ?? (stops.count - 1)
        
        return max(0, toIdx - fromIdx) * 10 // Assuming 10 mins per stop for simulation
    }
}
