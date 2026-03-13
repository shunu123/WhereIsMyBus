import SwiftUI
import MapKit

struct BusScheduleView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    let bus: Bus
    let searchPoint: String?
    let destinationStop: String?
    let sLat: Double?
    let sLon: Double?
    let dLat: Double?
    let dLon: Double?

    @StateObject private var vm: LiveTrackingViewModel
    @State private var showingCalendar = false
    @State private var showAlarm = false
    @State private var selectedDate = Date()

    init(bus: Bus, searchPoint: String? = nil, destinationStop: String? = nil, sourceLat: Double? = nil, sourceLon: Double? = nil, destLat: Double? = nil, destLon: Double? = nil) {
        self.bus = bus
        self.searchPoint = searchPoint
        self.destinationStop = destinationStop
        self.sLat = sourceLat
        self.sLon = sourceLon
        self.dLat = destLat
        self.dLon = destLon
        
        let sCoord = (sourceLat != nil && sourceLon != nil) ? Coord(lat: sourceLat!, lon: sourceLon!) : nil
        let dCoord = (destLat != nil && destLon != nil) ? Coord(lat: destLat!, lon: destLon!) : nil
        
        _vm = StateObject(wrappedValue: LiveTrackingViewModel(bus: bus, sourceStop: searchPoint, destinationStop: destinationStop, sourceCoord: sCoord, destinationCoord: dCoord))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            ZStack(alignment: .top) {
                // Background
                Color.white
                
                // Scrolling List of Stops
                stopsListView
            }
            .background(Color.white)
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            actionButtons
        }
        .sheet(isPresented: $showingCalendar) {
            calendarSheet
        }
        .sheet(isPresented: $showAlarm) {
            SetAlarmSheetView(vm: vm)
                .environmentObject(theme)
        }
        .onAppear {
            vm.start()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        ZStack(alignment: .topLeading) {
            // Background
            LinearGradient(colors: theme.current.primaryGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Nav Bar
                HStack {
                    Button {
                        router.back()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    
                    Text(bus.number)
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                    
                    if SessionManager.shared.userRole == "admin" {
                        Button {
                            showingCalendar.toggle()
                        } label: {
                            Image(systemName: "calendar")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(.white.opacity(0.2)))
                        }
                    }
                    
                    Spacer()
                    
                    // Dedicated Refresh Button (top right)
                    Button {
                        vm.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(.white.opacity(0.2)))
                    }
                }
                .padding(.top, 60) // Clears dynamic island
                .padding(.horizontal, 16)
                
                // From → To Destination Bar & Duration
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(bus.route.from)
                            Image(systemName: "arrow.right")
                            Text(bus.route.to)
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        
                        Text(bus.headsign)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            
                        // "View Map" Action
                        Button {
                            let isStudent = SessionManager.shared.userRole != "admin"
                            router.go(.liveTracking(
                                busID: bus.id, 
                                isHistorical: isStudent ? false : vm.isHistorical, 
                                date: isStudent ? Date() : vm.selectedDate, 
                                sourceStop: searchPoint, 
                                destinationStop: destinationStop,
                                sourceLat: sLat,
                                sourceLon: sLon,
                                destLat: dLat,
                                destLon: dLon
                            ))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                Text("View Map")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .foregroundStyle(.white)
                            .cornerRadius(20)
                        }
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Prominent Duration
                    durationBadge(eta: vm.durationToDestination)
                }
                .padding(.bottom, 20)
            }
            .padding(20)
        }
        .frame(height: 220)
    }

    private func durationBadge(eta: Int) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("DURATION")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(eta)")
                    .font(.system(size: 44, weight: .black))
                Text("min")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
        }
    }

    private var stopsListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status + Delay indicator
            HStack {
                Circle()
                    .fill(bus.status == .onTime ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(bus.statusDetail ?? bus.status.rawValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(bus.status == .onTime ? .green : .orange)
                Spacer()
                
                // Delay label if delayed
                if let detail = bus.statusDetail, detail.lowercased().contains("delay") {
                    Label(detail, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                
                Text("Today, \(selectedDate, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            
            // Pre-origin bus position banner
            if let fromStop = searchPoint, let busPosition = busPositionBeforeOrigin(from: fromStop) {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bus not yet at \(fromStop)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        Text("Currently at: \(busPosition)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
                .padding(12)
                .background(theme.current.accent)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if filteredStops.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 40)
                            Image(systemName: "clock.badge")
                                .font(.system(size: 64))
                                .foregroundStyle(.gray.opacity(0.5))
                            Text("Scheduled Every Day")
                                .font(.title3.bold())
                                .foregroundStyle(theme.current.accent)
                            Text("The basic schedule runs daily. Detailed stops are yet to be updated.")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        let liveIndex = bus.currentStopIndex
                        ForEach(Array(filteredStops.enumerated()), id: \.element.id) { index, stop in
                            stopRow(index: index, stop: stop, liveIndex: liveIndex)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            // No pull-to-refresh: user must use the dedicated Refresh button in header
        }
    }
    
    // Compute only the stops between selected origin and destination
    private var filteredStops: [Stop] {
        let allStops = vm.stops
        guard !allStops.isEmpty else { return [] }
        
        let fromName = searchPoint?.lowercased() ?? ""
        let toName = destinationStop?.lowercased() ?? ""
        
        if fromName.isEmpty && toName.isEmpty { return allStops }
        
        let targetFromIdx = allStops.firstIndex(where: { $0.name.lowercased().contains(fromName) }) ?? 0
        let toIdx = allStops.lastIndex(where: { $0.name.lowercased().contains(toName) }) ?? (allStops.count - 1)
        
        // If the bus is currently BEFORE our selected 'from' stop, 
        // start the timeline from the bus's current position instead.
        let busIdx = bus.currentStopIndex
        let startIdx = min(targetFromIdx, busIdx)
        
        guard startIdx <= toIdx else { return allStops }
        return Array(allStops[startIdx...toIdx])
    }
    
    // Returns the current stop name if the bus hasn't reached the origin yet
    private func busPositionBeforeOrigin(from: String) -> String? {
        let allStops = vm.stops
        guard !allStops.isEmpty else { return nil }
        
        let fromIdx = allStops.firstIndex(where: { $0.name.lowercased().contains(from.lowercased()) }) ?? 0
        let currentIdx = bus.currentStopIndex
        
        if currentIdx < fromIdx {
            return allStops.indices.contains(currentIdx) ? allStops[currentIdx].name : "En route"
        }
        return nil
    }

    private func stopRow(index: Int, stop: Stop, liveIndex: Int) -> some View {
        let originalIndex = bus.route.stops.firstIndex(where: { $0.id == stop.id }) ?? index
        let isPast = vm.isHistorical ? (bus.historyStops.first(where: { $0.stopName == stop.name })?.reachedTime != nil) : (originalIndex < liveIndex)
        let isCurrent = vm.isHistorical ? false : (originalIndex == liveIndex)
        let isUpcoming = vm.isHistorical ? (bus.historyStops.first(where: { $0.stopName == stop.name })?.reachedTime == nil) : (originalIndex > liveIndex)
        
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                timelineIndicator(index: index, originalIndex: originalIndex, liveIndex: liveIndex, isCurrent: isCurrent)
                stopContent(index: index, stop: stop, originalIndex: originalIndex, liveIndex: liveIndex, isCurrent: isCurrent, isUpcoming: isUpcoming, isPast: isPast)
                Spacer()
            }
            .padding(.horizontal, 8)
            
            if bus.isDeviated && originalIndex == vm.deviationStartStopIndex {
                deviationMarkerRow
            }
        }
    }

    private func timelineIndicator(index: Int, originalIndex: Int, liveIndex: Int, isCurrent: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(originalIndex <= liveIndex ? Color.blue : Color.gray.opacity(0.1))
                .frame(width: 2)
                .frame(height: 10)
                .opacity(index == 0 ? 0 : 1)
            
            ZStack {
                Circle()
                    .fill(originalIndex <= liveIndex ? Color.blue : Color.white)
                    .frame(width: 12, height: 12)
                
                if originalIndex > liveIndex {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                        .frame(width: 12, height: 12)
                }
                
                if isCurrent {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                        .frame(width: 22, height: 22)
                }
            }
            
            Rectangle()
                .fill(originalIndex < liveIndex ? Color.blue : Color.gray.opacity(0.1))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .opacity(index == vm.stops.count - 1 ? 0 : 1)
        }
        .frame(width: 40)
    }

    @ViewBuilder
    private func stopContent(index: Int, stop: Stop, originalIndex: Int, liveIndex: Int, isCurrent: Bool, isUpcoming: Bool, isPast: Bool) -> some View {
        let stopIndex = index
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(stop.name)
                    .font(.system(size: 17, weight: isCurrent ? .bold : .semibold))
                    .foregroundStyle(isPast ? .secondary : .primary)

                if vm.alarmEnabled, stop.name == vm.alarmStopName {
                    HStack(spacing: 2) {
                        Image(systemName: "bell.fill")
                        Text("Alarm Set")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
            }

            // Scheduled / ETA time chip
            if let timeStr = stop.timeText, !timeStr.isEmpty, timeStr != "0 min" {
                HStack(spacing: 4) {
                    Image(systemName: isCurrent ? "location.fill" : (isPast ? "checkmark.circle.fill" : "clock"))
                        .font(.system(size: 10))
                        .foregroundStyle(isCurrent ? .blue : (isPast ? .green : .secondary))
                    Text(isPast ? "Reached \(timeStr)" : (isCurrent ? "Arriving now" : "ETA \(timeStr)"))
                        .font(.caption.bold())
                        .foregroundStyle(isCurrent ? .blue : (isPast ? .green : .secondary))
                }
            } else if isCurrent {
                Text("Arriving now")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }

            // Deviation / delay badges
            if bus.isDeviated && originalIndex == vm.deviationStartStopIndex {
                EmptyView()
            } else if bus.isDeviated && isUpcoming {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption2)
                    Text("Delayed due to deviation")
                }
                .font(.caption.bold())
                .foregroundStyle(.orange)
            } else if let status = bus.statusDetail, status.lowercased().contains("delay"), isUpcoming {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark").font(.caption2)
                    Text(status)
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 28)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                showAlarm.toggle()
            } label: {
                HStack {
                    Image(systemName: vm.alarmEnabled ? "bell.fill" : "bell")
                    Text(vm.alarmEnabled ? "Alarm On" : "Set Alarm")
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background {
                    if vm.alarmEnabled {
                        Rectangle().fill(Color.orange.gradient)
                    } else {
                        Rectangle().fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing))
                    }
                }
                .foregroundStyle(.white)
                .cornerRadius(25)
                .shadow(color: (vm.alarmEnabled ? Color.orange : theme.current.accent).opacity(0.3), radius: 8, y: 4)
            }
            
            Button {
                vm.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Circle().fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing)))
                    .shadow(radius: 4)
            }
            
            if let next = vm.nextStop {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT STOP")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.secondary)
                    Text(next.name)
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
        .padding(.bottom, 30)
    }

    private var deviationMarkerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Bus deviated from route here")
                .font(.caption.bold())
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(.leading, 40)
        .padding(.bottom, 16)
    }

    private var calendarSheet: some View {
        VStack {
            DatePicker("Select Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
            
            Button("Confirm") {
                vm.selectedDate = selectedDate
                showingCalendar = false
                vm.refresh()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
            .padding()
        }
        .presentationDetents([.medium])
    }
}
