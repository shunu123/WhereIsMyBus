import SwiftUI

struct HomeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var languageManager: LanguageManager
    
    // Inject closure from RouteShellView to handle drawer opening
    var openDrawer: () -> Void

    @StateObject private var vm: HomeViewModel
    @State private var showingManualSearch = false

    init(openDrawer: @escaping () -> Void, locationManager: LocationManager) {
        self.openDrawer = openDrawer
        self._vm = StateObject(wrappedValue: HomeViewModel(locationManager: locationManager))
    }

    var body: some View {
        ZStack(alignment: .bottom) { // Algn to bottom for bottom nav
            theme.current.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header (Squared Green)
                header
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Main Search Card (From/To)
                        mainSearchCard
                        
                        // Secondary Search Actions
                        secondarySearchActions
                        
                        // Search History Section
                        searchHistorySection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 8)
                }
            }
            
            // Bottom Bar
            bottomBar
            
            // Permission Overlay
            if vm.showPermissions {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { vm.skipPermissions() }
                
                PermissionRequestView(
                    onAllow: { vm.requestPermissions() },
                    onDismiss: { vm.skipPermissions() }
                )
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 100) // Above bottom bar
                .zIndex(100)
            }
        }
        .onAppear {
            vm.router = router
            vm.checkPermissions()
            SessionManager.shared.resetIdleTimer()
        }
        .onTapGesture {
            SessionManager.shared.resetIdleTimer()
        }
        .ignoresSafeArea(.all, edges: .top)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingManualSearch) {
            manualSearchSheet
        }
    }
}

// MARK: - Manual Search Sheet
private extension HomeView {
    var manualSearchSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Text(vm.isHistoryMode ? "Search History" : "Search Bus Number")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showingManualSearch = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
            
            Toggle("Search in History", isOn: $vm.isHistoryMode)
                .font(.subheadline.bold())
                .tint(theme.current.accent)
                .padding(.vertical, 4)

            if vm.isHistoryMode {
                DatePicker("Select Date", selection: $vm.historyDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding()
                    .background(theme.current.card)
                    .cornerRadius(12)
            } else {
                Text("Enter the bus number manually to track its live schedule.")
                    .font(.subheadline)
                    .foregroundStyle(theme.current.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Image(systemName: "bus.fill")
                    .foregroundStyle(theme.current.accent)
                TextField("e.g. 500-D, 335-E", text: $vm.busNumberSearch)
                    .font(.title3.bold())
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
            }
            .padding()
            .background(theme.current.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.current.border, lineWidth: 1)
            )

            Button {
                if !vm.busNumberSearch.isEmpty {
                    showingManualSearch = false
                    let allBuses = BusRepository.shared.allBuses
                    guard let bus = allBuses.first(where: { $0.number.contains(vm.busNumberSearch.uppercased()) }) ?? allBuses.first else { return }
                    
                    if vm.isHistoryMode {
                        router.go(.liveTracking(busID: bus.id, isHistorical: true, date: vm.historyDate))
                    } else {
                        router.go(.busSchedule(busID: bus.id))
                    }
                }
            } label: {
                Text(vm.isHistoryMode ? "View Historical Data" : "Track Bus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(theme.current.accent)
                    .cornerRadius(12)
            }
            .disabled(vm.busNumberSearch.isEmpty)
            .opacity(vm.busNumberSearch.isEmpty ? 0.6 : 1.0)

            Spacer()
        }
        .padding(24)
        .background(theme.current.background)
        .presentationDetents([.height(vm.isHistoryMode ? 450 : 350)])
    }
}

