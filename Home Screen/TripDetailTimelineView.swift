import SwiftUI
import MapKit

struct TripDetailTimelineView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm: TripDetailTimelineViewModel
    
    @State private var position: MapCameraPosition = .automatic
    
    // Initializer to set initial camera position from VM
    init(tripId: UUID, busNumber: String, startTime: String, endTime: String, trackPoints: [Coord], timelineEvents: [TripTimelineEvent]) {
        let viewModel = TripDetailTimelineViewModel(
            tripId: tripId,
            busNumber: busNumber,
            startTime: startTime,
            endTime: endTime,
            trackPoints: trackPoints,
            timelineEvents: timelineEvents
        )
        self._vm = StateObject(wrappedValue: viewModel)
        // Initialize map camera position
        self._position = State(initialValue: .region(viewModel.mapRegion))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header (Fixed Height)
                header
                    .frame(height: 50)
                    .zIndex(10) // Ensure header is above map if needed, though VStack handles layout
                
                // Map View (45% of available height after header - actually full screen split is requested)
                // User requirement: "Top: Map (fixed height) -> 40–50% of screen"
                // "Bottom: Timeline list (flex) -> fills remaining space"
                // Let's interpret "of screen" relative to the available space in GeometryReader
                
                mapView
                    .frame(height: geometry.size.height * 0.45)
                    .clipped()
                
                // Timeline List (Flex)
                timelineList
                    .frame(maxHeight: .infinity)
                    .background(theme.current.background)
            }
            .background(theme.current.background)
            .ignoresSafeArea(edges: .bottom) // Timeline goes to bottom
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Components
private extension TripDetailTimelineView {
    var header: some View {
        HStack {
            Button {
                router.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Trip Timeline")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(vm.busNumber)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .background(
            GeometryReader { geo in
                LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
                    .frame(height: 100)
                    .position(x: geo.size.width / 2, y: 25)
            }
        )
    }
    
    var mapView: some View {
        Map(position: $position) {
            // Trip Polyline
            if !vm.trackPoints.isEmpty {
                MapPolyline(coordinates: vm.trackPoints.map { $0.cl })
                    .stroke(theme.current.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            
            // Start Marker
            if let first = vm.trackPoints.first {
                Annotation("Start", coordinate: first.cl) {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .background(Circle().fill(.white).frame(width: 24, height: 24))
                        
                        Text("Start")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green))
                    }
                }
            }
            
            // End Marker
            if let last = vm.trackPoints.last {
                Annotation("End", coordinate: last.cl) {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                            .background(Circle().fill(.white).frame(width: 24, height: 24))
                        
                        Text("End")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
            // MapUserLocationButton() // Optional
        }
    }
    
    var timelineList: some View {
        VStack(spacing: 0) {
            // Sticky-like Header info
            HStack {
                Text("Trip Events")
                    .font(.headline.bold())
                    .foregroundStyle(theme.current.text)
                
                Spacer()
                
                Text("\(vm.startTime) - \(vm.endTime)")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.current.border.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(theme.current.card)
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
            .zIndex(1)
            
            // Timeline Content
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.sortedEvents.enumerated()), id: \.element.id) { index, event in
                        timelineEventRow(event, isLast: index == vm.sortedEvents.count - 1)
                    }
                }
                .padding(.bottom, 30) // Bottom padding for content
            }
        }
    }
    
    func timelineEventRow(_ event: TripTimelineEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline Column (Fixed Width)
            ZStack(alignment: .top) {
                // Vertical Line
                if !isLast {
                    Rectangle()
                        .fill(theme.current.border.opacity(0.5))
                        .frame(width: 2)
                        .padding(.top, 14) // Start below dot center
                        .frame(maxHeight: .infinity) // Extends to bottom of row
                }
                
                // Dot
                Circle()
                    .fill(iconColor(for: event.eventType))
                    .frame(width: 12, height: 12)
                    .background(
                        Circle()
                            .fill(theme.current.background)
                            .frame(width: 20, height: 20) // White border
                    )
                    .padding(.top, 8) // Align visually with text baseline
            }
            .frame(width: 44) // Fixed width column
            
            // Content Column
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(vm.formatTime(event.timestamp))
                        .font(.caption.bold())
                        .foregroundStyle(theme.current.secondaryText)
                        .frame(minWidth: 45, alignment: .leading)
                    
                    Text(event.eventType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(iconColor(for: event.eventType)))
                }
                
                Text(event.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.current.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                
                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Gap for visual spacing between logical events
                Spacer().frame(height: 24)
            }
            .padding(.top, 4)
            .padding(.trailing, 20)
            
            Spacer()
        }
        .background(theme.current.background)
    }
    
    func iconColor(for eventType: TripTimelineEvent.EventType) -> Color {
        switch eventType {
        case .tripStart: return .green
        case .stopReached: return theme.current.accent
        case .halt: return .orange
        case .deviation: return .red
        case .tripEnd: return .red
        }
    }
}
