import SwiftUI
import MapKit

struct RouteMapView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    let buses: [Bus]
    let fromStop: String
    let toStop: String
    
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedBus: Bus?
    // Road-snapped polyline per bus ID
    @State private var snappedPolylines: [UUID: [Coord]] = [:]
    
    var body: some View {
        ZStack {
            Map(position: $position, interactionModes: .all) {
                // Road-snapped route polylines
                ForEach(buses) { bus in
                    let coords = snappedPolylines[bus.id] ?? bus.route.stops.map { $0.coordinate }
                    MapPolyline(coordinates: coords.map { $0.cl })
                        .stroke(theme.current.accent.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }

                // Stops for the first route
                if let firstBus = buses.first {
                    ForEach(firstBus.route.stops) { stop in
                        Annotation(stop.name, coordinate: CLLocationCoordinate2D(latitude: stop.coordinate.lat, longitude: stop.coordinate.lon)) {
                            Circle()
                                .fill(stop.name.lowercased().contains(fromStop.lowercased()) ? theme.current.accent : Color.white)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                                .overlay {
                                    if stop.name.lowercased().contains(fromStop.lowercased()) {
                                        Text("MY POINT")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(theme.current.accent)
                                            .offset(y: -12)
                                    }
                                }
                        }
                    }
                }
                
                // Live Bus Markers
                ForEach(buses) { bus in
                    let stop = bus.route.stops[min(bus.currentStopIndex, bus.route.stops.count - 1)]
                    Annotation(bus.number, coordinate: CLLocationCoordinate2D(latitude: stop.coordinate.lat, longitude: stop.coordinate.lon)) {
                        Button {
                            selectedBus = bus
                        } label: {
                            BusMarker(bus: bus, relativeTo: fromStop, theme: theme)
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onAppear {
                snapAllRoutes()
            }
            .onChange(of: buses) { _, newBuses in
                snapAllRoutes()
            }
            
            // Top Header for Dismiss
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(theme.current.secondaryText)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                
                Spacer()
            }
            
            // Bottom Sheet for Selected Bus
            if let bus = selectedBus {
                VStack {
                    Spacer()
                    BusMapDetailCard(bus: bus, fromStop: fromStop, theme: theme) {
                        selectedBus = nil
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func snapAllRoutes() {
        Task {
            for bus in buses {
                let stops = bus.route.stops
                let snapped = await RoadSnapService.shared.snap(stops: stops)
                await MainActor.run {
                    snappedPolylines[bus.id] = snapped
                }
            }
        }
    }
}

struct BusMarker: View {
    let bus: Bus
    let relativeTo: String
    let theme: ThemeManager
    
    var body: some View {
        VStack(spacing: 4) {
            // Info Label
            VStack(alignment: .center, spacing: 2) {
                Text(bus.number)
                    .font(.caption2.bold())
                
                let isHalted = bus.liveTelemetry.isHalted
                let statusText = bus.isDeviated ? "Deviated" : (isHalted ? "Halted" : "Running")
                Text(statusText)
                    .font(.system(size: 8, weight: .semibold))
                
                if let eta = bus.displayETA {
                    Text("\(eta)m")
                        .font(.system(size: 8, weight: .black))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(markerColor.shadow(.drop(color: .black.opacity(0.2), radius: 2)))
            .cornerRadius(6)
            
            // Icon
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                
                Image(systemName: bus.isDeviated ? "exclamationmark.triangle.fill" : "bus.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
        }
    }

    private var markerColor: Color {
        if bus.isDeviated { return .orange }
        if bus.liveTelemetry.isHalted { return .gray }
        return theme.current.accent
    }
}

struct BusMapDetailCard: View {
    let bus: Bus
    let fromStop: String
    let theme: ThemeManager
    let onClose: () -> Void
    
    @EnvironmentObject var router: AppRouter
    
    private var effectiveStatus: TrackingStatus {
        bus.statusRelativeTo(stopName: fromStop)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(bus.number)
                        .font(.title2.bold())
                    Text(bus.headsign)
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                }
                
                if bus.isDeviated {
                    Text("OFF ROUTE")
                        .font(.caption.bold())
                        .padding(4)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                    Text(bus.isDeviated ? "Off Route" : effectiveStatus.rawValue)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                if let eta = bus.etaMinutes {
                    VStack(alignment: .leading) {
                        Text("ETA")
                            .font(.caption)
                            .foregroundStyle(theme.current.secondaryText)
                        Text("\(eta) mins")
                            .font(.headline)
                    }
                    Spacer()
                }
                VStack(alignment: .leading) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                    Text("\(Int(bus.liveTelemetry.speed)) km/h")
                        .font(.headline)
                }
            }
            
            Button {
                if !bus.isDeviated {
                    router.go(.busSchedule(busID: bus.id.uuidString, searchPoint: fromStop))
                }
            } label: {
                Text(bus.isDeviated ? "Find Alternative Bus" : "Detailed Timeline")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(bus.isDeviated ? Color.orange : theme.current.accent)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(theme.current.background)
        .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
        .shadow(radius: 10)
    }
    
    private var statusColor: Color {
        switch effectiveStatus {
        case .scheduled: return .gray
        case .arriving: return .yellow
        case .arrived: return .green
        case .departed: return .red
        case .halted: return .orange
        case .ended: return .black
        }
    }
}

