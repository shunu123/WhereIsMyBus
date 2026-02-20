import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    // Default location: Bangalore center (Majestic area)
    @Published var userLocation: CLLocation? = CLLocation(
        latitude: 13.0827,
        longitude: 80.2707
    )
    
    @Published var currentCity = "Chennai"
    
    private let cityCoordinates: [String: CLLocation] = [
        "Chennai": CLLocation(latitude: 13.0827, longitude: 80.2707)
    ]
    
    override init() {
        super.init()
    }
    
    func setCity(_ name: String) {
        if let location = cityCoordinates[name] {
            currentCity = name
            userLocation = location
        }
    }
}
