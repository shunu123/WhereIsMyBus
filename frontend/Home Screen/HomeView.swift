import SwiftUI
import CoreLocation


struct HomeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var languageManager: LanguageManager
    
    // Inject closure from RouteShellView to handle drawer opening
    var openDrawer: () -> Void

    @StateObject private var vm: HomeViewModel
    @State private var showingManualSearch = false
    
    enum Field {
        case from, to
    }
    @FocusState private var focusedField: Field?

    init(openDrawer: @escaping () -> Void, locationManager: LocationManager) {
        self.openDrawer = openDrawer
        self._vm = StateObject(wrappedValue: HomeViewModel(locationManager: locationManager))
    }

    var body: some View {
        ZStack(alignment: .top) {
            theme.current.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header (Squared Green)
                header
                
                // Fixed Search Card (No longer scrolls away)
                mainSearchCard
                    .padding(.top, 10)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Track by Bus Number bar (Moved from middle to top position)
                        trackByNumberBar
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        
                        // 1. Recent Buses (Priority)
                        recentBusesSection
                            .padding(.top, 10)
                            .padding(.horizontal, 20)
                        
                        // 2. Recent Route Searches (Secondary)
                        recentRoutesSection
                            .padding(.horizontal, 20)
                        
                        if vm.isHistoryMode && SessionManager.shared.userRole == "admin" {
                            // History Date Selection
                            DatePicker("Select Date", selection: $vm.historyDate, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding()
                                .background(theme.current.card)
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, SessionManager.shared.userRole == "admin" ? 60 : 20) // Buffer for bottom bar
                }
            }
            
            // Persistent Bottom Bar for All Users
            VStack {
                Spacer()
                bottomNavigationBar
            }
            .ignoresSafeArea(.keyboard)
            
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
            vm.loadRecentSearches()
            SessionManager.shared.resetIdleTimer()
            
            // Dynamic Header Logic
            vm.prepareDynamicHeader()
            // Wait 5 seconds, then slowly transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    vm.showDynamicHeader = false
                }
            }
        }
        .onTapGesture {
            SessionManager.shared.resetIdleTimer()
        }
        .ignoresSafeArea(.all, edges: .top)

        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingManualSearch) {
            manualSearchSheet
        }
    }


}

// MARK: - Manual Search Sheet
private extension HomeView {
    var manualSearchSheetHeader: some View {
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
    }

