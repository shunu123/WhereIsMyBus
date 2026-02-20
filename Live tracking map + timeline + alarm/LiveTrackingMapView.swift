import SwiftUI
import MapKit

func calculateBearing(from: Coord, to: Coord) -> Double {
    let lat1 = from.lat * .pi / 180
    let lon1 = from.lon * .pi / 180
    let lat2 = to.lat * .pi / 180
    let lon2 = to.lon * .pi / 180
    
    let dLon = lon2 - lon1
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let y = sin(dLon) * cos(lat2)
    let radians = atan2(y, x)
    return (radians * 180 / .pi) 
}

struct LiveTrackingMapView: View {
    @EnvironmentObject var theme: ThemeManager
    @StateObject var vm: LiveTrackingViewModel

    init(bus: Bus, isHistorical: Bool = false, selectedDate: Date = Date(), sourceStop: String? = nil) {
        _vm = StateObject(wrappedValue: LiveTrackingViewModel(bus: bus, isHistorical: isHistorical, date: selectedDate, sourceStop: sourceStop))
    }


    @State private var position: MapCameraPosition = .automatic
    @State private var showTimeline = false
    @State private var showAlarm = false

    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingCalendar = false
    @State private var showingBusDetails = false
    
    // Scoped properties for builders
    private var busToTrack: Bus {
        vm.selectedBusForDetail ?? vm.bus
    }
    
