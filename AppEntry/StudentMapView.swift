import SwiftUI
import MapKit
import FirebaseDatabase

struct StudentMapView: View {
    @EnvironmentObject var theme: ThemeManager
    let route: RouteModel
    let busID: String
    
    @State private var busLocation = CLLocationCoordinate2D(latitude: 13.0827, longitude: 80.2707)
    @State private var currentStopIndex: Int = 0
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Map UI
            Map(position: $position) {
                Annotation("Bus \(busID)", coordinate: busLocation) {
                    Image(systemName: "bus.fill")
                        .padding(8)
                        .background(theme.current.accent)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
            }
            .ignoresSafeArea()

            // 2. Timeline UI Overlay
            BusStopTimelineView(stops: route.stops, currentStopIndex: currentStopIndex)
                .frame(height: 300)
                .background(theme.current.card)
                .cornerRadius(25, corners: [.topLeft, .topRight])
                .shadow(radius: 10)
        }
        .onAppear { observeBusMovement() }
    }

    // 3. ETA and Movement Logic
    func observeBusMovement() {
        Database.database().reference().child("live_buses/\(busID)").observe(.value) { snapshot in
            guard let dict = snapshot.value as? [String: Any],
                  let lat = dict["latitude"] as? Double,
                  let lon = dict["longitude"] as? Double else { return }
            
            let newCoords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            withAnimation(.easeInOut) {
                self.busLocation = newCoords
                self.position = .camera(MapCamera(centerCoordinate: newCoords, distance: 1000))
            }
            calculateCurrentStop(lat: lat, lon: lon)
        }
    }

    func calculateCurrentStop(lat: Double, lon: Double) {
        // Simple logic: If bus is moving, we estimate progress
        // In a real app, compare lat/lon to your stop coordinates
        print("Bus is currently at: \(lat), \(lon)")
    }
}
