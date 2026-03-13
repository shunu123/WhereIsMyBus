import SwiftUI

struct RouteDetailView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    let route: BusRoute

    @State private var directions: [TransitDirection] = []
    @State private var selectedDirection: TransitDirection?
    @State private var stops: [BusStop] = []
    @State private var fromStop: BusStop?
    @State private var toStop: BusStop?
    
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView().padding(.top, 40)
                    } else if let error {
                        Text(error).foregroundStyle(.red).padding()
                    } else {
                        directionSection
                        if selectedDirection != nil {
                            stopSelectionSection
                        }
                    }
                }
                .padding(20)
            }
            
            findButton
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await loadDirections()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button { router.back() } label: {
                Image(systemName: "arrow.left")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.headline.bold())
                    .foregroundStyle(theme.current.text)
                Text("Select Direction & Stops")
                    .font(.caption)
                    .foregroundStyle(theme.current.secondaryText)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(theme.current.card)
    }

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DIRECTION")
                .font(.caption.bold())
                .foregroundStyle(theme.current.secondaryText)
            
            HStack(spacing: 12) {
                ForEach(directions, id: \.dir) { dir in
                    Button {
                        selectedDirection = dir
                        Task { await loadStops(for: dir) }
                    } label: {
                        Text(dir.dir)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedDirection?.dir == dir.dir ? theme.current.accent : theme.current.card)
                            .foregroundStyle(selectedDirection?.dir == dir.dir ? .white : theme.current.text)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.current.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stopSelectionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            stopPicker(title: "STARTING FROM", selection: $fromStop)
            stopPicker(title: "DESTINATION TO", selection: $toStop)
        }
    }

    private func stopPicker(title: String, selection: Binding<BusStop?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(theme.current.secondaryText)
            
            Menu {
                ForEach(stops) { stop in
                    Button(stop.name) {
                        selection.wrappedValue = stop
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue?.name ?? "Select a stop...")
                        .font(.body.weight(.medium))
                        .foregroundStyle(selection.wrappedValue == nil ? theme.current.secondaryText : theme.current.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(theme.current.secondaryText)
                }
                .padding()
                .background(theme.current.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.current.border, lineWidth: 1)
                )
            }
        }
    }

    private var findButton: some View {
        Button {
            guard let from = fromStop, let to = toStop else { return }
            router.go(.availableBuses(from: from.name, to: to.name, fromID: from.id, toID: to.id, via: route.ext_route_id))
        } label: {
            Text("FIND BUSES")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canSearch ? theme.current.accent : Color.gray)
                .cornerRadius(16)
                .padding(20)
        }
        .disabled(!canSearch)
    }

    private var canSearch: Bool {
        fromStop != nil && toStop != nil
    }

    private func loadDirections() async {
        guard let rt = route.ext_route_id else { return }
        isLoading = true
        do {
            self.directions = try await TransitService.shared.fetchDirections(rt: rt)
            if let first = directions.first {
                selectedDirection = first
                await loadStops(for: first)
            }
        } catch {
            self.error = "Failed to load directions"
        }
        isLoading = false
    }

    private func loadStops(for dir: TransitDirection) async {
        guard let rt = route.ext_route_id else { return }
        isLoading = true
        do {
            self.stops = try await TransitService.shared.fetchStops(rt: rt, dir: dir.dir)
            self.fromStop = nil
            self.toStop = nil
        } catch {
            self.error = "Failed to load stops"
        }
        isLoading = false
    }
}
