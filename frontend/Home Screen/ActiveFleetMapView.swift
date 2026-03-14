import SwiftUI
import MapKit
import Combine

struct ActiveFleetMapView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var router: AppRouter
    
    // We observe all buses to render their live positions
    @StateObject private var busRepo = BusRepository.shared
    
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    // Track span separately — position.region becomes nil after panning (MapKit bug)
    @State private var currentSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    @State private var currentCenter = CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090)
    @State private var liveBuses: [GPSPoint] = []
    @State private var availableRoutes: [String] = []
    @State private var selectedRoute: String? = nil
    @State private var timer: Timer? = nil
    @State private var wsSubscription: AnyCancellable? = nil
    
    // Instead of a full `Bus` (which requires schedule routes), 
    // the live map just needs the raw telemetry.
    @State private var selectedPoint: GPSPoint?
    
    @State private var hasFetchedOnce = false
    @State private var isFirstCenter = true
    
    @State private var isSearchVisible = false
    @State private var isFilterVisible = true
    @State private var searchText = ""
    @State private var isFetchingDetails = false
    @State private var isFollowingSelectedBus = true

    // MARK: - Optimization State
    @State private var quadtree: Quadtree?
    @State private var clusters: [BusCluster] = []
    private let refreshThrottle = Throttler(interval: 0.5) // Max 2 updates per second
    
    // Smooth Interpolation
    @State private var interpolatedLiveBuses: [String: GPSPoint] = [:]
    @State private var interpolationTimer: Timer?

    // MARK: - Historical Mode
    @State private var isHistoricalMode = false
    @State private var showHistoryCalendar = false
    @State private var historicalDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var historyTrips: [AdminHistoryTrip] = []
    @State private var isLoadingHistory = false
    @State private var selectedHistTrip: AdminHistoryTrip? = nil

    // Playback State
    @State private var playbackTime: Double = 0.0 // 0.0 to 1.0 (start to end of day)
    @State private var playbackSpeed: Double = 1.0
    @State private var isPlaybackPaused: Bool = true
    @State private var playbackTimer: Timer? = nil

    private let histDateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // Route color palette for historical polylines
    private let routePalette: [Color] = [.blue, .orange, .green, .purple, .red, .teal, .pink, .yellow, .indigo, .cyan]
    private func routeColor(for name: String) -> Color {
        let h = abs(name.hashValue) % routePalette.count; return routePalette[h]
    }
    
    private var isZoomedOut: Bool {
        currentSpan.latitudeDelta > 0.05
    }

    private var filteredBuses: [GPSPoint] {
        guard !isHistoricalMode else { return [] }
        
        // Use Quadtree for O(log N) frustum culling
        var base: [GPSPoint] = []
        if let tree = quadtree {
            let range = QuadtreeRect.fromRegion(MKCoordinateRegion(center: currentCenter, span: currentSpan), buffer: 1.5)
            tree.query(in: range, found: &base)
        } else {
            base = liveBuses
        }

        if !searchText.isEmpty {
            base = base.filter {
                $0.route_name?.localizedCaseInsensitiveContains(searchText) == true ||
                String($0.bus_id ?? 0).contains(searchText)
            }
        }
        if let route = selectedRoute {
            base = base.filter { $0.route_name == route }
        }
        return base.filter { $0.status?.lowercased() != "completed" && $0.status?.lowercased() != "ended" }
    }

    // New computed property to get live Bus objects, filtered by headsign
    private var liveBusesFilteredByHeadsign: [Bus] {
        if let route = selectedRoute {
            return BusRepository.shared.allBuses.filter { $0.headsign == route }
        }
        return BusRepository.shared.allBuses
    }

    private var filteredHistTrips: [AdminHistoryTrip] {
        guard isHistoricalMode else { return [] }
        if let route = selectedRoute {
            return historyTrips.filter { $0.route_name == route }
        }
        return historyTrips
    }
    
    var body: some View {
        ZStack {
            mapView
            zoomControls
            overlayContent
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { startLiveUpdates() }
        .onDisappear {
            timer?.invalidate()
            wsSubscription?.cancel()
            // Don't fully disconnect WebSocket — other views may use it
        }
        .sheet(isPresented: $showHistoryCalendar) {
            calendarSheet
        }
        .onChange(of: position) { newPos in
            // Basic heuristic: if position changes but it's not a programatic animation, 
            // the user likely panned. 
            // MapKit's Map(position:) is tricky, but let's just use it to disable follow 
            // if the user drags.
            if isFollowingSelectedBus {
                isFollowingSelectedBus = false
            }
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        VStack(spacing: 0) {
            appBar
            
            if isSearchVisible {
                PremiumSearchBar(text: $searchText, theme: theme)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    .zIndex(5)
            }
            
            if isFilterVisible && selectedPoint == nil {
                filterPills
            }
            
            Spacer()
        }
        .padding(.top, 10)
        .safeAreaPadding(.top)
        
        if let pt = selectedPoint, !isHistoricalMode {
            infoCardView(pt: pt)
        } else if isHistoricalMode {
            if let trip = selectedHistTrip {
                historyDetailCard(for: trip)
            } else {
                playbackOverlay
            }
        } else if isLoadingHistory {
            VStack { Spacer(); ProgressView("Loading historical fleet…"); Spacer() }
        } else if isHistoricalMode && historyTrips.isEmpty {
            emptyHistoryView
        } else if !hasFetchedOnce && !isHistoricalMode {
            loadingView
        } else if liveBuses.isEmpty && busRepo.allBuses.isEmpty && !isHistoricalMode {
            emptyStateView
        }
    }

    @ViewBuilder
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // ── All Routes pill ──
                let allCount = isHistoricalMode ? historyTrips.count : liveBuses.count
                routePill(
                    label: "All Routes",
                    count: allCount,
                    isActive: selectedRoute == nil,
                    color: theme.current.accent
                )
                .onTapGesture { withAnimation(.spring()) { selectedRoute = nil } }

                // ── One pill per distinct route_name ──
                ForEach(availableRoutes, id: \.self) { routeName in
                    let count = isHistoricalMode
                        ? historyTrips.filter { $0.route_name == routeName }.count
                        : BusRepository.shared.allBuses.filter { $0.headsign == routeName }.count
                    routePill(
                        label: routeName,
                        count: count,
                        isActive: selectedRoute == routeName,
                        color: isHistoricalMode ? routeColor(for: routeName) : theme.current.routePurple
                    )
                    .onTapGesture { withAnimation(.spring()) { selectedRoute = routeName } }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.85).blur(radius: 5))
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(4)
    }
    
    // MARK: - Subviews
    
    // zoomControls moved to its primary location at line 504

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bus.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.current.accent.opacity(0.3))
            Text("No Active Buses")
                .font(.headline)
            Text("There are no live buses tracking right now. Check back during active hours!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.current.secondaryText)
                .padding(.horizontal, 40)
        }
        .padding(32)
        .background(theme.current.card)
        .cornerRadius(24)
        .shadow(radius: 10)
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange.opacity(0.8))
            Text("No Fleet History")
                .font(.headline)
                .foregroundStyle(theme.current.text)
            Text("No fleet history found for \(histDateFmt.string(from: historicalDate)).")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.current.secondaryText)
                .padding(.horizontal, 40)
            
            Button("Switch to Live") {
                withAnimation {
                    isHistoricalMode = false
                    startLiveUpdates()
                }
            }
            .font(.subheadline.bold())
            .padding(.top, 8)
        }
        .padding(32)
        .background(theme.current.card)
        .cornerRadius(24)
        .shadow(radius: 10)
    }

    private var selectedMapBus: Bus? {
        guard let pt = selectedPoint else { return nil }
        return BusRepository.shared.allBuses.first(where: { 
            $0.extTripId == pt.ext_trip_id || ($0.vehicleId != nil && $0.vehicleId == pt.trip_id)
        })
    }
    
    private func markerColor(for pt: GPSPoint) -> Color {
        routeColor(for: pt.route_name ?? "Default")
    }

    private func getPlannedCoords(for bus: Bus) -> [CLLocationCoordinate2D] {
        bus.route.plannedPolyline.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    private func getActualCoords(for bus: Bus) -> [CLLocationCoordinate2D] {
        bus.actualPolyline.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    @MapContentBuilder
    private func plannedRouteContent(for bus: Bus) -> some MapContent {
        if !bus.route.plannedPolyline.isEmpty {
            MapPolyline(coordinates: getPlannedCoords(for: bus))
                .stroke(theme.current.secondaryText.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [6, 6]))
        }
    }

    @MapContentBuilder
    private func actualRouteContent(for bus: Bus) -> some MapContent {
        if !bus.actualPolyline.isEmpty {
            MapPolyline(coordinates: getActualCoords(for: bus))
                .stroke(routeColor(for: bus.headsign), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
    }

    @MapContentBuilder
    private func stopsContent(for bus: Bus) -> some MapContent {
        if !bus.route.stops.isEmpty {
            ForEach(0..<bus.route.stops.count, id: \.self) { index in
                let isFirst = index == 0
                let isLast = index == bus.route.stops.count - 1
                let isTerminal = isFirst || isLast
                Annotation(isTerminal ? bus.route.stops[index].name : "", coordinate: bus.route.stops[index].coordinate.cl) {
                    if isFirst {
                        Text("📍").font(.system(size: 24)).foregroundStyle(.green).shadow(radius: 2, y: 1)
                    } else if isLast {
                        Text("📍").font(.system(size: 24)).foregroundStyle(.red).shadow(radius: 2, y: 1)
                    } else {
                        Text("📍").font(.system(size: 14)).foregroundStyle(theme.current.accent)
                    }
                }
            }
        }
    }

    @MapContentBuilder
    private func busRouteContent(for bus: Bus) -> some MapContent {
        plannedRouteContent(for: bus)
        actualRouteContent(for: bus)
        stopsContent(for: bus)
    }

    @MapContentBuilder
    private var fleetMarkers: some MapContent {
        if isZoomedOut && !isHistoricalMode {
            // Render Clusters when zoomed out
            ForEach(clusters) { cluster in
                Annotation(cluster.routeNames.joined(separator: ", "), coordinate: cluster.coordinate) {
                    ClusterMarker(cluster: cluster, theme: theme)
                }
            }
        } else {
            // Render individual markers when zoomed in or in historical mode
            ForEach(filteredBuses) { pt in
                Annotation(pt.route_name ?? "\(pt.bus_id ?? 0)", coordinate: CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lng)) {
                    Button {
                        withAnimation(.spring()) {
                            selectedPoint = pt
                        }
                    } label: {
                        PremiumMarker(busNumber: pt.route_name ?? "?", theme: theme, isSelected: selectedPoint?.id == pt.id, color: markerColor(for: pt))
                    }
                }
            }
        }
    }

    private var selectedBuses: [Bus] {
        if let b = selectedMapBus { return [b] }
        return BusRepository.shared.allBuses.filter { bus in
            filteredBuses.contains { pt in
                bus.extTripId == pt.ext_trip_id || (bus.vehicleId != nil && bus.vehicleId == pt.trip_id)
            }
        }
    }

    private func handlePointSelected(_ newPt: GPSPoint?) {
        guard let pt = newPt else { return }
        isFollowingSelectedBus = true
        
        // Try to find existing, or create a transient one
        var bus = BusRepository.shared.allBuses.first(where: {
            $0.extTripId == pt.ext_trip_id || ($0.vehicleId != nil && $0.vehicleId == pt.trip_id)
        })
        
        let isNewBus = (bus == nil)
        if bus == nil {
            // Compute delay label from live data
            let delayMin = Int(pt.delay_min ?? 0)
            let delayLabel: String = delayMin > 2 ? "Delayed \(delayMin) min" : (pt.source == "realtime" ? "Live" : "Scheduled")
            let etaMins: Int? = delayMin > 0 ? delayMin : nil

            // Create a skeleton bus for live visualization
            let rt = pt.route_name?.replacingOccurrences(of: "Route ", with: "") ?? "DTC"
            let newBus = Bus(
                id: UUID(),
                number: String(pt.bus_id ?? 0),
                headsign: pt.direction ?? "Destination",
                departsAt: "Now",
                durationText: "Live",
                status: delayMin > 2 ? .delayed : .onTime,
                statusDetail: delayLabel,
                trackingStatus: .arriving,
                etaMinutes: etaMins,
                route: Route(
                    from: pt.from_stop_name ?? "Start",
                    to: pt.to_stop_name ?? "End",
                    stops: []
                ),
                vehicleId: pt.trip_id,
                busId: pt.bus_id,
                extTripId: pt.ext_trip_id
            )
            bus = newBus
            // Register skeleton immediately so it appears in selectedBuses
            BusRepository.shared.register(bus: newBus)
        }

        Task {
            if let b = bus, b.route.stops.isEmpty {
                await MainActor.run { isFetchingDetails = true }
                do {
                    let rt = pt.route_name?.replacingOccurrences(of: "Route ", with: "") ?? "CTA"
                    let dir = pt.direction ?? "Eastbound"
                    let vid = String(pt.trip_id ?? 0)
                    let details = try await APIService.shared.fetchFullTripDetails(routeId: rt, direction: dir, vehicleId: vid)
                    
                    let newStops = details.timeline.map { stop in
                        Stop(
                            id: stop.stop_id,
                            name: stop.stop_name,
                            coordinate: Coord(lat: Double(stop.lat) ?? 0, lon: Double(stop.lng) ?? 0),
                            timeText: stop.eta,
                            isMajorStop: stop.is_major,
                            stopOrder: 0
                        )
                    }
                    
                    await MainActor.run {
                        var updatedBus = b
                        updatedBus.route.stops = newStops
                        if !details.polyline.isEmpty {
                            updatedBus.route.plannedPolyline = details.polyline.map { Coord(lat: $0.lat, lon: $0.lng) }
                        }
                        // Important: Register it so it shows up in selectedBuses / MapContent
                        BusRepository.shared.register(bus: updatedBus)
                        
                        isFetchingDetails = false
                        centerMapOnStops(newStops)
                    }
                } catch {
                    print("ActiveFleetMapView: Error fetching lazy stops - \(error)")
                    await MainActor.run { isFetchingDetails = false }
                }
            } else if let b = bus {
                centerMapOnStops(b.route.stops)
            }
        }
    }
    
    private func centerMapOnStops(_ stops: [Stop]) {
        guard !stops.isEmpty else { return }
        
        var minLat = 90.0, maxLat = -90.0
        var minLon = 180.0, maxLon = -180.0
        
        for stop in stops {
            let lat = stop.coordinate.lat
            let lon = stop.coordinate.lon
            minLat = min(minLat, lat)
            maxLat = max(maxLat, lat)
            minLon = min(minLon, lon)
            maxLon = max(maxLon, lon)
        }
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(maxLat - minLat + 0.02, 0.02), longitudeDelta: max(maxLon - minLon + 0.02, 0.02))
        
        withAnimation(.easeInOut(duration: 1.5)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private var mapView: some View {
        Map(position: $position, interactionModes: .all) {
                // ── Historical Mode: Draw GPS breadcrumbs + Playback Markers ──
                if isHistoricalMode {
                    // Full paths
                    ForEach(filteredHistTrips) { trip in
                        if !trip.points.isEmpty {
                            MapPolyline(coordinates: trip.points.map {
                                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                            })
                            .stroke(
                                routeColor(for: trip.route_name).opacity(0.3),
                                style: StrokeStyle(lineWidth: selectedHistTrip?.id == trip.id ? 8 : 4,
                                                  lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    
                    // Playback Markers (Dynamic)
                    ForEach(playbackPoints) { pt in
                        Annotation(pt.route_name ?? "?", coordinate: CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lng)) {
                            PremiumMarker(busNumber: pt.route_name ?? "?", theme: theme, isSelected: false, color: routeColor(for: pt.route_name ?? ""))
                                .scaleEffect(0.8)
                        }
                    }
                } else {
                // ── Live Mode ──
                fleetMarkers
                ForEach(selectedBuses) { bus in
                    busRouteContent(for: bus)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .onChange(of: selectedPoint) { _, newPt in
            handlePointSelected(newPt)
        }
        .onMapCameraChange { ctx in
            currentCenter = ctx.region.center
            currentSpan   = ctx.region.span
            
            // Re-calculate clusters on camera change (debounced via state change)
            updateClusters()
        }
    }
    
    private func updateClusters() {
        guard isZoomedOut else {
            if !clusters.isEmpty { clusters = [] }
            return
        }
        
        let newClusters = ClusteringAlgorithm.shared.cluster(
            points: filteredBuses,
            distanceThreshold: 0.15, // Group buses within 15% of screen width
            region: MKCoordinateRegion(center: currentCenter, span: currentSpan)
        )
        
        if clusters.count != newClusters.count {
            clusters = newClusters
        }
    }
    
    private var zoomControls: some View {
        VStack(spacing: 12) {
            if selectedPoint != nil {
                Button {
                    withAnimation { isFollowingSelectedBus.toggle() }
                } label: {
                    Image(systemName: isFollowingSelectedBus ? "location.fill" : "location")
                        .font(.title3.bold())
                        .foregroundStyle(isFollowingSelectedBus ? .white : theme.current.accent)
                        .frame(width: 44, height: 44)
                        .background(isFollowingSelectedBus ? theme.current.accent : theme.current.card)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            
            Button { adjustZoom(factor: 0.5) } label: {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.text)
                    .frame(width: 44, height: 44)
                    .background(theme.current.card)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            Button { adjustZoom(factor: 2.0) } label: {
                Image(systemName: "minus")
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.text)
                    .frame(width: 44, height: 44)
                    .background(theme.current.card)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            // Re-centre + Refresh merged: tap = re-centre, long-press = refresh
            Button {
                recentre()
                refresh()
            } label: {
                Image(systemName: "location.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.accent)
                    .frame(width: 44, height: 44)
                    .background(theme.current.card)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
        .padding(.leading, 16)
        .padding(.bottom, 40)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func adjustZoom(factor: Double) {
        // Use tracked span — position.region is nil after user pans the map
        let newLat = min(max(currentSpan.latitudeDelta * factor, 0.002), 60.0)
        let newLng = min(max(currentSpan.longitudeDelta * factor, 0.002), 60.0)
        currentSpan = MKCoordinateSpan(latitudeDelta: newLat, longitudeDelta: newLng)
        withAnimation(.easeInOut) {
            position = .region(MKCoordinateRegion(center: currentCenter, span: currentSpan))
        }
    }

    private func recentre() {
        guard let first = filteredBuses.first else { return }
        let center = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)
        currentCenter = center
        withAnimation(.easeInOut) {
            position = .region(MKCoordinateRegion(center: center, span: currentSpan))
        }
    }

    
    @ViewBuilder
    private func routePill(label: String, count: Int, isActive: Bool, color: Color) -> some View {
        HStack(spacing: 5) {
            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
            }
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .white : theme.current.text)
                .lineLimit(1)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(isActive ? .white.opacity(0.8) : theme.current.secondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((isActive ? Color.white.opacity(0.25) : theme.current.text.opacity(0.1)))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isActive ? color : theme.current.card)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? color : theme.current.text.opacity(0.12), lineWidth: 1.5)
        )
        .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: 8, y: 3)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }


    private var appBar: some View {
        HStack(spacing: 10) {
            Button {
                if selectedPoint != nil { selectedPoint = nil }
                else { router.back() }
            } label: {
                Image(systemName: selectedPoint != nil ? "xmark" : "arrow.left")
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.text)
                    .padding(12)
                    .background(theme.current.card)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4)
            }

            Spacer()

            HStack(spacing: 8) {
                if selectedPoint == nil {
                    Circle()
                        .fill(WebSocketService.shared.isConnected ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
                
                Text(selectedPoint != nil ? "Bus Details" : "Live Fleet")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.current.text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(theme.current.card.opacity(0.9))
            .cornerRadius(16)

            Spacer()

            // Search
            Button {
                withAnimation(.spring()) {
                    isSearchVisible.toggle()
                    if isSearchVisible { isFilterVisible = false }
                }
            } label: {
                Image(systemName: isSearchVisible ? "xmark" : "magnifyingglass")
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.accent)
                    .padding(12)
                    .background(theme.current.card)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4)
            }

            // Filter toggle
            Button {
                withAnimation(.spring()) {
                    isFilterVisible.toggle()
                    if isFilterVisible { isSearchVisible = false }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.bold())
                    .foregroundStyle(isFilterVisible ? .white : theme.current.accent)
                    .padding(12)
                    .background(isFilterVisible ? theme.current.accent : theme.current.card)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4)
            }

            // Historical Calendar toggle (Admin only)
            if SessionManager.shared.userRole == "admin" {
                Button {
                    showHistoryCalendar = true
                } label: {
                    Image(systemName: isHistoricalMode ? "calendar.badge.clock" : "calendar")
                        .font(.title3.bold())
                        .foregroundStyle(isHistoricalMode ? .white : theme.current.accent)
                        .padding(12)
                        .background(isHistoricalMode ? Color.orange : theme.current.card)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Playback UI & Logic
    
    private var playbackOverlay: some View {
        VStack(spacing: 12) {
            Spacer()
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatPlaybackTime())
                            .font(.title3.bold().monospacedDigit())
                        Text(histDateFmt.string(from: historicalDate))
                            .font(.caption)
                            .foregroundStyle(theme.current.secondaryText)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        ForEach([1.0, 2.0, 4.0], id: \.self) { speed in
                            Button("\(Int(speed))x") {
                                playbackSpeed = speed
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(playbackSpeed == speed ? theme.current.accent : theme.current.background)
                            .foregroundStyle(playbackSpeed == speed ? .white : theme.current.text)
                            .cornerRadius(8)
                        }
                    }
                }
                
                HStack(spacing: 16) {
                    Button {
                        isPlaybackPaused.toggle()
                        if !isPlaybackPaused { startPlaybackTimer() }
                        else { playbackTimer?.invalidate() }
                    } label: {
                        Image(systemName: isPlaybackPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(theme.current.accent)
                            .clipShape(Circle())
                    }
                    
                    Slider(value: $playbackTime, in: 0...1)
                        .tint(theme.current.accent)
                }
            }
            .padding(20)
            .background(theme.current.card)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }
    
    private func formatPlaybackTime() -> String {
        let totalSeconds = playbackTime * 86400
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let step = (playbackSpeed * 0.1) / 3600 // normalized step per 0.1s
            playbackTime = min(1.0, playbackTime + (step * 20)) // Scaling for visibility
        }
    }
    
    private var playbackPoints: [GPSPoint] {
        let currentTimeInSec = playbackTime * 86400
        return historyTrips.compactMap { trip -> GPSPoint? in
            // Logic to find interpolated point for trip at currentTimeInSec
            // For simplicity, find closest point in trip.points
            let points = trip.points
            guard !points.isEmpty else { return nil }
            
            // Simple: return the point whose timestamp is nearest to playbackTime
            // In a real app, we'd interpolate lat/lng between the two nearest points
            let closest = points.min(by: { abs(timeToSeconds($0.ts) - currentTimeInSec) < abs(timeToSeconds($1.ts) - currentTimeInSec) })
            
            if let p = closest {
                return GPSPoint.make(
                    busId: nil,
                    tripId: trip.trip_id,
                    lat: p.lat,
                    lng: p.lng,
                    speed: p.speed,
                    heading: 0,
                    routeName: trip.route_name,
                    ts: p.ts,
                    extVehicleId: trip.bus_number,
                    extTripId: String(trip.trip_id ?? 0),
                    status: "historical",
                    direction: nil
                )
            }
            return nil
        }
    }
    
    @ViewBuilder
    private func historyDetailCard(for trip: AdminHistoryTrip) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(trip.bus_number)
                            .font(.title2.bold())
                        Text(trip.route_name)
                            .font(.subheadline)
                            .foregroundStyle(theme.current.secondaryText)
                    }
                    Spacer()
                    Button { withAnimation { selectedHistTrip = nil } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Label("\(trip.points.count) Points", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    Spacer()
                    if let first = trip.points.first?.ts, let last = trip.points.last?.ts {
                        Text("\(first.suffix(8)) - \(last.suffix(8))")
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.current.secondaryText)
            }
            .padding(20)
            .background(theme.current.card)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }

    @ViewBuilder
    private var calendarSheet: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $historicalDate,
                    in: ...Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(theme.current.accent)
                .padding()

                PrimaryButton(title: "Load Historical Fleet") {
                    showHistoryCalendar = false
                    isHistoricalMode = true
                    timer?.invalidate()
                    selectedPoint = nil
                    selectedHistTrip = nil
                    loadHistoryTrips()
                }
                .padding()

                if isHistoricalMode {
                    Button("Back to Live") {
                        showHistoryCalendar = false
                        isHistoricalMode = false
                        selectedHistTrip = nil
                        historyTrips = []
                        startLiveUpdates()
                    }
                    .foregroundStyle(.red)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Fleet History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showHistoryCalendar = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func timeToSeconds(_ ts: String?) -> Double {
        guard let ts, ts.count >= 8 else { return 0 }
        let timePart = String(ts.suffix(8)) // "HH:MM:SS"
        let parts = timePart.split(separator: ":")
        if parts.count == 3, let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) {
            return h * 3600 + m * 60 + s
        }
        return 0
    }
    
    
    private func infoCardView(pt: GPSPoint) -> some View {
        VStack {
            Spacer()
            if isFetchingDetails {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Fetching Route Details...")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(theme.current.card)
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom))
            } else {
                FleetBusDetailCard(point: pt, theme: theme) {
                    withAnimation { selectedPoint = nil }
                } onTrack: {
                    if let matchedBus = BusRepository.shared.allBuses.first(where: { 
                        $0.extTripId == pt.ext_trip_id || ($0.vehicleId != nil && $0.vehicleId == pt.trip_id)
                    }) {
                        router.go(.busSchedule(busID: matchedBus.id.uuidString))
                    } else {
                        withAnimation { selectedPoint = nil }
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .zIndex(10)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Connecting to Live Fleet...")
                    .font(.headline)
                    .foregroundStyle(theme.current.secondaryText)
            }
            .padding(32)
            .background(theme.current.card)
            .cornerRadius(24)
            .shadow(radius: 20)
            Spacer()
        }
    }

    func refresh() {
        Task { await fetch() }
    }

    func loadHistoryTrips() {
        let dateStr = histDateFmt.string(from: historicalDate)
        isLoadingHistory = true
        Task {
            do {
                let trips = try await APIService.shared.fetchAdminHistoryMap(date: dateStr)
                await MainActor.run {
                    historyTrips = trips
                    isLoadingHistory = false
                    // Update route filter pills with history routes
                    availableRoutes = Array(Set(trips.map { $0.route_name })).sorted()
                    // Auto-center map on first trip's points
                    if !trips.isEmpty {
                        centerMapOnHistory(trips)
                    }
                }
            } catch {
                await MainActor.run { isLoadingHistory = false }
                print("loadHistoryTrips error: \(error)")
            }
        }
    }

    func startLiveUpdates() {
        // 1. Connect WebSocket (no-op if already connected)
        WebSocketService.shared.connect()

        // 2. Subscribe to GPS pushes from WebSocket
        wsSubscription = WebSocketService.shared.gpsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] vehicles in
                // Convert WSVehicle → GPSPoint (compatible with existing map rendering)
                let pts: [GPSPoint] = vehicles.compactMap { (v: WSVehicle) -> GPSPoint? in
                    guard let lat = Double(v.lat ?? ""), let lng = Double(v.lon ?? "") else { return nil }
                    return GPSPoint.make(
                        busId: nil,
                        tripId: Int(v.vid ?? "0"),
                        lat: lat,
                        lng: lng,
                        speed: Double(v.spd ?? 0),
                        heading: Double(v.hdg ?? "0") ?? 0,
                        routeName: v.rt,
                        ts: v.tmstmp,
                        extVehicleId: v.vid,
                        extTripId: v.vid,
                        status: v.dly == true ? "delayed" : "active",
                        direction: v.dir
                    )
                }
                guard !pts.isEmpty else { return }
                
                self.refreshThrottle.throttle {
                    self.hasFetchedOnce = true
                    withAnimation(.linear(duration: 1.0)) {
                        self.liveBuses = pts
                    }
                    
                    // Rebuild Quadtree for fast spatial queries
                    let tree = Quadtree(boundary: QuadtreeRect(minLat: 28.0, maxLat: 29.0, minLon: 76.0, maxLon: 78.0), capacity: 32)
                    for pt in pts { tree.insert(pt) }
                    self.quadtree = tree
                    
                    let routes = Array(Set(pts.compactMap { $0.route_name })).sorted()
                    self.availableRoutes = routes
                    
                    // Re-calculate clusters if needed
                    self.updateClusters()
                }
                
                // Track following logic (non-throttled for smoothness)
                if isFollowingSelectedBus, let sel = selectedPoint,
                   let updated = pts.first(where: { $0.id == sel.id }) {
                    let center = CLLocationCoordinate2D(latitude: updated.lat, longitude: updated.lng)
                    withAnimation(.linear(duration: 0.5)) {
                        self.position = .region(MKCoordinateRegion(center: center, span: self.currentSpan))
                    }
                }
                
                if isFirstCenter, let first = pts.first {
                    let center = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)
                    withAnimation {
                        self.position = .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)))
                    }
                    self.isFirstCenter = false
                }
            }

        // 3. Kick off an initial HTTP fetch immediately (covers the brief WS handshake window)
        Task { await fetch() }

        // 4. Fallback Timer — only polls if WebSocket is disconnected (15s interval)
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [self] _ in
            if !WebSocketService.shared.isConnected {
                refresh()
            }
        }
    }
    
    func fetch() async {
        do {
            let pts = try await APIService.shared.fetchLiveFleetGPS()
            await MainActor.run {
                self.hasFetchedOnce = true
                withAnimation(.linear(duration: 1.0)) {
                    self.liveBuses = pts
                }
                
                // Extract distinct route names for filtering
                let routes = Set(pts.compactMap { $0.route_name }).sorted()
                self.availableRoutes = routes
                
                // If it's the first fetch and we have points, center the map on the first one
                if !pts.isEmpty && isFirstCenter {
                    if let firstPt = pts.first {
                        let center = CLLocationCoordinate2D(latitude: firstPt.lat, longitude: firstPt.lng)
                        withAnimation {
                            self.position = .region(MKCoordinateRegion(
                                center: center,
                                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                            ))
                        }
                        self.isFirstCenter = false
                    }
                }
            }
            
            // Only hydrate if zoomed in enough AND not too many points (Performance check)
            if !isZoomedOut && pts.count < 100 {
                await hydrateMissingRoutes(pts)
            }
        } catch {
            print("Failed to fetch live fleet: \(error)")
        }
    }
    
    private func centerMapOnHistory(_ trips: [AdminHistoryTrip]) {
        let allPoints = trips.flatMap { $0.points }
        guard !allPoints.isEmpty else { return }
        
        var minLat = 90.0, maxLat = -90.0
        var minLon = 180.0, maxLon = -180.0
        
        for pt in allPoints {
            minLat = min(minLat, pt.lat)
            maxLat = max(maxLat, pt.lat)
            minLon = min(minLon, pt.lng)
            maxLon = max(maxLon, pt.lng)
        }
        
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(maxLat - minLat + 0.05, 0.1), longitudeDelta: max(maxLon - minLon + 0.05, 0.1))
        
        withAnimation(.easeInOut(duration: 1.5)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func hydrateMissingRoutes(_ points: [GPSPoint]) async {
        for pt in points {
            let bus = BusRepository.shared.allBuses.first(where: {
                $0.extTripId == pt.ext_trip_id || ($0.vehicleId != nil && $0.vehicleId == pt.trip_id)
            })
            
            if bus == nil || bus?.route.stops.isEmpty == true {
                do {
                    let rt = pt.route_name ?? "CTA"
                    let dir = bus?.statusDetail?.contains("East") == true ? "Eastbound" : "Westbound"
                    let vid = String(pt.trip_id ?? 0)
                    let details = try await APIService.shared.fetchFullTripDetails(routeId: rt, direction: dir, vehicleId: vid)
                    
                    let newStops = details.timeline.map { stop in
                        Stop(id: stop.stop_id, name: stop.stop_name, coordinate: Coord(lat: Double(stop.lat) ?? 0, lon: Double(stop.lng) ?? 0), timeText: stop.eta, isMajorStop: stop.is_major, stopOrder: 0)
                    }
                    
                    await MainActor.run {
                        if let index = BusRepository.shared.allBuses.firstIndex(where: { 
                            $0.extTripId == pt.ext_trip_id || ($0.vehicleId != nil && $0.vehicleId == pt.trip_id)
                        }) {
                            var updatedBus = BusRepository.shared.allBuses[index]
                            updatedBus.route.stops = newStops
                            if !details.polyline.isEmpty {
                                updatedBus.route.plannedPolyline = details.polyline.map { Coord(lat: $0.lat, lon: $0.lng) }
                            }
                            BusRepository.shared.register(bus: updatedBus)
                        } else {
                            // Create Virtual Bus
                            let delayMin = Int(pt.delay_min ?? 0)
                            let delayLabel: String = delayMin > 2 ? "Delayed \(delayMin) min" : (pt.source == "realtime" ? "Live" : "Scheduled")
                            let virtualBus = Bus(
                                id: UUID(),
                                number: pt.ext_vehicle_id ?? "Bus",
                                headsign: pt.route_name ?? "DTC",
                                departsAt: "--",
                                durationText: "--",
                                status: delayMin > 2 ? .delayed : .onTime,
                                statusDetail: delayLabel,
                                trackingStatus: .arriving,
                                etaMinutes: delayMin > 0 ? delayMin : nil,
                                route: Route(
                                    from: newStops.first?.name ?? "",
                                    to: newStops.last?.name ?? "",
                                    stops: newStops,
                                    plannedPolyline: details.polyline.map { Coord(lat: $0.lat, lon: $0.lng) }
                                ),
                                vehicleId: pt.trip_id,
                                busId: pt.bus_id,
                                extTripId: pt.ext_trip_id
                            )
                            BusRepository.shared.register(bus: virtualBus)
                        }
                    }
                } catch {
                    print("ActiveFleetMapView: Error background hydrating stops for \(pt.route_name ?? "CTA") - \(error)")
                }
            }
        }
    }
}


struct FleetBusDetailCard: View {
    let point: GPSPoint
    let theme: ThemeManager
    let onClose: () -> Void
    let onTrack: () -> Void
    
    var body: some View {
        let bus = BusRepository.shared.allBuses.first(where: { 
            $0.extTripId == point.ext_trip_id || ($0.vehicleId != nil && $0.vehicleId == point.trip_id)
        })
        
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.ext_vehicle_id ?? "Bus \(point.bus_id ?? 0)")
                        .font(.title2.bold())
                    Text(point.route_name ?? "Trip \(point.trip_id ?? 0)")
                        .font(.subheadline)
                        .foregroundStyle(theme.current.secondaryText)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.current.secondaryText.opacity(0.5))
                }
            }
            
            // Live Status & Schedule Summary
            if let b = bus {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SPEED")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(theme.current.secondaryText)
                            Text("\(Int(point.speed ?? 0)) km/h")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(theme.current.accent)
                        }
                        
                        if let next = b.nextStopName ?? (b.currentStopIndex + 1 < b.route.stops.count ? b.route.stops[b.currentStopIndex + 1].name : nil) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NEXT STOP")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(theme.current.secondaryText)
                                Text(next)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(theme.current.text)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        let isHalted = (point.speed ?? 0) < 0.5
                        Circle()
                            .fill(isHalted ? Color.orange : Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 2)
                    }
                    
                    Divider()
                    
                    // Stop Summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIMELINE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(theme.current.secondaryText)
                        
                        let stops = b.route.stops
                        let reached = b.currentStopIndex
                        
                        if stops.isEmpty {
                            Text("No stop schedule data available for this live bus.")
                                .font(.caption)
                                .italic()
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                                        HStack(spacing: 12) {
                                            let isPassed = index < reached
                                            let isCurrent = index == reached
                                            let isActive = isPassed || isCurrent
                                            
                                            // Timeline Dot
                                            ZStack {
                                                if index != stops.count - 1 {
                                                    Rectangle()
                                                        .fill(isActive ? theme.current.accent : theme.current.secondaryText.opacity(0.3))
                                                        .frame(width: 2)
                                                        .offset(y: 12)
                                                }
                                                Circle()
                                                    .fill(isCurrent ? theme.current.accent : (isPassed ? theme.current.text : theme.current.secondaryText.opacity(0.3)))
                                                    .frame(width: 10, height: 10)
                                            }
                                            .frame(width: 14)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(stop.name)
                                                    .font(isCurrent ? .subheadline.bold() : .caption)
                                                    .foregroundStyle(isActive ? theme.current.text : theme.current.secondaryText)
                                                    .lineLimit(1)
                                                
                                                if isCurrent {
                                                    Text("Next Stop")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(theme.current.accent)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(stop.timeText ?? "--:--")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(isPassed ? theme.current.secondaryText : theme.current.accent)
                                                if isPassed {
                                                    Text("Departed")
                                                        .font(.system(size: 9))
                                                        .foregroundStyle(theme.current.secondaryText)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(height: 140)
                        }
                    }
                }
                .padding(12)
                .background(theme.current.background)
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.caption)
                                .foregroundStyle(theme.current.secondaryText)
                            
                            let isHalted = (point.speed ?? 1.0) < 0.5
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isHalted ? Color.orange : Color.green)
                                    .frame(width: 8, height: 8)
                                Text(isHalted ? "Halted" : "Moving")
                                    .font(.headline)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speed")
                                .font(.caption)
                                .foregroundStyle(theme.current.secondaryText)
                            let kmh = Int(point.speed ?? 0)
                            Text("\(kmh) km/h")
                                .font(.headline)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(theme.current.background)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TIMELINE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(theme.current.secondaryText)
                        
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(theme.current.accent)
                            Text("Next stops and timeline not loaded.")
                                .font(.caption)
                                .foregroundStyle(theme.current.secondaryText)
                            Spacer()
                            Button("Load Timeline") {
                                // This is a bit of a hack, but it will trigger hydration
                                Task {
                                    // Normally handled by the map's task but we can re-trigger
                                    if let details = try? await APIService.shared.fetchFullTripDetails(routeId: point.route_name ?? "CTA", direction: "Eastbound", vehicleId: point.ext_vehicle_id ?? "0") {
                                        // The hydrate logic in the map should pick this up or we can extend APIService to auto-register
                                    }
                                }
                            }
                            .font(.caption.bold())
                        }
                    }
                    .padding(12)
                    .background(theme.current.background)
                    .cornerRadius(12)
                }
            }
            
            Button(action: onTrack) {
                Text("Track Full Schedule")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(theme.current.accent)
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .padding(.bottom, 30)
        .background(theme.current.card)
        .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        .task {
            if let b = bus {
                await BusRepository.shared.ensureStops(for: b.id)
            }
        }
    }
}


// MARK: - Optimization Components

struct ClusterMarker: View {
    let cluster: BusCluster
    let theme: ThemeManager
    
    var body: some View {
        ZStack {
            Circle()
                .fill(theme.current.accent)
                .frame(width: 32, height: 32)
                .shadow(radius: 4)
            
            Text("\(cluster.count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

class Throttler {
    private var lastRun: Date = Date.distantPast
    private let interval: TimeInterval
    
    init(interval: TimeInterval) {
        self.interval = interval
    }
    
    func throttle(action: @escaping () -> Void) {
        if Date().timeIntervalSince(lastRun) >= interval {
            lastRun = Date()
            action()
        }
    }
}
