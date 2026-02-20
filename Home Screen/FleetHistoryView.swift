import SwiftUI
import MapKit

struct FleetHistoryView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm = FleetHistoryViewModel()
    @State private var showingDatePicker = false
    @State private var showingRouteFilter = false
    @State private var showTripDetails = false
    
    // Bottom Sheet State
    @State private var sheetOffset: CGFloat = 0
    @State private var isSheetExpanded = false
    
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 13.0475, longitude: 80.1167),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )

    var body: some View {
        GeometryReader { screenGeometry in
            ZStack {
                // 1. Full Screen Map
                mapView
                    .ignoresSafeArea()
                
                // 2. Floating Controls (Top Safe Area)
                VStack(spacing: 0) {
                    topControls
                        .padding(.horizontal)
                        .padding(.top, 8) // Small adjustments for safe area
                    Spacer()
                }
                .safeAreaPadding(.top)
                
                // 3. Bottom Sheet (Draggable)
                VStack {
                    Spacer()
                    draggableBottomSheet(screenHeight: screenGeometry.size.height)
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(10)
                
                // 4. Sheets (Modals)
                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(Material.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingRouteFilter) {
            routeFilterSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: vm.visibleRoutes) { _, _ in
            updateMapRegion()
        }
        .onAppear {
            vm.loadHistory(for: vm.selectedDate)
            updateMapRegion()
        }
    }
    
    func updateMapRegion() {
        guard !vm.filteredTrips.isEmpty else { return }
        
        var allCoords: [Coord] = []
        for trip in vm.filteredTrips {
            allCoords.append(contentsOf: trip.actualPolyline)
        }
        
        guard !allCoords.isEmpty else { return }
        
        let lats = allCoords.map { $0.lat }
        let lons = allCoords.map { $0.lon }
        
        let minLat = lats.min() ?? 13.0
        let maxLat = lats.max() ?? 13.1
        let minLon = lons.min() ?? 80.0
        let maxLon = lons.max() ?? 80.1
        
        // Add padding
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.5
        let spanLon = (maxLon - minLon) * 1.5
        
        withAnimation(.easeInOut(duration: 1.0)) {
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.05), longitudeDelta: max(spanLon, 0.05))
            )
        }
    }

    // MARK: Route List / Bottom Sheet
    func draggableBottomSheet(screenHeight: CGFloat) -> some View {
        let expandedHeight = screenHeight - 100 // Dynamic height based on available space
        
        return GeometryReader { geometry in
            VStack(spacing: 0) {
                // Handle Area
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
                .background(theme.current.card)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // If showing details, drag effectively dismisses details or does nothing
                            if vm.selectedTrip != nil {
                                if value.translation.height > 50 {
                                    withAnimation { vm.selectedTrip = nil }
                                }
                                return
                            }
                            
                            // Calculate new height manually or just track offset
                            let potentialHeight = partialHeight - value.translation.height
                            if potentialHeight > collapsedHeight && potentialHeight < expandedHeight {
                                // Real-time drag? For simplicity, we just detect end
                            }
                        }
                        .onEnded { value in
                            if vm.selectedTrip != nil { return }
                            
                            // Drag Thresholds
                            let dragThreshold: CGFloat = 50
                            
                            if value.translation.height < -dragThreshold {
                                // Dragged Up -> Expand
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isSheetExpanded = true
                                }
                            } else if value.translation.height > dragThreshold {
                                // Dragged Down -> Collapse
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isSheetExpanded = false
                                }
                            }
                        }
                )
                
                // Content
                ZStack(alignment: .top) {
                    theme.current.card.ignoresSafeArea()
                    
                    if let _ = vm.selectedTrip {
                         tripDetailContent
                             .transition(.opacity)
                    } else {
                         routeListContent
                             .transition(.opacity)
                    }
                }
            }
            .frame(height: isSheetExpanded ? expandedHeight : (vm.selectedTrip != nil ? 400 : partialHeight))
            .cornerRadius(24, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.15), radius: 20, y: -5)
        }
        .frame(height: isSheetExpanded ? expandedHeight : (vm.selectedTrip != nil ? 400 : partialHeight))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSheetExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.selectedTrip)
    }
    

}

// MARK: - Subviews
private extension FleetHistoryView {
    
