import CoreLocation
import FirebaseDatabase
import Combine // Add this!

class BusTrackerService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let ref = Database.database().reference()
    
    @Published var lastLocation: CLLocation?

    override init() {
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 5
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()

            // TEST LINE: This should appear in Firebase immediately when the app starts
        }

    // This must be INSIDE the class
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.lastLocation = location
        
        let busData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "speed": max(0, location.speed),
            "timestamp": ServerValue.timestamp()
        ]
        
        // Push to Firebase
        ref.child("live_buses/Bus_101").setValue(busData)
    }
}
