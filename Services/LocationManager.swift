import Foundation
import CoreLocation
import Combine
import MapKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()
    
    @Published var userLocation: CLLocation?
    @Published var currentAddress = "Fetching location..."
    @Published var currentCity = "Chennai"
    
    private var isUpdatingAddress = false
    
    private let cityCoordinates: [String: CLLocation] = [
        "Chennai": CLLocation(latitude: 13.0827, longitude: 80.2707)
    ]
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        
        // Initial fallback
        userLocation = cityCoordinates["Chennai"]
        currentAddress = "Chennai, Tamil Nadu"
    }
    
    func setCity(_ name: String) {
        if let location = cityCoordinates[name] {
            currentCity = name
            userLocation = location
            currentAddress = "\(name), Tamil Nadu"
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location
            self.reverseGeocode(location)
        }
    }
    
    private func reverseGeocode(_ location: CLLocation) {
        guard !isUpdatingAddress else { return }
        isUpdatingAddress = true
        
        // Using MKLocalSearch as CLGeocoder is deprecated in this environment
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            self?.isUpdatingAddress = false
            
            if let mapItem = response?.mapItems.first {
                let city = mapItem.name ?? "Chennai"
                let address = mapItem.name ?? city // In iOS 26, name/address are preferred
                
                DispatchQueue.main.async {
                    self?.currentCity = city
                    self?.currentAddress = address
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }
}