    // MARK: Top Controls
    var topControls: some View {
        HStack {
            // Back Button
            Button {
                router.back()
            } label: {
                Circle()
                    .fill(Material.thickMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.1), radius: 4)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.current.text)
                    )
            }
            
            Spacer()
            
            // Date Picker Button
            Button {
                showingDatePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.subheadline.bold())
                    Text(formattedDate)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Material.thickMaterial)
                .foregroundColor(theme.current.text)
                .cornerRadius(22)
                .shadow(color: .black.opacity(0.1), radius: 4)
            }
            
            // Filter Button
            Button {
                showingRouteFilter = true
            } label: {
                Circle()
                    .fill(vm.visibleRoutes.count == vm.groupedRoutes.count ? Material.thickMaterial : Material.regular)
                    .frame(width: 44, height: 44)
                    .background(
                         vm.visibleRoutes.count == vm.groupedRoutes.count ? Color.clear : theme.current.accent
                    )
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.1), radius: 4)
                    .overlay(
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(vm.visibleRoutes.count == vm.groupedRoutes.count ? theme.current.text : .white)
                    )
            }
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: vm.selectedDate)
    }
    
    // MARK: Map View
    var mapView: some View {
        Map(position: .constant(.region(mapRegion))) {
            // Destination
            Annotation(vm.destinationName, coordinate: vm.destinationHub.cl) {
                VStack(spacing: 2) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white, theme.current.accent)
                        .background(Circle().fill(.white))
                    
                    Text("Saveetha")
                        .font(.caption2.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.9)))
                        .shadow(radius: 2)
                }
            }
            
            // Polylines & Buses
            ForEach(Array(vm.filteredTrips.enumerated()), id: \.element.id) { index, trip in
                let isSelected = vm.selectedTrip?.id == trip.id
                
                ForEach(Array(trip.segments.enumerated()), id: \.element.id) { segIndex, segment in
                    MapPolyline(coordinates: segment.coords.map { $0.cl })
                        .stroke(segment.isDiverted ? Color.red : theme.current.accent.opacity(isSelected ? 1.0 : 0.6),
                                style: StrokeStyle(lineWidth: isSelected ? 5 : 3,
                                                 lineCap: .round, lineJoin: .round))
                }
                
                // Show bus marker only at the end coordinate (destination for completed, or last known)
                if let last = trip.actualPolyline.last {
                    Annotation(trip.busNumber, coordinate: last.cl) {
                        Button {
                            withAnimation(.spring()) {
                                if vm.selectedTrip?.id == trip.id {
                                    vm.selectedTrip = nil
                                } else {
                                    vm.selectedTrip = trip
                                }
                            }
                        } label: {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(theme.current.accent.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                }
                                
                                Image(systemName: "bus.fill")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Circle().fill(trip.isDeviated ? Color.red : theme.current.accent))
                                    .shadow(radius: 3)
                            }
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
    
    // MARK: - Draggable Bottom Sheet Logic
    
    // Constants for sheet heights
    private var collapsedHeight: CGFloat { 80 }
    private var partialHeight: CGFloat { 320 }
    // expandedHeight is now calculated dynamically in the view
    

    
    var routeListContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fleet Activity")
                        .font(.title3.bold())
                        .foregroundColor(theme.current.text)
                    Text("\(vm.filteredTrips.count) trips recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Toggle expansion button
                Button {
                    withAnimation { isSheetExpanded.toggle() }
                } label: {
                    Image(systemName: isSheetExpanded ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.current.accent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.allTrips.isEmpty {
                        Text("No trips found for this date")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    } else {
                        ForEach(vm.filteredGroupedRoutes) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Circle()
                                        .fill(theme.current.accent)
                                        .frame(width: 8, height: 8)
                                    Text(group.startCity)
                                        .font(.headline)
                                        .foregroundColor(theme.current.text)
                                    Spacer()
                                    Text("\(group.trips.count)")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(theme.current.accent))
                                }
                                
                                ForEach(group.trips) { trip in
                                    Button {
                                        withAnimation {
                                            vm.selectedTrip = trip
                                            isSheetExpanded = false // Collapse when selecting details
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(trip.busNumber)
                                                    .font(.headline)
                                                    .foregroundColor(theme.current.text)
                                                HStack(spacing: 6) {
                                                    if trip.isDeviated {
                                                        Text("Diverted")
                                                            .font(.caption2.bold())
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.red.opacity(0.1))
                                                            .foregroundColor(.red)
                                                            .cornerRadius(4)
                                                    }
                                                    Text(trip.status)
                                                        .font(.caption)
                                                        .foregroundColor(trip.status == "COMPLETED" ? .green : .secondary)
                                                }
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text(trip.duration)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(theme.current.text)
                                                Text(trip.endTime)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(theme.current.background)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Bottom safe area buffer
            }
        }
    }
    
    var tripDetailContent: some View {
        VStack(spacing: 0) {
            // Header with Close
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bus \(vm.selectedTrip?.busNumber ?? "Unknown")")
                        .font(.title2.bold())
                        .foregroundColor(theme.current.text)
                    Text(vm.selectedTrip?.routeName ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation { vm.selectedTrip = nil }
                } label: {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.gray)
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            Divider()
            
            // Trip Stats
            if let trip = vm.selectedTrip {
                ScrollView {
                    VStack(spacing: 24) {
                        // Timeline like stats
                        HStack(spacing: 0) {
                            TripStatItem(title: "Start", value: trip.startTime, icon: "clock")
                            Divider()
                            TripStatItem(title: "Duration", value: trip.duration, icon: "hourglass")
                            Divider()
                            TripStatItem(title: "Status", value: trip.status, icon: "checkmark.circle", valueColor: trip.status == "COMPLETED" ? .green : .primary)
                        }
                        .padding(.vertical, 8)
                        
                        // Timeline Button
                        Button {
                             // Use existing navigation logic to timeline
                            navigateToTimeline(for: trip)
                        } label: {
                            HStack {
                                Text("View Detailed Timeline")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(theme.current.accent)
                            .cornerRadius(16)
                            .shadow(color: theme.current.accent.opacity(0.3), radius: 8, y: 4)
                        }
                        
                        // Deviation Warning
                        if trip.isDeviated {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Route Deviation Detected")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text("This bus deviated from its assigned route path.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // Helper view for stats
    func TripStatItem(title: String, value: String, icon: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(valueColor)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    func navigateToTimeline(for trip: FleetHistoryViewModel.HistoryTripDisplay) {
        let allBuses = BusRepository.shared.allBuses
        if let bus = allBuses.first(where: { $0.id == trip.busId }) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateKey = dateFormatter.string(from: vm.selectedDate)
            
            if let record = bus.tripHistory[dateKey] {
                let timelineEvents = vm.generateTimelineEvents(for: trip, historyStops: record.historyStops)
                
                router.go(.tripDetailTimeline(
                    tripId: trip.id,
                    busNumber: trip.busNumber,
                    startTime: trip.startTime,
                    endTime: trip.endTime,
                    trackPoints: trip.actualPolyline,
                    timelineEvents: timelineEvents
                ))
            }
        }
    }

    // MARK: Filter Sheet
    var routeFilterSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Filter Routes")
                    .font(.title3.bold())
                Spacer()
                Button("Done") {
                    showingRouteFilter = false
                }
                .font(.headline)
                .foregroundColor(theme.current.accent)
            }
            .padding(24)
            .background(Material.regular)
            
            List {
                Section {
                    Button {
                        if vm.visibleRoutes.count == vm.groupedRoutes.count {
                             vm.clearAllRoutes()
                        } else {
                             vm.showAllRoutes()
                        }
                    } label: {
                        HStack {
                            Text(vm.visibleRoutes.count == vm.groupedRoutes.count ? "Hide All" : "Show All")
                                .foregroundColor(theme.current.accent)
                            Spacer()
                        }
                    }
                }
                
                Section(header: Text("Routes")) {
                    ForEach(vm.groupedRoutes) { route in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(route.startCity)
                                    .font(.headline)
                                Text("\(route.trips.count) trips")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if vm.visibleRoutes.contains(route.startCity) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(theme.current.accent)
                                    .font(.headline)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.toggleRoute(route.startCity)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
    
    // MARK: Date Picker Sheet
    var datePickerSheet: some View {
        VStack {
            DatePicker("Select Date", selection: $vm.selectedDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
            
            Button("Done") {
                showingDatePicker = false
                vm.loadHistory(for: vm.selectedDate)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(theme.current.accent)
            .cornerRadius(12)
            .padding()
        }
    }
}
