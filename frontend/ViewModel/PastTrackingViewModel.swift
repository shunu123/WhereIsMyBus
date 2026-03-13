import Foundation
import Combine

@MainActor
final class PastTrackingViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var routes: [Route] = []
    @Published var selectedRoute: Route?

    @Published var pings: [LocationPing] = []
    @Published var replayIndex: Int = 0
    @Published var isReplaying: Bool = false

    private var timer: Timer?

    @objc private func handleTimer() {
        // This method runs on the main run loop; class is @MainActor so it's safe
        if replayIndex < historyPath.count - 1 {
            replayIndex += 1
        } else {
            isReplaying = false
            timer?.invalidate()
            timer = nil
        }
    }

    func loadRoutes() {
        routes = BusRepository.shared.allRoutes()
        if selectedRoute == nil { selectedRoute = routes.first }
    }

    func loadHistory() {
        guard let r = selectedRoute else { return }
        pings = HistoryService.shared.historyPings(for: r, on: selectedDate)
        replayIndex = 0
        isReplaying = false
        timer?.invalidate()
        timer = nil
    }

    var historyPath: [Coord] {
        pings.map { $0.coordinate }
    }

    var replayPath: [Coord] {
        Array(historyPath.prefix(replayIndex + 1))
    }

    func startReplay() {
        guard !historyPath.isEmpty else { return }
        isReplaying = true
        timer?.invalidate()
        timer = nil

        // Schedule a timer using target/selector to avoid capturing self in a @Sendable closure
        let t = Timer(timeInterval: 1.0, target: self, selector: #selector(handleTimer), userInfo: nil, repeats: true)
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
}