    var manualSearchSheetOptions: some View {
        Group {
            if SessionManager.shared.userRole == "admin" {
                Toggle("Search in History", isOn: $vm.isHistoryMode)
                    .font(.subheadline.bold())
                    .tint(theme.current.accent)
                    .padding(.vertical, 4)
            }

            if vm.isHistoryMode && SessionManager.shared.userRole == "admin" {
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
        }
    }

    var manualSearchSheetInput: some View {
        HStack {
            Image(systemName: "bus.fill")
                .foregroundStyle(theme.current.accent)
            TextField("e.g. 500-D, 335-E", text: $vm.busNumberSearch)
                .font(.title3.bold())
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            
            if !vm.busNumberSearch.isEmpty {
                Button { vm.busNumberSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
        }
        .padding()
        .background(theme.current.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.current.border, lineWidth: 1)
        )
    }

    private func handleManualSearch() {
        let search = vm.busNumberSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let allBuses = BusRepository.shared.allBuses
        
        // 1. Exact match in repository
        if let bus = allBuses.first(where: { 
            $0.number.lowercased() == search || 
            $0.extTripId?.lowercased() == search ||
            "\($0.busId ?? -1)" == search || 
            "\($0.vehicleId ?? -1)" == search 
        }) {
            BusSearchHistoryService.shared.save(bus.number)
            vm.loadRecentSearches()
            router.go(.busSchedule(busID: bus.id.uuidString, searchPoint: nil, destinationStop: nil))
            showingManualSearch = false
            return
        }
        
        // 2. Fuzzy match in repository
        if let fuzzyBus = allBuses.first(where: {
            $0.number.lowercased().contains(search) ||
            ($0.extTripId?.lowercased().contains(search) ?? false) ||
            ($0.statusDetail?.lowercased().contains(search) ?? false)
        }) {
            BusSearchHistoryService.shared.save(fuzzyBus.number)
            vm.loadRecentSearches()
            router.go(.busSchedule(busID: fuzzyBus.id.uuidString, searchPoint: nil, destinationStop: nil))
            showingManualSearch = false
            return
        }
        
        // 3. Fallback: Treat as a Route ID
        let routeNum = search.uppercased()
        BusSearchHistoryService.shared.save(routeNum)
        vm.loadRecentSearches()
        router.go(.availableBuses(from: "Route \(routeNum)", to: "Destination", fromLat: nil, fromLon: nil, toLat: nil, toLon: nil, via: routeNum))
        showingManualSearch = false
    }

    var manualSearchSheetAction: some View {
        Button(action: handleManualSearch) {
            Text("Track Bus")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(vm.busNumberSearch.isEmpty ? Color.gray : theme.current.accent)
                .cornerRadius(12)
        }
        .disabled(vm.busNumberSearch.isEmpty)
        .opacity(vm.busNumberSearch.isEmpty ? 0.6 : 1.0)
    }

    var manualSearchSheet: some View {
        VStack(spacing: 20) {
            manualSearchSheetHeader
            manualSearchSheetOptions
            manualSearchSheetInput
            manualSearchSheetAction
            Spacer()
        }
        .padding(24)
        .background(theme.current.background)
        .presentationDetents([.height(vm.isHistoryMode && SessionManager.shared.userRole == "admin" ? 450 : 350)])
    }
}

// MARK: - Header
private extension HomeView {
    var header: some View {
        ZStack(alignment: .bottom) {
            // Header Background covering safe area
            LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
            
            // Content
            ZStack {
                // Centered Title or Voice Wave or Greeting
                Group {
                    if vm.voice.isListening {
                        VoiceWaveView(level: vm.voice.audioLevel)
                            .frame(height: 40)
                            .transition(.opacity)
                    } else {
                        VStack(spacing: 2) {
                            Text("Where Is My Bus?")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption)
                                Text(locationManager.currentAddress)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        }
                        .transition(.opacity)
                        .animation(.easeInOut, value: locationManager.currentAddress)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 1.5), value: vm.showDynamicHeader)
                .animation(.easeInOut(duration: 0.5), value: vm.voice.isListening)

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

                // Right Actions (Mic only)
                HStack(spacing: 12) {
                    Spacer()
                    
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
        }
        .frame(height: 110) // Unified height including safe area
    }
}

struct VoiceWaveView: View {
    var level: Float
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<15, id: \.self) { i in
                // Slippery wave effect with overlapping sine waves
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: 3, height: calculateHeight(for: i))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: level)
            }
        }
    }
    
    private func calculateHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let intensity = CGFloat(level) * 100
        let time = Date().timeIntervalSince1970
        
        // Overlapping sine waves for a "slippery" feel
        let wave1 = sin(time * 5 + Double(index) * 0.4) * intensity * 0.5
        let wave2 = cos(time * 3 + Double(index) * 0.7) * intensity * 0.3
        
        return max(baseHeight, baseHeight + wave1 + wave2)
    }
}

