import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Search Fields
    @Published var fromText: String = ""
    @Published var toText: String = ""
    @Published var fromSuggestions: [String] = []
    @Published var toSuggestions: [String] = []

    // MARK: - Secondary Search
    @Published var busNumberSearch: String = ""
    @Published var stopSearchText: String = ""

    // MARK: - History / Manual Sheet
    @Published var isHistoryMode: Bool = false
    @Published var historyDate: Date = Date()

    // MARK: - Fleet History toggle (bottom bar)
    @Published var isFleetHistoryMode: Bool = false

    // MARK: - Voice
    @Published var voice: VoiceAssistant = VoiceAssistant()
    @Published var isSpeechAuthorized: Bool = false

    // MARK: - Permissions overlay
    @Published var showPermissions: Bool = false

    // MARK: - Router (set by HomeView.onAppear)
    var router: AppRouter?

    // MARK: - Dependencies
    private let locationManager: LocationManager

    // MARK: - Init
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
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
        let text = voice.transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !text.isEmpty else { return }

        // Simple from/to parsing: "from X to Y"
        if let fromRange = text.range(of: "from "),
           let toRange = text.range(of: " to ") {
            let from = String(text[fromRange.upperBound..<toRange.lowerBound])
                .capitalized
            let to = String(text[toRange.upperBound...])
                .capitalized
            fromText = from
            toText = to
            router?.go(.availableBuses(from: fromText, to: toText, via: nil))
        }
    }

    // MARK: - Suggestions

    func updateFromSuggestions() {
        let query = fromText
        Task {
            let results = await StopSuggestionService.shared.suggest(query: query)
            await MainActor.run { self.fromSuggestions = results }
        }
    }

    func updateToSuggestions() {
        let query = toText
        Task {
            let results = await StopSuggestionService.shared.suggest(query: query)
            await MainActor.run { self.toSuggestions = results }
        }
    }

    func selectFrom(_ suggestion: String) {
        fromText = suggestion
        fromSuggestions = []
    }

    func selectTo(_ suggestion: String) {
        toText = suggestion
        toSuggestions = []
    }

    // MARK: - Swap

    func swap() {
        let temp = fromText
        fromText = toText
        toText = temp
        fromSuggestions = []
        toSuggestions = []
    }
}