// MARK: - Header
private extension HomeView {
    var header: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom)
                .frame(height: 60) // Safe Area cover
                .ignoresSafeArea()
            
            ZStack {
                // Centered Title or Voice Wave
                if vm.voice.isListening {
                    VoiceWaveView(level: vm.voice.audioLevel)
                        .frame(height: 40)
                } else {
                    Text("Where Is My Bus?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }

                // Left Action (Drawer)
                HStack {
                    Button {
                        openDrawer()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }

                // Right Actions (Track + Mic)
                HStack(spacing: 12) {
                    Spacer()
                    
                    /* Removing Bus Icon as per requirement
                    Button {
                         router.go(.trackByNumber(autoStartVoice: false))
                    } label: {
                        Image(systemName: "bus.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    */
                    
                    // Voice Mic
                    Button {
                        if vm.isSpeechAuthorized {
                            if vm.voice.isListening {
                                vm.voice.stop()
                                vm.processVoiceCommand()
                            } else {
                                Task { await vm.voice.start() }
                            }
                        } else {
                            withAnimation {
                                vm.showPermissions = true
                            }
                        }
                    } label: {
                        Image(systemName: vm.voice.isListening ? "stop.fill" : "mic.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .opacity(vm.isSpeechAuthorized ? 1.0 : 0.6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom))
        }
    }
}

struct VoiceWaveView: View {
    @EnvironmentObject var theme: ThemeManager
    var level: Float
    
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<24) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 4, height: max(10, CGFloat(level * 80 * Float.random(in: 0.7...2.0))))
                    .animation(.spring(response: 0.15, dampingFraction: 0.5), value: level)
            }
        }
        .frame(height: 80)
        .padding(.vertical, 10)
    }
}

// MARK: - Components overhaul
private extension HomeView {
    var mainSearchCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Vertical Line + Circles + Bus Logo
                VStack(spacing: 0) {
                    Circle()
                        .fill(theme.current.accent)
                        .frame(width: 12, height: 12)
                    
                    // Connecting line with Bus Logo
                    Rectangle()
                        .fill(theme.current.border)
                        .frame(width: 2, height: 25)
                        .overlay(
                            Image(systemName: "bus.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(theme.current.accent)
                                .background(Circle().fill(theme.current.background).frame(width: 20, height: 20))
                        )
                    
                    Rectangle()
                        .fill(theme.current.border)
                        .frame(width: 2, height: 25)
                    
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 12, height: 12)
                }
                .padding(.leading, 12)

                VStack(spacing: 0) {
                    // Same text field UI for both modes, just different suggestion sources
                    trainStyleInputField(
                        placeholder: "From (e.g. Chennai)",
                        text: $vm.fromText,
                        onTextChange: vm.updateFromSuggestions
                    )
                    .frame(height: 50)
                    
                    Divider()
                    
                    trainStyleInputField(
                        placeholder: "To (e.g. Saveetha)",
                        text: $vm.toText,
                        onTextChange: vm.updateToSuggestions
                    )
                    .frame(height: 50)
                }
                
                // Swap Button
                Button {
                    vm.swap()
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                    
                        .font(.title)
                        .foregroundStyle(theme.current.accent)
                        .background(Circle().fill(theme.current.card))
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 16)
            
