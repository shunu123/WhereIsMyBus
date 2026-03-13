import SwiftUI
import Foundation

struct BusTimelineView: View {
    @EnvironmentObject var router: AppRouter
    let route: BusRoute
    @State private var stops: [Stop] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    ProgressView("Loading stops...")
                        .padding()
                } else if stops.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bus.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                        Text("No stops found for this route.")
                            .font(.headline)
                    }
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 20) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 10, height: 10)
                                if stop.id != stops.last?.id {
                                    Rectangle()
                                        .fill(.blue.opacity(0.3))
                                        .frame(width: 2, height: 40)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stop.name)
                                    .font(.headline)
                                if let time = stop.timeText {
                                    Text(time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStops()
        }
    }
    
    private func loadStops() async {
        if let existing = route.stops, !existing.isEmpty {
            self.stops = existing
            return
        }
        
        isLoading = true
        do {
            self.stops = try await APIService.shared.fetchRouteStops(routeId: route.id)
        } catch {
            print("Failed to fetch stops: \(error)")
        }
        isLoading = false
    }
}
