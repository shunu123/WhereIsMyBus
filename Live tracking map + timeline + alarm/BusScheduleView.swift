import SwiftUI
import MapKit

struct BusScheduleView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    let bus: Bus
    let searchPoint: String?

    @StateObject private var vm: LiveTrackingViewModel
    @State private var showingCalendar = false
    @State private var showAlarm = false
    @State private var selectedDate = Date()

    init(bus: Bus, searchPoint: String? = nil) {
        self.bus = bus
        self.searchPoint = searchPoint
        _vm = StateObject(wrappedValue: LiveTrackingViewModel(bus: bus))
    }

    private var isFutureTrip: Bool {
        Calendar.current.startOfDay(for: vm.selectedDate) > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Blue Card Header
            ZStack(alignment: .topLeading) {
                // Background
                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                        
                        Spacer()
                        
                        Button {
                            vm.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(.white.opacity(0.2)))
                        }

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
                    .padding(.top, 8) 
                    
                    // From → To Destination Bar & Duration (Screen 3)
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(bus.route.stops.first?.name ?? bus.route.from)
                                Image(systemName: "arrow.right")
                                Text(bus.route.stops.last?.name ?? bus.route.to)
                            }
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            
                            Text(bus.headsign)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                                
                            // "View Map" Action
                            Button {
                                router.go(.liveTracking(busID: bus.id, isHistorical: vm.isHistorical, date: vm.selectedDate, sourceStop: searchPoint))
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
                        
                        // Prominent Duration (Screen 3)
                        if let eta = bus.etaMinutes {
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
                    }
                    .padding(.bottom, 20)
                }
                .padding(20)
            }
            .frame(height: 220) 
            
            // 2. Scrollable Schedule List
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.blue)
                    Text("Scheduled Stops")
                        .font(.headline)
                    Spacer()
                }
                .padding(16)
                .background(Color.gray.opacity(0.05))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let displayedStops = searchPoint != nil ? bus.stopsFrom(sourceName: searchPoint!) : bus.route.stops
                        let liveIndex = bus.currentStopIndex
                        
                        ForEach(Array(displayedStops.enumerated()), id: \.element.id) { index, stop in
                            let originalIndex = bus.route.stops.firstIndex(where: { $0.id == stop.id }) ?? index
                            let isPast = originalIndex < liveIndex
                            let isCurrent = originalIndex == liveIndex
                            let isUpcoming = originalIndex > liveIndex
                            
                            VStack(spacing: 0) {
                                HStack(alignment: .top, spacing: 0) {
                                    // 1. Timeline Line & Dots
                                    VStack(spacing: 0) {
                                        // Upper segment
                                        Rectangle()
                                            .fill(originalIndex <= liveIndex ? Color.blue : Color.gray.opacity(0.1))
                                            .frame(width: 2)
                                            .frame(height: 10)
                                            .opacity(index == 0 ? 0 : 1)
                                        
                                        // Dot
                                        ZStack {
                                            Circle()
                                                .fill(isCurrent ? Color.blue : (isPast ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2)))
                                                .frame(width: isCurrent ? 14 : 10, height: isCurrent ? 14 : 10)
                                            
                                            if isCurrent {
                                                Circle()
                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                                                    .frame(width: 22, height: 22)
                                            }
                                        }
                                        
                                        // Lower segment
                                        Rectangle()
                                            .fill(originalIndex < liveIndex ? Color.blue : Color.gray.opacity(0.1))
                                            .frame(width: 2)
                                            .frame(maxHeight: .infinity)
                                            .opacity(index == displayedStops.count - 1 ? 0 : 1)
                                    }
                                    .frame(width: 40)
                                    
                                    // 2. Stop Content
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stop.name)
                                            .font(.system(size: 17, weight: isCurrent ? .bold : .semibold))
                                            .foregroundStyle(isPast ? .secondary : .primary)
                                        
                                        // Time States
                                        Group {
                                            if bus.isDeviated && originalIndex == vm.deviationStartStopIndex {
                                                 // Don't show "Deviated" here if we are showing it below as a marker
                                                 EmptyView()
                                            } else if bus.isDeviated && isUpcoming {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .font(.caption2)
                                                    Text("Bus Deviated")
                                                }
                                                .font(.caption.bold())
                                                .foregroundStyle(.orange)
                                            } else if isPast {
                                                // Arrived: XX:XX  Departed: XX:XX - Requirement 4
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Reached: \(stop.timeText ?? "--:--")")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.secondary)
                                                }
                                            } else if isCurrent {
                                                // Current Position - Requirement 4
                                                Text("Currently here (\(stop.timeText ?? "--:--")")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.blue)
                                            } else if isUpcoming {
                                                // ETA & Expected Arrival - Requirement 4
                                                let diff = originalIndex - liveIndex
                                                let etaMinutes = (diff * 8) + (bus.etaMinutes ?? 0)
                                                let arrivalTime = Calendar.current.date(byAdding: .minute, value: etaMinutes, to: Date()) ?? Date()
                                                
                                                HStack(spacing: 4) {
                                                    Text("ETA: \(etaMinutes) min")
                                                    Text("•")
                                                    Text(arrivalTime, style: .time)
                                                }
                                                .font(.caption.bold())
                                                .foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                    .padding(.bottom, 28)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                
                                if bus.isDeviated && originalIndex == vm.deviationStartStopIndex {
                                    deviationMarkerRow
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            .background(Color.white)
            .cornerRadius(24) // Rounded top corners
            .offset(y: -20) // Overlap slightly
            .overlay(alignment: .topTrailing) {
                // Front-layer Alarm Button (Screen 3)
                if !vm.isHistorical {
                    Button {
                        showAlarm = true
                    } label: {
                        Image(systemName: "bell.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 20)
                    .offset(y: -27) // Center it on the corner
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .overlay(alignment: .top) {
            deviationAlertOverlay
        }
        .overlay(alignment: .top) {
            if let point = searchPoint, bus.statusRelativeTo(stopName: point) == .departed && !vm.isHistorical {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        VStack(alignment: .leading) {
                            Text("You missed this bus")
                                .font(.headline)
                            Text("See catchable buses in the list")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    .padding(.top, 100)
                    .padding(.horizontal)
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
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

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    router.back()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                
                Text("Bus \(bus.number)")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.2)))
                }

                Button {
                    showingCalendar.toggle()
                } label: {
                    Image(systemName: "calendar")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(bus.route.from)  →  \(bus.route.to)")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(.leading, 12)
                
                Spacer()
                
                Chip(text: bus.status.rawValue)
            }
            .padding(.horizontal, 12)
            
            // Timeline Visualization
            HStack(spacing: 0) {
                // Start Station
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text(bus.route.from) 
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .frame(maxWidth: 80)
                }
                
                // Line + Pill
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 2)
                    
                    Text(bus.durationText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                .padding(.horizontal, 4)
                .offset(y: -8) // Shift line up align with dots
                
                // End Station
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text(bus.route.to) 
                        .font(.caption)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .frame(maxWidth: 80)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .padding(.bottom, 24)
        .background(headerBackground)
    }

    @ViewBuilder
    private var headerBackground: some View {
        LinearGradient(
            colors: theme.current.primaryGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea(edges: .top)
    }





    @ViewBuilder
    private var etaBannerView: some View {
        HStack {
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundStyle(theme.current.accent)
            
            let bannerText = bus.statusDetail ?? "Bus is \(bus.trackingStatus.rawValue.lowercased())"
            Text(bannerText)
                .font(.headline)
            Spacer()
            if let eta = bus.etaMinutes {
                Text("\(eta) mins")
                    .font(.title3.bold())
                    .foregroundStyle(theme.current.accent)
            }
        }
        .padding(20)
        .background(theme.current.accent.opacity(0.1))
    }



    @ViewBuilder
    private func stopRow(index: Int, stop: Stop) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(stop.timeText ?? "--:--")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.current.text)
                    .frame(width: 70)
            }
            .padding(.top, 6)
            
            VStack(spacing: 0) {
                timelineIcon(index: index, stop: stop)
                
                if index < bus.route.stops.count - 1 {
                    timelineConnector(index: index, stop: stop)
                }
            }
            .frame(width: 50)
            
                VStack(alignment: .leading, spacing: 4) {
                    let liveIndex = Int(vm.currentIndex)
                    HStack(alignment: .firstTextBaseline) {
                        Text(stop.name)
                            .font(stop.isMajorStop ? .title2.bold() : .headline.weight(.medium))
                            .foregroundStyle((vm.isHistorical || index <= liveIndex) ? theme.current.text : theme.current.secondaryText)
                    
                    platformBadge(for: stop)
                    currentBusBadge(for: index)
                    
                    if let sp = searchPoint, stop.name.lowercased().contains(sp.lowercased()) {
                        searchPointBadge
                    }
                }
                
                stopDetailText(index: index, stop: stop)
                
                Spacer().frame(height: stop.isMajorStop ? 60 : 30)
            }
        }
    }

    @ViewBuilder
    private func timelineIcon(index: Int, stop: Stop) -> some View {
        let liveIndex = Int(vm.currentIndex)
        ZStack {
            Circle()
                .fill((vm.isHistorical || index <= liveIndex) ? theme.current.accent : Color.gray.opacity(0.3))
                .frame(width: stop.isMajorStop ? 20 : 12, height: stop.isMajorStop ? 20 : 12)
            
            if index == liveIndex && !vm.isHistorical { 
                Circle()
                    .stroke(theme.current.accent.opacity(0.3), lineWidth: stop.isMajorStop ? 8 : 4)
                    .frame(width: stop.isMajorStop ? 32 : 20, height: stop.isMajorStop ? 32 : 20)
                
                if bus.trackingStatus == .arriving {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0.5)
                }
            }
        }
    }

    @ViewBuilder
    private func timelineConnector(index: Int, stop: Stop) -> some View {
        let liveIndex = Int(vm.currentIndex)
        Rectangle()
            .fill((vm.isHistorical || index < liveIndex) ? theme.current.accent : Color.gray.opacity(0.2))
            .frame(width: stop.isMajorStop ? 5 : 2)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func platformBadge(for stop: Stop) -> some View {
        if let pf = stop.platformNumber {
            Text(pf)
                .font(.system(size: 10, weight: .black))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.1))
                .foregroundStyle(theme.current.secondaryText)
                .cornerRadius(4)
        }
    }

    @ViewBuilder
    private func currentBusBadge(for index: Int) -> some View {
        let liveIndex = Int(vm.currentIndex)
        if index == liveIndex && !vm.isHistorical {
            HStack(spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.caption)
                Text(vm.currentSpeed == 0 ? "Halted" : bus.trackingStatus.rawValue)
                    .font(.caption.weight(.bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.1))
            .foregroundStyle(statusColor)
            .cornerRadius(10)
        }
    }

    @ViewBuilder
    private var searchPointBadge: some View {
        HStack(spacing: 4) {
             Image(systemName: "person.fill")
                 .font(.caption2)
             Text("MY POINT")
                 .font(.caption2.weight(.black))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.current.accent)
        .foregroundStyle(.white)
    }

    private var statusColor: Color {
        switch bus.trackingStatus {
        case .scheduled: return .gray
        case .arriving: return .yellow
        case .arrived: return .green
        case .departed: return .red
        case .halted: return .orange
        case .ended: return .black
        }
    }
    
    @ViewBuilder
    private var deviationMarkerRow: some View {
        HStack(spacing: 0) {
            // Line
            VStack {
                Rectangle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 4)
                    .frame(height: 40)
            }
            .frame(width: 40)
            
            // Content
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text("Bus Deviated")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .cornerRadius(20)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var deviationAlertOverlay: some View {
        if bus.isDeviated && !vm.isHistorical {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bus Deviated")
                            .font(.headline)
                        Text("bus deviated between \(bus.route.stops[max(0, bus.currentStopIndex - 1)].name) and \(bus.route.stops[min(bus.route.stops.count - 1, bus.currentStopIndex)].name), kindly wait for other bus")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                }
                .padding()
                .background(Color.red)
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.top, 100)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func stopDetailText(index: Int, stop: Stop) -> some View {
        let liveIndex = Int(vm.currentIndex)
        Group {
            if index == liveIndex && !vm.isHistorical {
                Text(vm.currentSpeed == 0 ? "At \(stop.name)" : (bus.statusDetail ?? "Updating live..."))
                    .font(.subheadline)
                    .foregroundStyle(theme.current.secondaryText)
            } else if index > liveIndex && !vm.isHistorical {
                let diff = index - liveIndex
                let eta = (diff * 10) + (bus.etaMinutes ?? 0)
                Text("Arrives in \(eta) mins")
                    .font(stop.isMajorStop ? .headline : .subheadline)
                    .foregroundStyle(theme.current.accent.opacity(stop.isMajorStop ? 1.0 : 0.7))
            } else if vm.isHistorical || index < liveIndex {
                Text("Departed at \(stop.timeText ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(theme.current.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var timelineView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(bus.route.stops.indices, id: \.self) { index in
                    stopRow(index: index, stop: bus.route.stops[index])
                }
            }
            .padding(24)
        }
    }


    @ViewBuilder
    private var bottomButtonsView: some View {
        HStack(spacing: 16) {
            Button {
                router.go(.liveTracking(busID: bus.id, sourceStop: searchPoint))
            } label: {
                viewOnMapButtonLabel
            }
            .disabled(vm.isFuture)
            
            Button {
                showAlarm = true
            } label: {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("Set Alarm")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.8, green: 0.3, blue: 0.1))
                )
            }
        }
        .padding(16)
        .background(theme.current.background)
        .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
    }

    @ViewBuilder
    private var viewOnMapButtonLabel: some View {
        VStack(spacing: 2) {
            HStack {
                Image(systemName: "map.fill")
                Text("View on Map")
            }
            if vm.isFuture {
                Text("Not available for future dates")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.8)
            }
        }
        .font(.headline.weight(.bold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(viewOnMapBackground)
    }

    @ViewBuilder
    private var viewOnMapBackground: some View {
        Group {
            if vm.isFuture {
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewOnMapFutureGradient)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewOnMapCurrentGradient)
            }
        }
    }

    private var viewOnMapFutureGradient: LinearGradient {
        LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
    }

    private var viewOnMapCurrentGradient: LinearGradient {
        LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing)
    }

    @ViewBuilder
    private var calendarSheet: some View {
        VStack {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(theme.current.accent)
                .padding()
            
            PrimaryButton(title: isFuture(selectedDate) ? "View Scheduled Stops" : "View Historical Route") {
                showingCalendar = false
                if isFuture(selectedDate) {
                    vm.selectedDate = selectedDate
                    vm.isHistorical = false
                    vm.start()
                } else {
                    router.go(.liveTracking(busID: bus.id, isHistorical: true, date: selectedDate, sourceStop: searchPoint))
                }
            }
            .padding()
        }
        .presentationDetents([.medium])
    }

    private func isFuture(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }
}
