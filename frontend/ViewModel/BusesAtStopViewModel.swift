import Foundation
import Combine

@MainActor
final class BusesAtStopViewModel: ObservableObject {
    @Published var buses: [Bus] = []
    @Published var stopName: String
    @Published var errorText: String?

    init(stopName: String) {
        self.stopName = stopName
        load()
    }

    func load() {
        let result = BusSearchService.shared.findByStop(stopName)
        buses = result
        errorText = buses.isEmpty ? "🚌 No buses found for this stop" : nil
    }
}
