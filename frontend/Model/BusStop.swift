import Foundation
import CoreLocation

struct BusStop: Codable, Identifiable, Hashable {
    let id: String           // ✅ String to support alphanumeric IDs (Delhi/CTA)
    let name: String
    let lat: Double
    let lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    // Convenience init for manual creation (Previews)
    init(id: String, name: String, lat: Double, lng: Double) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lng = lng
    }

    init(id: String, name: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.lat = coordinate.latitude
        self.lng = coordinate.longitude
    }
}
