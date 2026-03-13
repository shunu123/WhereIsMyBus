import Foundation

/// A trip result returned by the `/buses` endpoint.
struct DailyBusTrip: Codable, Identifiable {
    var id: Int { tripId }

    let tripId: Int
    let extTripId: String?
    let busId: Int?
    let busNo: String?
    let label: String?
    let routeId: Int?
    let routeName: String?
    let extRouteId: String?
    let firstDeparture: String?
    let lastArrival: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case tripId          = "trip_id"
        case extTripId       = "ext_trip_id"
        case busId           = "bus_id"
        case busNo           = "bus_no"
        case label
        case routeId         = "route_id"
        case routeName       = "route_name"
        case extRouteId      = "ext_route_id"
        case firstDeparture  = "first_departure"
        case lastArrival     = "last_arrival"
        case status
    }
}
