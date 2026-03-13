import SwiftUI
import Combine

@MainActor
final class AllRoutesViewModel: ObservableObject {
    @Published var routes: [BusRoute] = []
    @Published var searchText: String = "" {
        didSet { debounceSearch() }
    }
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var error: String?

    var filteredRoutes: [BusRoute] { routes } // filtering done server-side

    private var total: Int = 0
    private let limit = 100
    private var searchTask: Task<Void, Never>?

    func loadRoutes(reset: Bool = true) async {
        if reset { routes = []; error = nil }
        isLoading = reset
        do {
            let result = try await APIService.shared.fetchRoutes(q: searchText, offset: reset ? 0 : routes.count)
            if reset {
                self.routes = result.routes
            } else {
                self.routes.append(contentsOf: result.routes)
            }
            self.total = result.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
        isLoadingMore = false
    }

    func loadMore() {
        guard !isLoadingMore, routes.count < total else { return }
        isLoadingMore = true
        Task { await loadRoutes(reset: false) }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }
            await loadRoutes()
        }
    }
}
