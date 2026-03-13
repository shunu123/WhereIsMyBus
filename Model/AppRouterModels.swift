import Foundation
import CoreLocation

// Shared models used for navigation in AppRouter

struct Coord: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let lat: Double
    let lon: Double
    var isDiverted: Bool = false

    nonisolated init(id: UUID = UUID(), lat: Double, lon: Double, isDiverted: Bool = false) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.isDiverted = isDiverted
    }

    nonisolated var cl: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

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
