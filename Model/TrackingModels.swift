import Foundation

/// Single, unique ping type (prevents "ambiguous type lookup")
struct LocationPing: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let coordinate: Coord

    init(id: UUID = UUID(), timestamp: Date, coordinate: Coord) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
    }
}

struct PathSegment: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var coords: [Coord]
    var isDiverted: Bool
}

/// GPS track point for trip history replay
struct TripTrackPoint: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let coordinate: Coord
    let speed: Double? // km/h
    let heading: Double? // degrees
    
    init(id: UUID = UUID(), timestamp: Date, coordinate: Coord, speed: Double? = nil, heading: Double? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.coordinate = coordinate
        self.speed = speed
        self.heading = heading
    }
}

/// Timeline event for trip history display
struct TripTimelineEvent: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let title: String
    let subtitle: String?
    let eventType: EventType
    
    enum EventType: String, Hashable {
        case tripStart = "Trip Started"
        case stopReached = "Stop Reached"
        case halt = "Halted"
        case deviation = "Route Deviation"
        case tripEnd = "Trip Completed"
    }
    
    init(id: UUID = UUID(), timestamp: Date, title: String, subtitle: String? = nil, eventType: EventType) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.subtitle = subtitle
        self.eventType = eventType
    }
}
