import SwiftUI
import MapKit
import Combine

@MainActor
final class TripDetailTimelineViewModel: ObservableObject {
    @Published var mapRegion: MKCoordinateRegion
    @Published var selectedEvent: TripTimelineEvent?
    @Published var isReplayMode: Bool = false
    @Published var replayProgress: Double = 0.0
    
    let tripId: UUID
    let busNumber: String
    let startTime: String
    let endTime: String
    let trackPoints: [Coord]
    let timelineEvents: [TripTimelineEvent]
    
    var sortedEvents: [TripTimelineEvent] {
        timelineEvents.sorted { $0.timestamp < $1.timestamp }
    }
    
    init(tripId: UUID, busNumber: String, startTime: String, endTime: String, trackPoints: [Coord], timelineEvents: [TripTimelineEvent]) {
        self.tripId = tripId
        self.busNumber = busNumber
        self.startTime = startTime
        self.endTime = endTime
        self.trackPoints = trackPoints
        self.timelineEvents = timelineEvents
        
        // Calculate initial map region to fit all track points
        self.mapRegion = Self.calculateRegion(for: trackPoints)
    }
    
    static func calculateRegion(for points: [Coord]) -> MKCoordinateRegion {
        guard !points.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 13.0287, longitude: 80.0071),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        let latitudes = points.map { $0.lat }
        let longitudes = points.map { $0.lon }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = (maxLat - minLat) * 1.3 // Add 30% padding
        let spanLon = (maxLon - minLon) * 1.3
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.01), longitudeDelta: max(spanLon, 0.01))
        )
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func formatDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}
