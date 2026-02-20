import SwiftUI
import MapKit
import FirebaseDatabase

struct UniversalMapView: View {
    @EnvironmentObject var theme: ThemeManager
    let route: RouteModel
    let busID: String
    
    @State private var busLocation = CLLocationCoordinate2D(latitude: 13.0827, longitude: 80.2707)
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                Annotation(busID, coordinate: busLocation) {
                    Image(systemName: "bus.fill")
                        .padding(8)
                        .background(theme.current.accent)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
            }
            .ignoresSafeArea()

            VStack {
                Capsule().fill(.gray).frame(width: 40, height: 6).padding(.top)
                Text("Live Route: \(route.name)").font(.headline)
                List(route.stopsArray, id: \.self) { stop in
                    Text(stop).font(.subheadline)
                }
                .listStyle(.plain)
            }
            .frame(height: 250)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(25)
        }
        .onAppear { listenToBus() }
    }

    func listenToBus() {
        let busPath = Database.database().reference().child("live_buses/\(busID)")
        
        // Get the single latest entry from the random-ID folder
        busPath.queryLimited(toLast: 1).observe(.value) { snapshot in
            guard let topLevel = snapshot.value as? [String: Any],
                  let latestKey = topLevel.keys.first,
                  let data = topLevel[latestKey] as? [String: Any] else { return }
            
            // Digging: location -> coords -> lat/lon
            if let location = data["location"] as? [String: Any],
               let coords = location["coords"] as? [String: Any],
               let lat = coords["latitude"] as? Double,
               let lon = coords["longitude"] as? Double {
                
                let newCoords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.busLocation = newCoords
                    // Center the map on the bus
                    self.position = .region(MKCoordinateRegion(
                        center: newCoords,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }
}
