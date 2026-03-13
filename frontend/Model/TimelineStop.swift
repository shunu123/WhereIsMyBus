import Foundation

/// A single stop in a trip's timeline, returned by `/trips/{id}/timeline`.
/// Field names match the SQL column aliases in the FastAPI backend.
struct TimelineStop: Codable, Identifiable {
    var id: Int { stopId }

    let stopOrder: Int
    let stopId: Int
    let stopName: String
    let lat: Double
    let lng: Double
    let schedArrival: String?
    let schedDeparture: String?
    let realtimeEta: String?
    let delaySec: Int?
    let isReached: Bool?

    enum CodingKeys: String, CodingKey {
        case stopOrder      = "stop_order"
        case stopId         = "stop_id"
        case stopName       = "stop_name"
        case lat
        case lng
        case schedArrival   = "sched_arrival"
        case schedDeparture = "sched_departure"
        case realtimeEta    = "realtime_eta"
        case delaySec       = "delay_sec"
        case isReached      = "is_reached"
    }
}
