import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var stops: [BusStop] = []
    @Published var fromStop: BusStop?
    @Published var toStop: BusStop?

    @Published var trips: [SearchTrip] = []

    @Published var isLoading: Bool = false
    @Published var errorText: String?

    func loadStops(routeId: String = "20", dir: String = "Eastbound") async {
        isLoading = true
        errorText = nil

        do {
            stops = try await APIService.shared.fetchStops(routeId: routeId, dir: dir)
        } catch {
            errorText = "Stops load failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func search() async {
        guard let fromStop, let toStop else {
            errorText = "Select From and To stops"
            return
        }

        isLoading = true
        errorText = nil

        do {
            trips = try await APIService.shared.searchTrips(
                fromStopId: fromStop.id,
                toStopId: toStop.id
            )
        } catch {
            errorText = "Search failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
