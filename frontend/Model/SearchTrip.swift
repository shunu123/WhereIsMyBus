import Foundation

// MARK: - Transit Support Models

struct TransitGPS: Codable, Hashable {
    let lat: Double
    let lon: Double
    let heading: Int
    let speed_mph: Int
}


/// A trip result returned by the `/search` endpoint.
/// Field names match the SQL column aliases in the FastAPI backend.
struct SearchTrip: Codable, Identifiable {
    var id: Int { tripId }

    let tripId: Int
    let extTripId: String?
    let busId: Int?
    let busNo: String?
    let label: String?
    let routeId: Int?
    let routeName: String?
    let extRouteId: String?
    let fromDeparture: String?
    let toArrival: String?
    let durationMinutes: Int?
    let status: String?
    let busLiveLocation: TransitGPS?
    let nextStopName: String?
    let currentStopName: String?

    enum CodingKeys: String, CodingKey {
        case tripId          = "trip_id"
        case extTripId       = "ext_trip_id"
        case busId           = "bus_id"
        case busNo           = "bus_no"
        case label
        case routeId         = "route_id"
        case routeName       = "route_name"
        case extRouteId      = "ext_route_id"
        case fromDeparture   = "from_departure"
        case toArrival       = "to_arrival"
        case durationMinutes = "duration_minutes"
        case status
        case busLiveLocation = "bus_live_location"
        case nextStopName    = "next_stop_name"
        case currentStopName = "current_stop_name"
    }
}
