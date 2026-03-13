import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class StudentDashboardViewModel: ObservableObject {
    // MARK: - Published State
    // MARK: - Published State
    @Published var currentUserLocation: CLLocation?
    @Published var allStops: [BusStop] = []
    
    // Top 2 Nearest Stops
    @Published var nearbyStops: [BusStop] = []
    @Published var routes: [String: MKRoute] = [:] // stopId -> route
    @Published var walkingTimes: [String: TimeInterval] = [:] // stopId -> time
    @Published var distances: [String: Double] = [:] // stopId -> km
    
    @Published var selectedStop: BusStop?
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
        
        // Auto-select first stop when nearbyStops changes
        $nearbyStops
            .sink { [weak self] stops in
                if let first = stops.first, self?.selectedStop == nil {
                    self?.selectStop(first)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBindings() {
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
                if allStops.isEmpty {
                    allStops = try await apiService.fetchAllStops()
                }
                
                // Find top 2 nearest stops
                let stops = shortestPathService.findNearestStops(from: location.coordinate, to: allStops, count: 2)
                self.nearbyStops = stops
                
                for stop in stops {
                    let d = location.distance(from: CLLocation(latitude: stop.lat, longitude: stop.lng)) / 1000.0
                    self.distances[stop.id] = d
                    
                    calculateWalkingRoute(for: stop)
                }
                
                wsService.connect()
                
            } catch {
                self.error = "Failed to load dashboard: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    func selectStop(_ stop: BusStop) {
        self.selectedStop = stop
        fetchBuses(for: stop)
        saveSearch(nearest: stop)
    }
    
    private func calculateWalkingRoute(for stop: BusStop) {
        guard let location = currentUserLocation else { return }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: stop.coordinate))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let route = response?.routes.first else { return }
            DispatchQueue.main.async {
                self.routes[stop.id] = route
                self.walkingTimes[stop.id] = route.expectedTravelTime
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
        let dist = distances[nearest.id] ?? 0
        
        Task {
            try? await apiService.saveStudentStopSearch(
                studentId: studentId,
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                nearestStopId: Int(nearest.id) ?? 0,
                distance: dist
            )
        }
    }
    
    deinit {
        wsService.disconnect()
    }
}