            // Integrated Find Button
            Button {
                router.go(.availableBuses(from: vm.fromText, to: vm.toText, via: nil))
                SearchHistoryService.shared.save(from: vm.fromText, to: vm.toText)
            } label: {
                Text(languageManager.localizedString("Search buses"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(8)
                    .padding(16)
            }
        }
        .background(theme.current.background)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.current.border, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            // Suggestions overlay for both modes
            VStack(spacing: 0) {
                // Suggestions List for FROM
                if !vm.fromSuggestions.isEmpty {
                    suggestionList(suggestions: vm.fromSuggestions) { suggestion in
                        vm.selectFrom(suggestion)
                    }
                    .padding(.top, 70) // Position below the From field
                }

                // Suggestions List for TO
                if !vm.toSuggestions.isEmpty {
                    suggestionList(suggestions: vm.toSuggestions) { suggestion in
                        vm.selectTo(suggestion)
                    }
                    .padding(.top, vm.fromSuggestions.isEmpty ? 120 : 0) // Position below the To field
                }
            }
            .padding(.leading, 12) // Start at the same leading as the icons
            .zIndex(100)
        }
        .padding(.top, 12)
    }
    
    func trainStyleInputField(placeholder: String, text: Binding<String>, onTextChange: @escaping () -> Void) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .onChange(of: text.wrappedValue) { _, _ in
                    onTextChange()
                }
            
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
        }
        .frame(height: 60)
        .padding(.trailing, 60) // Space for swap button
    }

    var secondarySearchActions: some View {
        VStack(spacing: 12) {
            secondarySearchRow(icon: "bus.fill", title: "Bus No. / Bus Name", text: $vm.busNumberSearch) {
                let allBuses = BusRepository.shared.allBuses
                guard let bus = allBuses.first(where: { $0.number.contains(vm.busNumberSearch) || $0.headsign.contains(vm.busNumberSearch) }) ?? allBuses.first else { return }
                router.go(.busSchedule(busID: bus.id))
            }
            
            secondarySearchRow(icon: "dot.radiowaves.right", title: "Bus Stop departure board", text: $vm.stopSearchText) {
                // Show buses for a specific stop
                router.go(.busesAtStop(stopName: vm.stopSearchText))
            }
        }
    }

    func secondarySearchRow(icon: String, title: String, text: Binding<String>, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(theme.current.accent)
                .frame(width: 40)
            
            TextField(title, text: text)
                .font(.system(size: 18, weight: .medium, design: .rounded))
            
            Spacer()
            
            Button {
                action()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 36)
                    .background(theme.current.accent)
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(theme.current.background)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.current.border, lineWidth: 1)
        )
    }

    func suggestionList(suggestions: [String], onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(theme.current.accent)
                            .frame(width: 20) // Match icon column width
                        
                        Text(suggestion)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.current.text)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(theme.current.card)
                }
                if suggestion != suggestions.last {
                    Divider().padding(.leading, 52) // Aligned with text
                }
            }
        }
        .background(theme.current.background)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
        .padding(.trailing, 24)
    }

    var searchHistorySection: some View {
        let allBuses = BusRepository.shared.allBuses
        return VStack(alignment: .leading, spacing: 0) {
            Text("RECENT BUSES")
                .font(.caption.bold())
                .foregroundStyle(theme.current.secondaryText)
                .padding(.leading, 8)
                .padding(.bottom, 8)

            if allBuses.isEmpty {
                Text("No buses available")
                    .font(.subheadline)
                    .foregroundStyle(theme.current.secondaryText)
                    .padding(16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allBuses.prefix(5).enumerated()), id: \.element.id) { idx, bus in
                        if idx > 0 { Divider() }
                        historyRow(
                            busNo: bus.number,
                            name: bus.headsign,
                            route: "\(bus.route.from.prefix(3).uppercased()) - \(bus.route.to.prefix(3).uppercased())"
                        ) {
                            router.go(.busSchedule(busID: bus.id))
                        }
                    }
                }
                .background(theme.current.background)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.current.border, lineWidth: 1)
                )
            }
        }
        .padding(.top, 16)
    }

    func historyRow(busNo: String, name: String, route: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Text(busNo)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.current.text)
                
                Text(name)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(theme.current.secondaryText)
                
                Spacer()
                
                Text(route)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.current.secondaryText)
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.accent)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    private func navigate(toBus busNo: String) {
        let allBuses = BusRepository.shared.allBuses
        guard let bus = allBuses.first(where: { $0.number.contains(busNo) }) ?? allBuses.first else { return }
        router.go(.busSchedule(busID: bus.id))
    }
    


    var bottomBar: some View {
        HStack {
            Spacer()
            
            // Search Button
            Button {
                showingManualSearch = true
            } label: {
                bottomBarItem(
                    icon: "magnifyingglass",
                    title: "SEARCH",
                    isSelected: !vm.isFleetHistoryMode
                )
            }
            
            Spacer()
            
            // History Button (New Fleet History Icon)
            Button {
                router.go(.fleetHistory)
            } label: {
                bottomBarItem(
                    icon: "clock.arrow.circlepath",
                    title: "HISTORY",
                    isSelected: false 
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 12)
        .padding(.bottom, 34)
        .background(theme.current.card)
        .cornerRadius(30, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
    }

    func bottomBarItem(icon: String, title: String, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.caption2.bold())
        }
        .foregroundStyle(isSelected ? theme.current.accent : theme.current.secondaryText)
    }
}
