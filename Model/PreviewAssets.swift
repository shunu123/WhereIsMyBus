import Foundation
import CoreLocation

/// Holds all static sample data used exclusively by Xcode Canvas #Preview blocks.
/// Do NOT reference this from production code paths.
enum PreviewAssets {

    // MARK: - Sample Route

    static let sampleRoute: Route = {
        let stops: [Stop] = [
            Stop(name: "Tambaram",
                 coordinate: Coord(lat: 12.9249, lon: 80.1167),
                 timeText: "07:30 AM",
                 isMajorStop: true),
            Stop(name: "Chromepet",
                 coordinate: Coord(lat: 12.9516, lon: 80.1407),
                 timeText: "07:40 AM",
                 isMajorStop: false),
            Stop(name: "Guindy",
                 coordinate: Coord(lat: 13.0067, lon: 80.2206),
                 timeText: "07:55 AM",
                 isMajorStop: true),
            Stop(name: "Koyambedu",
                 coordinate: Coord(lat: 13.0694, lon: 80.1948),
                 timeText: "08:10 AM",
                 isMajorStop: true),
            Stop(name: "Saveetha Engineering College",
                 coordinate: Coord(lat: 13.0287, lon: 80.0071),
                 timeText: "08:30 AM",
                 isMajorStop: true)
        ]
        return Route(from: "Tambaram",
                     to: "Saveetha Engineering College",
                     stops: stops,
                     plannedPolyline: stops.map { $0.coordinate })
    }()

    // MARK: - Sample Bus

    static let sampleBus: Bus = Bus(
        number: "S-ENG-101",
        headsign: "Saveetha Eng - Route 1",
        departsAt: "07:30 AM",
        durationText: "1h 00m",
        status: .onTime,
        statusDetail: "On schedule",
        trackingStatus: .arriving,
        etaMinutes: 15,
        route: sampleRoute
    )

    // MARK: - Nearby Stops (for HomeMapView preview)

    static let nearbyStops: [BusStop] = [
        BusStop(id: "1", name: "Majestic",
                coordinate: CLLocationCoordinate2D(latitude: 12.9763, longitude: 77.5731)),
        BusStop(id: "2", name: "Hebbal",
                coordinate: CLLocationCoordinate2D(latitude: 13.0358, longitude: 77.5970)),
        BusStop(id: "3", name: "Silk Board",
                coordinate: CLLocationCoordinate2D(latitude: 12.9177, longitude: 77.6238)),
        BusStop(id: "4", name: "Electronic City",
                coordinate: CLLocationCoordinate2D(latitude: 12.8456, longitude: 77.6603))
    ]
}
