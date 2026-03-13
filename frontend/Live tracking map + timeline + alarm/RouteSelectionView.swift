import SwiftUI

struct RouteSelectionView: View {
    @State private var routes: [BusRoute] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading routes...")
                } else if routes.isEmpty {
                    ContentUnavailableView("No Routes Found", systemImage: "map", description: Text("Check your connection or try again later."))
                } else {
                    List(routes, id: \.id) { route in
                        Button {
                            // Find the first bus associated with this route, or handle lack thereof
                            let buses = BusRepository.shared.allBuses.filter { $0.headsign == route.name || $0.number == route.name || $0.extRouteId == String(route.id) }
                            if let firstBus = buses.first {
                                // Assume this view is rendered in an AppRouter context
                                if let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
                                   let rootVC = window.rootViewController {
                                    // Use notification or environment object
                                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToBusSchedule"), object: firstBus.id)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.name)
                                    .font(.headline)
                                Text("\(route.from_name ?? "Start") ➔ \(route.to_name ?? "End")")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Route")
            .task {
                await fetchRoutes()
            }
        }
    }

    private func fetchRoutes() async {
        isLoading = true
        do {
            self.routes = try await APIService.shared.fetchRoutes().routes
        } catch {
            print("Failed to fetch routes: \(error)")
        }
        isLoading = false
    }
}

