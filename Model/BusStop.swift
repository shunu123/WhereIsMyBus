import Foundation
import CoreLocation

struct BusStop: Codable, Identifiable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    
    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
    
    // Default memberwise initializer for Codable is automatic
    
    // Convenience init for manual creation (e.g. Previews)
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