// MARK: - Components overhaul
private extension HomeView {
    var mainSearchCard: some View {
        VStack(spacing: 0) {
            searchCardHeader
            searchButton
            browseAllRoutesButton
        }
        .background(theme.current.card)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.current.border, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(theme.current.card)
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 25, x: 0, y: 15)
        .padding(.horizontal, 16)
        .zIndex(100)
        .overlay {
            suggestionsDimmedBackground
        }
        .overlay(alignment: .top) {
            suggestionsOverlay
        }
    }

    private var searchCardHeader: some View {
        HStack(spacing: 12) {
            // Vertical Progress Line
            VStack(spacing: 0) {
                Circle()
                    .fill(theme.current.accent)
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill(LinearGradient(colors: [theme.current.accent, theme.current.border], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2, height: 60)
                
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.current.accent)
            }
            .padding(.vertical, 8)
            
            searchTextFields
            
            // Swap Button
            Button {
                withAnimation(.spring()) { vm.swap() }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.current.accent)
                    .padding(12)
                    .background(theme.current.accent.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(20)
    }

    private var searchButton: some View {
        Button(action: handleSearch) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                Text("Find Buses")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.current.accent)
            .foregroundStyle(.white)
        }
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var browseAllRoutesButton: some View {
        Button {
            router.go(.allRoutes)
        } label: {
            HStack {
                Image(systemName: "list.bullet.rectangle.portrait")
                Text("BROWSE ALL ROUTES")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(theme.current.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(theme.current.accent.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var suggestionsDimmedBackground: some View {
        if (!vm.fromSuggestions.isEmpty && focusedField == .from) || (!vm.toSuggestions.isEmpty && focusedField == .to) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        focusedField = nil
                    }
                }
                .transition(.opacity)
                .zIndex(90)
        }
    }

    @ViewBuilder
    private var suggestionsOverlay: some View {
        if (!vm.fromSuggestions.isEmpty && focusedField == .from) || (!vm.toSuggestions.isEmpty && focusedField == .to) {
            ScrollView {
                VStack(spacing: 0) {
                    if !vm.fromSuggestions.isEmpty && focusedField == .from {
                        suggestionList(suggestions: vm.fromSuggestions) { stop in
                            vm.selectFrom(stop)
                            focusedField = nil
                        }
                    } else if !vm.toSuggestions.isEmpty && focusedField == .to {
                        suggestionList(suggestions: vm.toSuggestions) { stop in
                            vm.selectTo(stop)
                            focusedField = nil
                        }
                    }
                }
            }
            .frame(maxHeight: 250)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(12)
            .padding(.top, 160)
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            .zIndex(500)
        }
    }
    
    @ViewBuilder
    private var searchTextFields: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Starting From...", text: $vm.fromText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .focused($focusedField, equals: .from)
                    .onChange(of: vm.fromText) { _, _ in
                        if focusedField == .from {
                            vm.fromID = nil
                            vm.updateFromSuggestions()
                        }
                    }
                
                if !vm.fromText.isEmpty {
                    Button { vm.fromText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.current.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(theme.current.background.opacity(0.5))
            .cornerRadius(12)
            
            HStack {
                TextField("Destination To...", text: $vm.toText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .focused($focusedField, equals: .to)
                    .onChange(of: vm.toText) { _, _ in
                        if focusedField == .to {
                            vm.toID = nil
                            vm.updateToSuggestions()
                        }
                    }
                
                if !vm.toText.isEmpty {
                    Button { vm.toText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.current.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(theme.current.background.opacity(0.5))
            .cornerRadius(12)
        }
    }
    
    private func handleSearch() {
        guard !vm.fromText.isEmpty, !vm.toText.isEmpty else { return }
        // Save history locally
        SearchHistoryService.shared.save(from: vm.fromText, to: vm.toText)
        
        // Save history to backend
        let fid = vm.fromID ?? ""
        let tid = vm.toID ?? ""
        let fn = vm.fromText
        let tn = vm.toText
        let uid = SessionManager.shared.currentUser?.id
        
        let fLat = vm.fromStop?.lat
        let fLon = vm.fromStop?.lng
        let tLat = vm.toStop?.lat
        let tLon = vm.toStop?.lng
        
        Task {
            try? await APIService.shared.saveRecentSearch(
                fromStopId: fid.isEmpty ? "unknown" : fid,
                toStopId: tid.isEmpty ? "unknown" : tid,
                fromName: fn,
                toName: tn,
                userId: uid
            )
        }
        
        router.go(.availableBuses(
            from: fn,
            to: tn,
            fromID: fid,
            toID: tid,
            fromLat: fLat,
            fromLon: fLon,
            toLat: tLat,
            toLon: tLon,
            via: nil
        ))
    }
    
    var trackByNumberBar: some View {
        Button {
            showingManualSearch = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "number.square.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(theme.current.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track by Bus Number")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.current.text)
                    Text("Enter exact number like 500-D")
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.secondaryText)
            }
            .padding(12)
            .background(theme.current.card)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
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
                router.go(.busSchedule(busID: bus.id.uuidString))
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

    func suggestionList(suggestions: [BusStop], onSelect: @escaping (BusStop) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { stop in
                Button {
                    onSelect(stop)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(theme.current.accent)
                            .frame(width: 20) // Match icon column width
                        
                        Text(stop.name)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.current.text)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(theme.current.card)
                }
                if stop.id != suggestions.last?.id {
                    Divider().padding(.leading, 52) // Aligned with text
                }
            }
        }
    }

    private func handleRecentBusSelection(_ number: String) {
        vm.busNumberSearch = number
        if let bus = BusRepository.shared.allBuses.first(where: { $0.number.lowercased() == number.lowercased() }) {
            router.go(.busSchedule(busID: bus.id.uuidString, searchPoint: nil, destinationStop: nil))
        }
    }


    var recentBusesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.recentBusNumbers.isEmpty {
                Text("RECENT BUSES")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.secondaryText)
                    .padding(.leading, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.recentBusNumbers, id: \.self) { number in
                            Button {
                                handleRecentBusSelection(number)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "bus")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(number)
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(theme.current.card)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(theme.current.border, lineWidth: 1)
                                )
                                .foregroundStyle(theme.current.text)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    var recentRoutesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !vm.recentSearches.isEmpty {
                Text("RECENT ROUTES")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.secondaryText)
                    .padding(.leading, 8)
                    .padding(.bottom, 8)
                
                VStack(spacing: 0) {
                    ForEach(vm.recentSearches) { search in
                        recentSearchRow(search)
                        if search.id != vm.recentSearches.last?.id {
                            Divider()
                        }
                    }
                }
                .background(theme.current.card) // Explicitly card color
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.current.border, lineWidth: 1)
                )
            }
        }
    }

    private func recentSearchRow(_ search: RecentSearch) -> some View {
        Button {
            vm.useRecentSearch(search)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(theme.current.accent)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(search.from_name)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                        Text(search.to_name)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.current.text)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.current.accent)
            }
            .padding(16)
        }
    }



    var bottomNavigationBar: some View {
        HStack(spacing: 0) {
            // Home Button
            Button {
                withAnimation {
                    router.popToRoot()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20))
                    Text("Home")
                        .font(.caption2.bold())
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(theme.current.accent)
            }
            
            // Nearby Stops Button
            Button {
                router.go(.studentDashboard)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 20))
                    Text("Nearby Stops")
                        .font(.caption2.bold())
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(theme.current.secondaryText)
            }

            // Fleet Activity Button (Only for Admins)
            if SessionManager.shared.userRole == "admin" {
                Button {
                    router.go(.activeFleet)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 20))
                        Text("Fleet Activity")
                            .font(.caption2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(theme.current.secondaryText)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            theme.current.card
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
        )
        .overlay(
            Rectangle()
                .fill(theme.current.border)
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }

    private func navigate(toBus busNo: String) {
        let allBuses = BusRepository.shared.allBuses
        guard let bus = allBuses.first(where: { $0.number.contains(busNo.uppercased()) }) ?? allBuses.first else { return }
        router.go(.busSchedule(busID: bus.id.uuidString))
    }
}
