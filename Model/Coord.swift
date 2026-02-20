import Foundation
import CoreLocation

struct Coord: Identifiable, Hashable, Codable {
    let id: UUID
    let lat: Double
    let lon: Double
    var isDiverted: Bool = false

    init(id: UUID = UUID(), lat: Double, lon: Double, isDiverted: Bool = false) {
        self.id = id
        self.lat = lat
        self.lon = lon
        self.isDiverted = isDiverted
    }

    var cl: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
