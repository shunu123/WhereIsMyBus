import Foundation
import Combine
import Speech
import AVFoundation
import CoreLocation

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Search Fields
    @Published var fromText: String = ""
    @Published var toText: String = ""
    @Published var fromID: String? = nil
    @Published var toID: String? = nil
    @Published var fromSuggestions: [BusStop] = []
    @Published var toSuggestions: [BusStop] = []

    
    // Objects with coordinates for map routing
    @Published var fromStop: BusStop? = nil
    @Published var toStop: BusStop? = nil


    // MARK: - Secondary Search
    @Published var busNumberSearch: String = ""
    @Published var stopSearchText: String = ""

    // MARK: - History / Manual Sheet
    @Published var isHistoryMode: Bool = false
    @Published var historyDate: Date = Date()

    // MARK: - Fleet History toggle (bottom bar)
    @Published var isFleetHistoryMode: Bool = false
    
    // MARK: - Persistent Recent Searches
    @Published var recentSearches: [RecentSearch] = []
    @Published var recentBusNumbers: [String] = []

    // MARK: - Voice
    @Published var voice: VoiceAssistant = VoiceAssistant()
    @Published var isSpeechAuthorized: Bool = false

    // MARK: - Permissions overlay
    @Published var showPermissions: Bool = false

    // MARK: - Dynamic Header
    @Published var dynamicHeaderInfo: String = ""
    @Published var showDynamicHeader: Bool = false
    @Published var isLoading: Bool = false

    // MARK: - Router (set by HomeView.onAppear)
    var router: AppRouter?

    // MARK: - Dependencies
    private let locationManager: LocationManager

    // MARK: - Init
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        loadRecentSearches()
        
        // Auto-process when voice assistant detects silence
        voice.onSilenceRecognized = { [weak self] in
            self?.processVoiceCommand()
        }
    }

    func loadRecentSearches() {
        if !UserDefaults.standard.bool(forKey: "didClearOldDataForDelhi") {
            SearchHistoryService.shared.clearAll()
            BusSearchHistoryService.shared.clear()
            UserDefaults.standard.set(true, forKey: "didClearOldDataForDelhi")
        }

        Task {
            isLoading = true
            do {
                let user = SessionManager.shared.currentUser
                let role = SessionManager.shared.userRole ?? "student"
                
                // 1. Fetch from-to history from backend
                let searches = try await APIService.shared.fetchRecentSearches(role: role, userId: user?.id)
                
                // 2. Load bus number history from local storage
                let busNumbers = BusSearchHistoryService.shared.all()
                
                await MainActor.run {
                    self.recentSearches = searches
                    self.recentBusNumbers = busNumbers
                }
            } catch {
                print("Failed to load recent searches: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    func useRecentSearch(_ search: RecentSearch) {
        fromText = search.from_name
        toText = search.to_name
        fromID = search.from_stop_id
        toID = search.to_stop_id
        
        // Show the search view as a fallback, but try direct navigation first
        Task {
            isLoading = true
            do {
                let trips = try await APIService.shared.searchTrips(fromStopId: search.from_stop_id, toStopId: search.to_stop_id)
                
                await MainActor.run {
                    if let trip = trips.first {
                        // Construct a bus object to register it in the repo for schedule view
                        let bus = mapTripToBus(trip, from: search.from_name, to: search.to_name)
                        BusRepository.shared.register(bus: bus)
                        router?.go(.busSchedule(busID: bus.id.uuidString, searchPoint: search.from_name, destinationStop: search.to_name))
                    } else {
                        router?.go(.availableBuses(
                            from: fromText,
                            to: toText,
                            fromID: fromID,
                            toID: toID,
                            fromLat: fromStop?.coordinate.latitude,
                            fromLon: fromStop?.coordinate.longitude,
                            toLat: toStop?.coordinate.latitude,
                            toLon: toStop?.coordinate.longitude,
                            via: nil
                        ))


                    }
                }
            } catch {
                print("Search failed for direct navigation: \(error)")
                await MainActor.run {
                    router?.go(.availableBuses(
                        from: fromText,
                        to: toText,
                        fromID: fromID,
                        toID: toID,
                        fromLat: fromStop?.coordinate.latitude,
                        fromLon: fromStop?.coordinate.longitude,
                        toLat: toStop?.coordinate.latitude,
                        toLon: toStop?.coordinate.longitude,
                        via: nil
                    ))


                }
            }
            isLoading = false
        }
    }

    private func mapTripToBus(_ trip: SearchTrip, from: String, to: String) -> Bus {
        // Simple mapping similar to AvailableBusesViewModel
        let ds = (trip.fromDeparture ?? "--").replacingOccurrences(of: "Z", with: "")
        var departsAtStr = "--"
        let parts = ds.components(separatedBy: "T")
        if parts.count > 1 {
            let timeParts = parts[1].components(separatedBy: ":")
            if timeParts.count >= 2, let hr = Int(timeParts[0]) {
                let ampm = hr >= 12 ? "PM" : "AM"
                let hr12 = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr)
                departsAtStr = String(format: "%02d:%@ %@", hr12, timeParts[1], ampm)
            }
        }

        let existingId = BusRepository.shared.allBuses.first(where: { 
            $0.extTripId == trip.extTripId || ($0.vehicleId != nil && $0.vehicleId == trip.tripId)
        })?.id ?? UUID()

        return Bus(
            id: existingId,
            number: trip.busNo ?? "N/A",
            headsign: trip.label ?? trip.routeName ?? "College Bus",
            departsAt: departsAtStr,
            durationText: "\(trip.durationMinutes ?? 0)m",
            status: .onTime,
            statusDetail: trip.status ?? "Scheduled",
            trackingStatus: TrackingStatus(rawValue: trip.status?.capitalized ?? "Scheduled") ?? .scheduled,
            etaMinutes: trip.durationMinutes,
            route: Route(from: from, to: to, stops: []),
            vehicleId: trip.tripId,
            busId: trip.busId,
            extTripId: trip.extTripId
        )
    }

    // MARK: - Permissions

    func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        isSpeechAuthorized = (speechStatus == .authorized)
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.isSpeechAuthorized = (status == .authorized)
                self?.showPermissions = false
            }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }

    func skipPermissions() {
        showPermissions = false
    }

    // MARK: - Voice Command

    func processVoiceCommand() {
        var text = voice.transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !text.isEmpty else { return }
        
        // 0. Normalize numbers (e.g., "twenty" -> "20")
        text = normalizeNumbers(text)

        // 1. Action Commands
        if text.contains("go back") || text.contains("return") || text.contains("back") {
            voice.speak(text: "Going back.")
            router?.back()
            return
        }
        if text.contains("live fleet") || text.contains("active fleet") || text.contains("show all buses") {
            voice.speak(text: "Opening the live fleet map.")
            router?.go(.activeFleet)
            return
        }
        if text.contains("settings") || text.contains("profile") {
            voice.speak(text: "Opening settings.")
            router?.go(.settings)
            return
        }
        if text.contains("history") || text.contains("recent") {
            voice.speak(text: "Showing your recent searches.")
            router?.go(.recentSearches)
            return
        }

        // 2. Complex patterns: "to X from Y" or "from Y to X"
        // Pattern: "to [Dest] from [Source]"
        if let toRange = text.range(of: "to "),
           let fromRange = text.range(of: " from "),
           toRange.lowerBound < fromRange.lowerBound {
            let to = String(text[toRange.upperBound..<fromRange.lowerBound]).trimmingCharacters(in: .whitespaces).capitalized
            let from = String(text[fromRange.upperBound...]).trimmingCharacters(in: .whitespaces).capitalized
            if !to.isEmpty && !from.isEmpty {
                fromText = from
                toText = to
                voice.speak(text: "Finding buses from \(from) to \(to).")
                router?.go(.availableBuses(from: from, to: to, fromLat: nil, fromLon: nil, toLat: nil, toLon: nil, via: nil))


                return
            }
        }
        
        // Pattern: "from [Source] to [Dest]"
        if let fromRange = text.range(of: "from "),
           let toRange = text.range(of: " to "),
           fromRange.lowerBound < toRange.lowerBound {
            let from = String(text[fromRange.upperBound..<toRange.lowerBound]).trimmingCharacters(in: .whitespaces).capitalized
            let to = String(text[toRange.upperBound...]).trimmingCharacters(in: .whitespaces).capitalized
            if !from.isEmpty && !to.isEmpty {
                fromText = from
                toText = to
                voice.speak(text: "Finding buses from \(from) to \(to).")
                router?.go(.availableBuses(from: from, to: to, fromLat: nil, fromLon: nil, toLat: nil, toLon: nil, via: nil))


                return
            }
        }

        // 3. Simple Route/Bus search: "Route 20", "Bus 20", "Show twenty"
        let busKeywords = ["route", "bus", "show", "track", "find"]
        for kw in busKeywords {
            if let range = text.range(of: kw) {
                let rest = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let components = rest.components(separatedBy: .whitespaces)
                if let firstWord = components.first, !firstWord.isEmpty {
                    // Try to find by number
                    if let bus = BusRepository.shared.allBuses.first(where: { 
                        $0.number.lowercased() == firstWord || $0.number.lowercased().contains(firstWord)
                    }) {
                        voice.speak(text: "Showing schedule for Route \(bus.number).")
                        router?.go(.busSchedule(busID: bus.id.uuidString))
                        return
                    }
                }
            }
        }

        // 4. "Buses at [Stop]"
        if let atRange = text.range(of: " at ") {
            let stopName = String(text[atRange.upperBound...]).trimmingCharacters(in: .whitespaces).capitalized
            if !stopName.isEmpty {
                voice.speak(text: "Checking buses arriving at \(stopName).")
                router?.go(.busesAtStop(stopName: stopName))
                return
            }
        }

        // 5. Global Fuzzy Fallback
        let bestMatch = BusRepository.shared.allBuses.min { b1, b2 in
            let d1 = min(levenshtein(text, b1.route.from.lowercased()), levenshtein(text, b1.headsign.lowercased()))
            let d2 = min(levenshtein(text, b2.route.from.lowercased()), levenshtein(text, b2.headsign.lowercased()))
            return d1 < d2
        }

        if let bus = bestMatch {
            let d = min(levenshtein(text, bus.route.from.lowercased()), levenshtein(text, bus.headsign.lowercased()))
            if d <= max(4, text.count / 2) {
                voice.speak(text: "Navigating to Route \(bus.number), \(bus.headsign).")
                router?.go(.busSchedule(busID: bus.id.uuidString))
                return
            }
        }
        
        voice.speak(text: "I didn't quite catch that. Try saying something like, 'Show route twenty'.")
    }
    
    private func normalizeNumbers(_ text: String) -> String {
        var result = text
        let map = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
            "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
            "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
            "eighteen": "18", "nineteen": "19", "twenty": "20", "thirty": "30",
            "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70",
            "eighty": "80", "ninety": "90"
        ]
        for (word, digit) in map {
            result = result.replacingOccurrences(of: "\\b\(word)\\b", with: digit, options: .regularExpression)
        }
        return result
    }
    
    private func levenshtein(_ a: String, _ b: String) -> Int {
        let empty = [Int](repeating: 0, count: b.count)
        var last = [Int](0...b.count)
        for (i, char1) in a.enumerated() {
            var cur = [i + 1] + empty
            for (j, char2) in b.enumerated() {
                cur[j + 1] = char1 == char2 ? last[j] : Swift.min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last ?? 0
    }

    // MARK: - Suggestions

    func updateFromSuggestions() {
        let query = fromText.lowercased()
        if query.isEmpty {
            self.fromSuggestions = []
            return
        }
        
        // 1. Local history suggestions (Available from 1 character)
        let historyMatches = SearchHistoryService.shared.all()
            .filter { $0.from.lowercased().starts(with: query) }
            .map { BusStop(id: "0", name: $0.from, lat: 0, lng: 0) }
        
        if query.count < 2 {
            self.fromSuggestions = []
            return
        }
        
        Task {
            // 2. API suggestions (Available from 2 characters)
            let results = await StopSuggestionService.shared.suggestions(query: query)
            await MainActor.run { 
                guard self.fromText.lowercased() == query else { return }
                
                // Combine and deduplicate
                var combined = historyMatches
                for r in results {
                    if !combined.contains(where: { $0.name.lowercased() == r.name.lowercased() }) {
                        combined.append(r)
                    }
                }
                
                if combined.count == 1 && combined[0].name.lowercased() == query {
                    self.fromSuggestions = []
                } else {
                    self.fromSuggestions = combined 
                }
            }
        }
    }

    func updateToSuggestions() {
        let query = toText.lowercased()
        if query.isEmpty {
            self.toSuggestions = []
            return
        }
        
        // 1. Local history suggestions (Available from 1 character)
        let historyMatches = SearchHistoryService.shared.all()
            .filter { $0.to.lowercased().starts(with: query) }
            .map { BusStop(id: "0", name: $0.to, lat: 0, lng: 0) }
            
        if query.count < 2 {
            self.toSuggestions = []
            return
        }
        
        Task {
            // 2. API suggestions (Available from 2 characters)
            let results = await StopSuggestionService.shared.suggestions(query: query)
            await MainActor.run { 
                guard self.toText.lowercased() == query else { return }
                
                // Combine and deduplicate
                var combined = historyMatches
                for r in results {
                    if !combined.contains(where: { $0.name.lowercased() == r.name.lowercased() }) {
                        combined.append(r)
                    }
                }
                
                if combined.count == 1 && combined[0].name.lowercased() == query {
                    self.toSuggestions = []
                } else {
                    self.toSuggestions = combined 
                }
            }
        }
    }

    func selectFrom(_ stop: BusStop) {
        fromText = stop.name
        fromID = stop.id
        fromStop = stop
        fromSuggestions = []
    }

    func selectTo(_ stop: BusStop) {
        toText = stop.name
        toID = stop.id
        toStop = stop
        toSuggestions = []
    }

    // MARK: - Swap

    func swap() {
        let tempText = fromText
        let tempID = fromID
        let tempStop = fromStop
        
        fromText = toText
        fromID = toID
        fromStop = toStop
        
        toText = tempText
        toID = tempID
        toStop = tempStop
        
        fromSuggestions = []
        toSuggestions = []
    }

    // MARK: - Dynamic Header Helpers
    
    func prepareDynamicHeader() {
        dynamicHeaderInfo = getTimeBasedGreeting()
        showDynamicHeader = true
    }

    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Have a Good Night"
        }
    }
}
