import SwiftUI
import MapKit

struct StudentDashboardView: View {
    @StateObject private var vm = StudentDashboardViewModel()
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showFullPanel = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Map Layer
            Map(position: $position) {
                UserAnnotation()
                
                // 2. Walking Routes
                ForEach(vm.nearbyStops) { stop in
                    if let route = vm.routes[stop.id] {
                        MapPolyline(route)
                            .stroke(stop.id == vm.selectedStop?.id ? theme.current.accent : theme.current.secondaryText.opacity(0.4), 
                                    lineWidth: stop.id == vm.selectedStop?.id ? 5 : 3)
                    }
                }
                
                // 3. Nearby Bus Stops
                ForEach(vm.nearbyStops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate) {
                        Circle()
                            .fill(stop.id == vm.selectedStop?.id ? .green : theme.current.secondaryText.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .onTapGesture {
                                withAnimation { vm.selectStop(stop) }
                            }
                    }
                }
                
                // 4. Live Buses
                ForEach(Array(vm.liveBuses.values), id: \.vid) { vehicle in
                    Annotation("Bus \(vehicle.rt ?? "")", coordinate: CLLocationCoordinate2D(latitude: vehicle.latDouble, longitude: vehicle.lonDouble)) {
                        VStack(spacing: 0) {
                            Image(systemName: "bus.fill")
                                .font(.system(size: 14))
                                .padding(6)
                                .background(theme.current.accent)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                            
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(theme.current.accent)
                                .offset(y: -4)
                        }
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .ignoresSafeArea()
            
            // MARK: - Info Panel
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.current.secondaryText.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Stop Selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(vm.nearbyStops) { stop in
                                Button {
                                    withAnimation { vm.selectStop(stop) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stop.id == vm.nearbyStops.first?.id ? "PRIMARY" : "ALTERNATIVE")
                                            .font(.system(size: 8, weight: .black))
                                            .foregroundStyle(stop.id == vm.selectedStop?.id ? .white : theme.current.secondaryText)
                                        Text(stop.name)
                                            .font(.subheadline.bold())
                                            .lineLimit(1)
                                            .foregroundStyle(stop.id == vm.selectedStop?.id ? .white : theme.current.text)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(stop.id == vm.selectedStop?.id ? theme.current.accent : theme.current.card)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(theme.current.border, lineWidth: stop.id == vm.selectedStop?.id ? 0 : 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    
                    if let selected = vm.selectedStop {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SELECTED STOP")
                                        .font(.caption2.bold())
                                        .foregroundStyle(theme.current.secondaryText)
                                    Text(selected.name)
                                        .font(.title3.bold())
                                        .foregroundStyle(theme.current.text)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "%.1f km", vm.distances[selected.id] ?? 0))
                                        .font(.headline)
                                        .foregroundStyle(theme.current.accent)
                                    if let time = vm.walkingTimes[selected.id] {
                                        Text("\(Int(time / 60)) min walk")
                                            .font(.caption2)
                                            .foregroundStyle(theme.current.secondaryText)
                                    }
                                }
                            }
                            
                            // Show Direction Button
                            Button {
                                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: selected.coordinate))
                                mapItem.name = selected.name
                                mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                            } label: {
                                HStack {
                                    Image(systemName: "safari.fill")
                                    Text("Show Direction")
                                        .font(.subheadline.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(theme.current.accent)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                            }
                            
                            Divider()
                            
                            Text("AVAILABLE BUSES")
                                .font(.caption2.bold())
                                .foregroundStyle(theme.current.secondaryText)
                            
                            if vm.arrivingBuses.isEmpty {
                                Text("No buses arriving soon.")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.current.secondaryText)
                                    .padding(.vertical, 8)
                            } else {
                                ScrollView {
                                    VStack(spacing: 12) {
                                        ForEach(vm.arrivingBuses) { bus in
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(theme.current.accent.opacity(0.1))
                                                    .frame(width: 40, height: 40)
                                                    .overlay(
                                                        Image(systemName: "bus.fill")
                                                            .foregroundStyle(theme.current.accent)
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Bus \(bus.number)")
                                                        .font(.subheadline.bold())
                                                    Text(bus.headsign)
                                                        .font(.caption)
                                                        .foregroundStyle(theme.current.secondaryText)
                                                }
                                                
                                                Spacer()
                                                
                                                Text(bus.departsAt)
                                                    .font(.headline)
                                                    .foregroundStyle(theme.current.accent)
                                            }
                                            .padding(12)
                                            .background(theme.current.card.opacity(0.5))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .frame(maxHeight: showFullPanel ? .infinity : 200)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(
                theme.current.card
                    .shadow(color: .black.opacity(0.1), radius: 20, y: -10)
            )
            .cornerRadius(25, corners: [.topLeft, .topRight])
            .offset(y: showFullPanel ? 0 : 40)
            .gesture(
                DragGesture().onEnded { val in
                    if val.translation.height < -100 { withAnimation { showFullPanel = true } }
                    if val.translation.height > 100 { withAnimation { showFullPanel = false } }
                }
            )
            
            // Back Button
            VStack {
                HStack {
                    Button { router.back() } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .padding(12)
                            .background(Circle().fill(theme.current.card))
                            .shadow(radius: 5)
                            .padding(.leading, 20)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            if let error = vm.error {
                VStack {
                    Text(error)
                        .padding()
                        .background(.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
    }
}