    private var isDeviatedMode: Bool {
        busToTrack.isDeviated
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.isHistorical && vm.isHistoryEmpty && !vm.showScheduledStopsOnly {
                emptyHistoryView
            } else {
                Map(position: $position) {
                    mapContent
                }
                .ignoresSafeArea()
                
                if vm.isHistorical {
                    VStack {
                        Spacer()
                        if let range = vm.historySearchRange {
                            Text("Searching history from \(range)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Capsule())
                                .padding(.bottom, vm.isHistoryEmpty ? 20 : 250) // Adjust if dashboard is up
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                }
            }
            
            if !isDeviatedMode {
                if !(vm.isHistorical && vm.isHistoryEmpty) {
                    dashboardLayer
                        .ignoresSafeArea(edges: .bottom)
                    
                    topControls
                    
                    mapOverlays
                } else {
                    // Even in empty history, show top controls so user can go back or open calendar
                    topControls
                }
            } else {
                // In deviated mode, show only back button
                VStack {
                    HStack {
                        Button { router.back() } label: {
                            Image(systemName: "arrow.left")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(theme.current.accent)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(theme.current.card).shadow(radius: 2))
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    Spacer()
                    
                    // Requirement 1: Deviated bus = just the map + red polyline + optional back
                    deviationAlertOverlay
                }
            }
        }
        .sheet(isPresented: $showingCalendar) {
            VStack {
                DatePicker("Select Date", selection: $vm.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(theme.current.accent)
                    .padding()
                
                PrimaryButton(title: "View Historical Route") {
                    showingCalendar = false
                    vm.isHistorical = true
                    vm.start()
                }
                .padding()
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            vm.start()
            position = .region(regionForStops(vm.stops))
        }
        .onChange(of: vm.isHistorical) { _, isHist in
            if isHist {
                withAnimation {
                    position = .region(regionForStops(vm.stops))
                }
            }
        }
        .onChange(of: vm.currentCoordinate) { _, newCoord in
            guard vm.autoRecenter && !vm.isHistorical else { return }
            withAnimation(.easeInOut(duration: 3.0)) {
                position = .region(
                    MKCoordinateRegion(
                        center: newCoord.cl,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
        .sheet(isPresented: $showTimeline) {
            RouteTimelineView(stops: vm.stops)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showAlarm) {
            SetAlarmSheetView(vm: vm)
                .environmentObject(theme)
        }
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        // Underlay: Full Planned Route (light blue)
        MapPolyline(coordinates: vm.plannedPolyline.map { $0.cl })
            .stroke(theme.current.accent.opacity(0.4), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

        if busToTrack.isDeviated {
            deviatedMapContent(for: busToTrack)
        } else {
            standardMapContent(for: busToTrack)
        }
    }

    @MapContentBuilder
    private func deviatedMapContent(for busToTrack: Bus) -> some MapContent {
        // 1. Blue segments (On-route actual path)
        ForEach(vm.actualOnRouteSegments) { segment in
            MapPolyline(coordinates: segment.coords.map { $0.cl })
                .stroke(theme.current.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }

        // 2. Red segments (Off-route deviation actual path)
        ForEach(vm.actualOffRouteSegments) { segment in
            MapPolyline(coordinates: segment.coords.map { $0.cl })
                .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        
        if vm.isHistorical {
            // Direction Arrows on ALL actual path
            ForEach(Array(busToTrack.actualPolyline.enumerated()), id: \.offset) { idx, coord in
                if idx % 10 == 0 && idx > 0 && idx < busToTrack.actualPolyline.count - 1 {
                    Annotation("", coordinate: coord.cl) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                            .rotationEffect(Angle(degrees: calculateBearing(from: busToTrack.actualPolyline[idx-1], to: busToTrack.actualPolyline[idx+1])))
                    }
                }
            }
            
            historyMarkers(for: busToTrack)
            rejoinMarkers()
        } else {
            Annotation("Bus \(busToTrack.number)", coordinate: vm.currentCoordinate.cl) {
                BusMapMarker(bus: busToTrack, theme: theme, isMain: true, isSelected: true)
            }
        }
    }

    @MapContentBuilder
    private func rejoinMarkers() -> some MapContent {
        if let start = vm.deviationStartCoord {
            Annotation("Deviation", coordinate: start.cl) {
                VStack(spacing: 0) {
                    Text("Deviation Start")
                        .font(.system(size: 8, weight: .bold))
                        .padding(4)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(180))
                        .offset(y: -4)
                }
            }
        }
        
        if let rejoin = vm.rejoiningCoord {
            Annotation("Rejoin", coordinate: rejoin.cl) {
                VStack(spacing: 0) {
                    Text("Rejoined Route")
                        .font(.system(size: 8, weight: .bold))
                        .padding(4)
                        .background(theme.current.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.current.accent)
                        .rotationEffect(.degrees(180))
                        .offset(y: -4)
                }
            }
        }
    }

    @MapContentBuilder
    private func historyMarkers(for busToTrack: Bus) -> some MapContent {
        if let first = busToTrack.actualPolyline.first {
            Annotation("Start", coordinate: first.cl) {
                MarkerLabel(text: "Start (\(busToTrack.historyStops.first?.reachedTime ?? "--:--"))", color: .green)
            }
        }
        
        if let last = busToTrack.actualPolyline.last {
            Annotation("End", coordinate: last.cl) {
                MarkerLabel(text: "End (\(busToTrack.historyStops.last?.reachedTime ?? "--:--"))", color: .red)
            }
        }
    }

    @MapContentBuilder
    private func standardMapContent(for busToTrack: Bus) -> some MapContent {
        // 1. Blue segments (On-route actual path)
        ForEach(vm.actualOnRouteSegments) { segment in
            MapPolyline(coordinates: segment.coords.map { $0.cl })
                .stroke(theme.current.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        
        // 2. Red segments (Off-route deviation actual path) - though in "standard" this should be empty
        ForEach(vm.actualOffRouteSegments) { segment in
            MapPolyline(coordinates: segment.coords.map { $0.cl })
                .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        
        if vm.isLive && !vm.isHistorical && !vm.isIsolatedMode {
            MapPolyline(coordinates: vm.fullRoutePath.map { $0.cl })
                .stroke(theme.current.accent.opacity(0.1), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [5, 10]))
        }

        ForEach(0..<vm.stops.count, id: \.self) { index in
            stopAnnotation(for: index, stop: vm.stops[index])
        }

        if !vm.isHistorical && (!vm.isIsolatedMode || vm.selectedBusForDetail?.id == vm.bus.id) {
            Annotation("Bus \(vm.bus.number)", coordinate: vm.currentCoordinate.cl) {
                BusMapMarker(bus: vm.bus, theme: theme, isMain: true, isSelected: vm.selectedBusForDetail?.id == vm.bus.id)
                    .onTapGesture { withAnimation(.spring()) { vm.selectedBusForDetail = vm.bus } }
            }
        }
        
        if !vm.isHistorical && !vm.isIsolatedMode {
            let visibleBuses = vm.otherBuses.filter { bus in
                switch bus.trackingStatus {
                case .arriving, .halted: return vm.showUpcoming
                case .departed: return vm.showDeparted
                case .scheduled: return vm.showScheduled
                default: return false
                }
            }
            ForEach(visibleBuses) { otherBus in
                if otherBus.currentStopIndex >= 0 && otherBus.currentStopIndex < otherBus.route.stops.count {
                    let stop = otherBus.route.stops[otherBus.currentStopIndex]
                    Annotation(otherBus.number, coordinate: stop.coordinate.cl) {
                        BusMapMarker(bus: otherBus, theme: theme, isMain: false, isSelected: vm.selectedBusForDetail?.id == otherBus.id)
                            .onTapGesture { withAnimation(.spring()) { vm.selectedBusForDetail = otherBus } }
                    }
                }
            }
        }
    }

    @MapContentBuilder
    private func stopAnnotation(for index: Int, stop s: Stop) -> some MapContent {
        let busToTrack = vm.selectedBusForDetail ?? vm.bus
        let liveIndexValue = (busToTrack.id == vm.bus.id) ? Int(vm.currentIndex) : busToTrack.currentStopIndex
        
        let isPast = index < liveIndexValue
        let isCurrent = index == liveIndexValue
        
        if vm.isHistorical {
            if index == 0 || index == vm.stops.count - 1 {
                Marker(index == 0 ? "START" : "END", coordinate: s.coordinate.cl)
            } else {
                Annotation("", coordinate: s.coordinate.cl) {
                    Circle().fill(theme.current.accent.opacity(0.3)).frame(width: 4, height: 4)
                }
            }
        } else {
            Annotation(s.name, coordinate: s.coordinate.cl) {
                if isCurrent {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.current.accent)
                        .background(Circle().fill(.white))
                } else if isPast {
                    Circle()
                        .fill(theme.current.accent.opacity(0.4))
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private var mapOverlays: some View {
        // Phase 2: Removed Planned/Actual legend as Deviated mode must be "just map + red line"
        EmptyView()
    }

    @ViewBuilder
    private var dashboardLayer: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                if vm.isHistorical {
                    historicalDashboard
                } else {
                    liveDashboard
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(30)
            .shadow(color: Color.black.opacity(0.1), radius: 20, y: -5)
        }
    }

    @ViewBuilder
    private var historicalDashboard: some View {
        let displayBus = vm.selectedBusForDetail ?? vm.bus
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(displayBus.number)
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.accent)
                
                Spacer()
                
                let status = vm.historyTripStatus ?? "COMPLETED"
                let isDeviated = status.uppercased() == "DEVIATED"
                
                Text(status)
                    .font(.caption.bold())
                    .foregroundStyle(isDeviated ? .red : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isDeviated ? Color.red : Color.green).opacity(0.1))
                    .clipShape(Capsule())
            }
            
            if displayBus.isDeviated {
                Text("Trip deviated on this date")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                    .padding(.top, -8)
            }
            
            HStack {
                Text(vm.stops.first?.name ?? "Start")
                Image(systemName: "arrow.right")
                Text(vm.stops.last?.name ?? "End")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.gray)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let historyStops = displayBus.historyStops
                    ForEach(Array(historyStops.enumerated()), id: \.element.id) { idx, hStop in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Circle().fill(hStop.reachedTime != nil ? theme.current.accent : .gray.opacity(0.3)).frame(width: 6, height: 6)
                                Text(hStop.stopName).font(.subheadline.bold())
                                
                                let timeLabel: String = {
                                    if let time = hStop.reachedTime { return " — \(time)" }
                                    
                                    if vm.isHistorical {
                                        let status = (vm.historyTripStatus ?? "COMPLETED").uppercased()
                                        let isDone = status == "COMPLETED" || status == "REACHED" || status == "ENDED" || status == "ARRIVED" || status == "NORMAL" || status == "DEVIATED"
                                        
                                        if isDone {
                                            return " — Time unavailable"
                                        } else {
                                            if historyStops.suffix(from: idx).contains(where: { $0.reachedTime != nil }) {
                                                return " — Time unavailable"
                                            }
                                            return " — Not reached"
                                        }
                                    }
                                    return displayBus.hasReachedDestination ? " — Time unavailable" : " — Not reached"
                                }()
                                
                                Text(timeLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                
                                Spacer()
                                
                                if let _ = hStop.reachedTime, idx > 0 {
                                    Text("+10 min")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray.opacity(0.6))
                                }
                            }
                            .padding(.vertical, 8)
                            
                            // Check if deviation started after this stop (but before next)
                            if displayBus.isDeviated && idx < historyStops.count - 1 {
                                let stopName = hStop.stopName
                                if let realIdx = vm.bus.route.stops.firstIndex(where: { $0.name == stopName }),
                                   realIdx == vm.deviationStartStopIndex {
                                    deviationTimelineMark
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    @ViewBuilder
    private var liveDashboard: some View {
        let displayBus = vm.selectedBusForDetail ?? vm.bus
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayBus.number)
                        .font(.title3.bold())
                        .foregroundStyle(theme.current.accent)
                    
                    let statusText: String = {
                        if displayBus.hasReachedDestination { return "REACHED" }
                        if displayBus.isDeviated { return "DEVIATED" }
                        return (displayBus.liveTelemetry.speedKmph ?? 0) <= 1 ? "STOPPED" : "RUNNING"
                    }()
                    
                    Text(statusText)
                        .font(.caption.bold())
                        .foregroundStyle(statusText == "DEVIATED" ? .red : (statusText == "REACHED" ? .blue : .green))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    if displayBus.hasReachedDestination {
                        // Destination reached state
                        Text("TOTAL TRIP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                        Text("\(displayBus.totalTripDuration ?? 60)m")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(theme.current.accent)
                    } else if (displayBus.liveTelemetry.speedKmph ?? 0) <= 1 {
                        // Stopped state refinement: Replace speed section with prominently displayed Stop Name (if it's not too long)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("STOPPED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.red)
                            Text(vm.nearestStopName.isEmpty ? "Near location" : vm.nearestStopName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }
                    } else {
                        // Speed behavior
                        Text("SPEED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                        
                        if let speed = displayBus.liveTelemetry.speedKmph {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(speed)")
                                    .font(.system(size: 32, weight: .black))
                                Text("km/h")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(theme.current.accent)
                        } else {
                            Text("-- km/h")
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(.gray)
                            Text("Updating...")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            
            Divider()
            
            if displayBus.hasReachedDestination {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bus reached destination")
                        .font(.headline.bold())
                    Text("Reached in \(displayBus.totalTripDuration ?? 60) minutes")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if (displayBus.liveTelemetry.speedKmph ?? 0) <= 1 {
                            Text("Stopped at")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                            Text(vm.nearestStopName.isEmpty ? "Stopped near current location" : vm.nearestStopName)
                                .font(.headline.bold())
                        } else {
                            Text("Next Stop")
                                .font(.caption.bold())
                                .foregroundStyle(.gray)
                            Text(vm.nextStop?.name ?? "Arrived")
                                .font(.headline.bold())
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duration")
                            .font(.caption.bold())
                            .foregroundStyle(.gray)
                        Text("\(vm.durationToDestination) mins")
                            .font(.headline.bold())
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button { showTimeline = true } label: {
                    Text("Detailed Timeline")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.current.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(theme.current.accent.opacity(0.3), lineWidth: 1))
                }
                
                if !displayBus.isDeviated {
                    Button { showAlarm = true } label: {
                        Text("Set Alarm")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var topControls: some View {
        VStack {
            HStack {
                Button { router.back() } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(theme.current.card).shadow(radius: 2))
                }
                Spacer()
                HStack(spacing: 8) {
                    filterButton(title: "Upcoming", color: .blue, isOn: vm.showUpcoming) { vm.showUpcoming.toggle() }
                    filterButton(title: "Departed", color: .red, isOn: vm.showDeparted) { vm.showDeparted.toggle() }
                    filterButton(title: "Scheduled", color: .gray, isOn: vm.showScheduled) { vm.showScheduled.toggle() }
                }
                .padding(4)
                .background(Capsule().fill(Color.white.opacity(0.8)))
                .shadow(radius: 2)
                Spacer()
                Button { showingCalendar = true } label: {
                    Image(systemName: "calendar")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(theme.current.card).shadow(radius: 2))
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var deviationAlertOverlay: some View {
        if vm.bus.isDeviated && !vm.isHistorical {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bus Deviated").font(.headline)
                        Text("bus deviated in \(vm.bus.route.stops[max(0, vm.bus.currentStopIndex - 1)].name) kindly wait for other bus").font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.red)
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.top, 60)
                .padding(.horizontal)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var deviationTimelineMark: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 2)
                .frame(height: 30)
                .padding(.leading, 2)
            
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text("Bus Deviated")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private func filterButton(title: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(isOn ? .white : color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isOn ? color : Color.clear)
                .cornerRadius(4)
        }
    }

    private func regionForStops(_ stops: [Stop]) -> MKCoordinateRegion {
        guard let first = stops.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
                                      span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
        return MKCoordinateRegion(center: first.coordinate.cl,
                                  span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    }
}

struct BusMapMarker: View {
    let bus: Bus
    let theme: ThemeManager
    let isMain: Bool
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .center, spacing: 2) {
                Text(bus.number).font(.caption2.bold())
                let statusText = bus.isDeviated ? "Deviated" : (bus.liveTelemetry.isHalted ? "Halted" : "Running")
                Text(statusText).font(.system(size: 8, weight: .semibold))
                if let eta = bus.displayETA {
                    Text("\(eta)m").font(.system(size: 8, weight: .black))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(markerColor.shadow(.drop(color: .black.opacity(0.2), radius: 2)))
            .cornerRadius(6)
            .scaleEffect(isSelected ? 1.2 : 1.0)
            
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: isMain ? 32 : 24, height: isMain ? 32 : 24)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 0))
                
                Image(systemName: bus.isDeviated ? "exclamationmark.triangle.fill" : "bus.fill")
                    .font(.system(size: isMain ? 16 : 12))
                    .foregroundStyle(.white)
            }
            .scaleEffect(isSelected ? 1.2 : 1.0)
        }
    }
    
    private var markerColor: Color {
        if bus.isDeviated { return .orange }
        if bus.liveTelemetry.isHalted { return .gray }
        return theme.current.accent
    }
}

struct MarkerLabel: View {
    let text: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: 8, weight: .black))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.8))
                .foregroundStyle(.white)
                .cornerRadius(4)
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(color)
                .font(.title3)
        }
    }
}

extension LiveTrackingMapView {
    private var emptyHistoryView: some View {
        VStack(spacing: 16) {
            Image(systemName: vm.isHistoryScheduled ? "clock.badge.exclamationmark" : "calendar.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.gray.opacity(0.5))
            
            Text(vm.isHistoryScheduled ? "Trip scheduled, but tracking history is unavailable for this date." : "No trip recorded for this date")
                .font(.title3.bold())
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                if vm.isHistoryScheduled {
                    Button {
                        vm.showScheduledStopsOnly = true
                    } label: {
                        Text("View Scheduled Stops")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(theme.current.accent)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                }
                
                Button {
                    vm.selectedDate = Date()
                    vm.isHistorical = false
                } label: {
                    Text("Return to Live Tracking")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(vm.isHistoryScheduled ? Color.gray.opacity(0.1) : theme.current.accent)
                        .foregroundStyle(vm.isHistoryScheduled ? theme.current.accent : .white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.isHistoryScheduled ? theme.current.accent : Color.clear, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
