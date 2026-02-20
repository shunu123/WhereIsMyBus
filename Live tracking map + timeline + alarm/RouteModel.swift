import Foundation

struct RouteModel: Identifiable, Codable, Hashable {
    var id: String { route_id }
    let route_id: String
    let name: String
    let from_location: String
    let to_location: String
    let stops_sequence: String
    let bus_ids: [String]

    var stopsArray: [String] {
        stops_sequence.components(separatedBy: ", ")
    }

    var stops: [String] { stopsArray }
    var buses: [String] { bus_ids }

    func hash(into hasher: inout Hasher) { hasher.combine(route_id) }
    static func == (lhs: RouteModel, rhs: RouteModel) -> Bool { lhs.route_id == rhs.route_id }
}
