import SwiftUI

struct AvailableBusesView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter

    let from: String
    let to: String
    let via: String?

    @StateObject private var vm = AvailableBusesViewModel()
    @State private var showFilter = false

    var body: some View {
        ZStack(alignment: .top) {
            theme.current.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { router.back() } label: {
                        Image(systemName: "arrow.left")
                            .font(.title2.bold())
                            .foregroundStyle(theme.current.text)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(from)  →  \(to)")
                            .font(.headline.bold())
                            .foregroundStyle(theme.current.text)
                        if let via {
                            Text("via \(via)")
                                .font(.caption)
                                .foregroundStyle(theme.current.secondaryText)
                        }
                    }

                    Spacer()

                    Button { showFilter = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(theme.current.accent)
                            .padding(8)
                            .background(Circle().fill(theme.current.card))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.current.card)

                if let error = vm.errorText {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bus")
                            .font(.system(size: 48))
                            .foregroundStyle(theme.current.secondaryText)
                        Text(error)
                            .font(.headline)
                            .foregroundStyle(theme.current.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    Spacer()
                } else if vm.buses.isEmpty {
                    Spacer()
                    ProgressView("Finding buses…")
                        .foregroundStyle(theme.current.secondaryText)
                    Spacer()
                } else {
                    TimelineScheduleView(
                        buses: filteredBuses,
                        from: from,
                        to: to
                    ) { bus in
                        router.go(.liveTracking(busID: bus.id, sourceStop: from))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.load(from: from, to: to, via: via) }
        .sheet(isPresented: $showFilter) {
            FilterSheetView(
                showOnTime: $vm.showOnTime,
                showDelayed: $vm.showDelayed,
                sortOption: $vm.sortOption
            ) {
                vm.applyFilterState(from: from, to: to, via: via)
                showFilter = false
            }
            .environmentObject(theme)
        }
    }

    private var filteredBuses: [Bus] {
        var result = vm.buses
        if !vm.showOnTime  { result = result.filter { $0.status != .onTime } }
        if !vm.showDelayed { result = result.filter { $0.status != .delayed } }
        switch vm.sortOption {
        case .departureTime: result.sort { $0.departsAt < $1.departsAt }
        case .duration:      result.sort { $0.durationText < $1.durationText }
        }
        return result
    }
}
