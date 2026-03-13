import SwiftUI
import MapKit

struct HomeMapView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var position: MapCameraPosition = .automatic
    @State private var nearbyStops: [BusStop] = []
    
    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                // Center location marker (default Bangalore location)
                if let userLocation = locationManager.userLocation {
                    Annotation("Bangalore", coordinate: userLocation.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 40, height: 40)
                            
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                )
                        }
                    }
                }
                
                // Nearby bus stops
                ForEach(nearbyStops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate) {
                        VStack(spacing: 4) {
                            Image(systemName: "bus.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(theme.current.accent)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                            
                            Text(stop.name)
                                .font(.caption2.bold())
                                .foregroundStyle(theme.current.text)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.1), radius: 2)
                                )
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapCompass()
            }
            .frame(height: 220)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.current.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .onAppear {
            loadNearbyStops()
            updateCameraPosition()
        }
    }
    
    private func updateCameraPosition() {
        guard let userLocation = locationManager.userLocation else { return }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            position = .region(
                MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }
    }
    
    private func loadNearbyStops() {
        // TODO: Fetch nearby stops from Firebase based on user location.
        // nearbyStops will be populated by the Firebase listener when connected.
        nearbyStops = []
    }
}

// BusStop is now defined in Model/BusStop.swift

#Preview {
    HomeMapView()
        .environmentObject(ThemeManager())
        .environmentObject(LocationManager())
        .padding()
        .onAppear {
            // Inject preview stops so the canvas shows something useful
            // (PreviewAssets.nearbyStops is preview-only data)
        }
}
