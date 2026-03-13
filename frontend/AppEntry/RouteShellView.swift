import SwiftUI
import CoreLocation


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
                    .navigationDestination(for: AppRouter.AppPage.self) { route in
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToBusSchedule"))) { notification in
            if let busID = notification.object as? String {
                router.go(.busSchedule(busID: busID))
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRouter.AppPage) -> some View {
        switch route {
        case .home:
            HomeView(openDrawer: { withAnimation { isDrawerOpen = true } },
                     locationManager: locationManager)

        case .availableBuses(let from, let to, let fromID, let toID, let fromLat, let fromLon, let toLat, let toLon, let via):
            let fCoord = (fromLat != nil && fromLon != nil) ? CLLocationCoordinate2D(latitude: fromLat!, longitude: fromLon!) : nil
            let tCoord = (toLat != nil && toLon != nil) ? CLLocationCoordinate2D(latitude: toLat!, longitude: toLon!) : nil
            AvailableBusesView(origin: from, destination: to, fromID: fromID, toID: toID, fromCoord: fCoord, toCoord: tCoord, via: via)



        case .liveTracking(let busID, let isHistorical, let date, let sourceStop, let destinationStop, let sLat, let sLon, let dLat, let dLon):
            if let bus = BusRepository.shared.bus(by: busID) {
                let sCoord = (sLat != nil && sLon != nil) ? Coord(lat: sLat!, lon: sLon!) : nil
                let dCoord = (dLat != nil && dLon != nil) ? Coord(lat: dLat!, lon: dLon!) : nil
                LiveTrackingMapView(bus: bus,
                                    isHistorical: isHistorical,
                                    selectedDate: date ?? Date(),
                                    sourceStop: sourceStop,
                                    destinationStop: destinationStop,
                                    sourceCoord: sCoord,
                                    destinationCoord: dCoord)
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
            
        case .editProfile:
            EditProfileView()
            
        case .studentData:
            StudentRosterView()

        case .about:
            AboutView()

        case .busSchedule(let busID, let searchPoint, let destinationStop, let sLat, let sLon, let dLat, let dLon):
            if let uuid = UUID(uuidString: busID), let bus = BusRepository.shared.bus(by: uuid) {
                BusScheduleView(
                    bus: bus, 
                    searchPoint: searchPoint, 
                    destinationStop: destinationStop,
                    sourceLat: sLat,
                    sourceLon: sLon,
                    destLat: dLat,
                    destLon: dLon
                )
            } else {
                unavailableView("Bus schedule unavailable")
            }

        case .busesAtStop(let stopName):
            BusesAtStopView(stopName: stopName)

        case .logout:
            LoginView()

        case .routeMap(let busNumbers, let from, let to):
            // Fallback since bus objects were removed from navigation temporarily
            RouteMapView(buses: [], fromStop: from, toStop: to)


        case .fleetHistory:
            FleetHistoryView()
            
        case .activeFleet:
            ActiveFleetMapView()

        case .allRoutes:
            AllRoutesView()

        case .routeDetail(let routeID):
            // Fallback since route object was removed from navigation temporarily
            unavailableView("Route detail unavailable")


        case .registration:
            RegistrationView()

        case .tripDetailTimeline(let tripId, let busNumber, let startTime, let endTime, let trackPoints, let timelineEvents):
            TripDetailTimelineView(
                tripId: tripId,
                busNumber: busNumber,
                startTime: startTime,
                endTime: endTime,
                trackPoints: trackPoints,
                timelineEvents: timelineEvents
            )

        case .adminScheduling:
            AdminSchedulingView()
        case .adminHistory:
            AdminHistoryView()
        case .studentDashboard:
            StudentDashboardView()
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
