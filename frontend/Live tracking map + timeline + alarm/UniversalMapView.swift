import SwiftUI
import MapKit

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
        // Firebase logic removed
    }
}
