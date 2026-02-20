import SwiftUI

struct RouteShellView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var locationManager: LocationManager

    @State private var isDrawerOpen = false

    var body: some View {
        ZStack {
            NavigationStack(path: $router.path) {
                HomeView(openDrawer: { withAnimation { isDrawerOpen = true } },
                         locationManager: locationManager)
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        destination(for: route)
                    }
            }

            // Backdrop
            if isDrawerOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { isDrawerOpen = false } }
                    .zIndex(1)

                DrawerView(isOpen: $isDrawerOpen)
                    .zIndex(2)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isDrawerOpen)
    }

    @ViewBuilder
    private func destination(for route: AppRouter.Route) -> some View {
        switch route {
        case .home:
            HomeView(openDrawer: { withAnimation { isDrawerOpen = true } },
                     locationManager: locationManager)

        case .availableBuses(let from, let to, let via):
            AvailableBusesView(from: from, to: to, via: via)

        case .liveTracking(let busID, let isHistorical, let date, let sourceStop):
            if let bus = BusRepository.shared.bus(by: busID) {
                LiveTrackingMapView(bus: bus,
                                    isHistorical: isHistorical,
                                    selectedDate: date ?? Date(),
                                    sourceStop: sourceStop)
            } else {
                unavailableView("Bus not found")
            }

        case .trackByNumber(let autoStartVoice):
            TrackByBusNumberView(autoStartVoice: autoStartVoice)

        case .savedRoutes:
            SavedRoutesView()

        case .recentSearches:
            RecentSearchesView()

        case .settings:
            SettingsView()

        case .help:
            HelpSupportView()

        case .report:
            ReportIssueView()

        case .about:
            AboutView()

        case .busSchedule(let busID, let searchPoint):
            if let bus = BusRepository.shared.bus(by: busID) {
                BusScheduleView(bus: bus, searchPoint: searchPoint)
            } else {
                unavailableView("Bus schedule unavailable")
            }

        case .busesAtStop(let stopName):
            BusesAtStopView(stopName: stopName)

        case .logout:
            LoginView()

        case .routeMap(let buses, let from, let to):
            RouteMapView(buses: buses, fromStop: from, toStop: to)

        case .fleetHistory:
            FleetHistoryView()

        case .tripDetailTimeline(let tripId, let busNumber, let startTime, let endTime, let trackPoints, let timelineEvents):
            TripDetailTimelineView(
                tripId: tripId,
                busNumber: busNumber,
                startTime: startTime,
                endTime: endTime,
                trackPoints: trackPoints,
                timelineEvents: timelineEvents
            )
        }
    }

    @ViewBuilder
    private func unavailableView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(message)
                .font(.headline)
                .foregroundStyle(theme.current.secondaryText)
            Button("Go Back") { router.back() }
                .font(.subheadline.bold())
                .foregroundStyle(theme.current.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.current.background)
    }
}
