import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class StudentDashboardViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentUserLocation: CLLocation?
    @Published var allStops: [BusStop] = []
    @Published var nearestStop: BusStop?
    @Published var nearestStopDistance: Double = 0
    @Published var walkingRoute: MKRoute?
    @Published var walkingTime: TimeInterval = 0
    
    @Published var arrivingBuses: [Bus] = []
    @Published var liveBuses: [String: WSVehicle] = [:] // vid -> vehicle
    
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Dependencies
    private let locationManager = LocationManager.shared
    private let apiService = APIService.shared
    private let wsService = WebSocketService.shared
    private let shortestPathService = ShortestPathService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var isFirstLoad = true
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe user location
        locationManager.$userLocation
            .sink { [weak self] location in
                guard let self = self, let location = location else { return }
                self.currentUserLocation = location
                if self.isFirstLoad {
                    self.isFirstLoad = false
                    self.refreshDashboard()
                }
            }
            .store(in: &cancellables)
            
        // Observe live bus updates from WebSocket
        wsService.gpsPublisher
            .sink { [weak self] vehicles in
                guard let self = self else { return }
                for vehicle in vehicles {
                    if let vid = vehicle.vid {
                        self.liveBuses[vid] = vehicle
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshDashboard() {
        guard let location = currentUserLocation else { return }
        
        Task {
            isLoading = true
            error = nil
            
            do {
                // 1. Fetch all stops if not already loaded
                if allStops.isEmpty {
                    allStops = try await apiService.fetchAllStops()
                }
                
                // 2. Find nearest stop using Dijkstra service
                if let nearest = shortestPathService.findNearestStop(from: location.coordinate, to: allStops) {
                    self.nearestStop = nearest
                    self.nearestStopDistance = location.distance(from: CLLocation(latitude: nearest.lat, longitude: nearest.lng)) / 1000.0 // km
                    
                    // 3. Calculate walking route
                    calculateWalkingRoute(from: location.coordinate, to: nearest.coordinate)
                    
                    // 4. Fetch buses for this stop
                    fetchBuses(for: nearest)
                    
                    // 5. Save search history
                    saveSearch(nearest: nearest)
                }
                
                // 6. Connect WebSocket for live updates
                wsService.connect()
                
            } catch {
                self.error = "Failed to load dashboard: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func calculateWalkingRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.walkingRoute = route
                    self.walkingTime = route.expectedTravelTime
                }
            }
        }
    }
    
    private func fetchBuses(for stop: BusStop) {
        Task {
            do {
                let trips = try await apiService.fetchBusesForStop(stopId: stop.id)
                self.arrivingBuses = trips.map { trip in
                    Bus(
                        id: UUID(),
                        number: trip.busNo ?? "N/A",
                        headsign: trip.routeName ?? "Transit",
                        departsAt: trip.firstDeparture ?? "--",
                        durationText: "--",
                        status: .onTime,
                        statusDetail: trip.status ?? "Live",
                        trackingStatus: .arriving,
                        etaMinutes: nil,
                        route: Route(from: "", to: "", stops: []),
                        vehicleId: trip.tripId,
                        busId: trip.busId,
                        extTripId: trip.extTripId
                    )
                }
            } catch {
                print("Failed to fetch buses for stop \(stop.id): \(error)")
            }
        }
    }
    
    private func saveSearch(nearest: BusStop) {
        guard let location = currentUserLocation else { return }
        let studentId = SessionManager.shared.currentUser?.id ?? 0
        
        Task {
            try? await apiService.saveStudentStopSearch(
                studentId: studentId,
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                nearestStopId: Int(nearest.id) ?? 0,
                distance: nearestStopDistance
            )
        }
    }
    
    deinit {
        wsService.disconnect()
    }
}
