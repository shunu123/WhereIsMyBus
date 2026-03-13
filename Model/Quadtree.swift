import Foundation
import CoreLocation
import MapKit

/// A simple spatial boundary for the Quadtree.
struct QuadtreeRect {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    
    var centerLat: Double { (minLat + maxLat) / 2 }
    var centerLon: Double { (minLon + maxLon) / 2 }
    
    func contains(_ point: GPSPoint) -> Bool {
        return point.lat >= minLat && point.lat <= maxLat &&
               point.lng >= minLon && point.lng <= maxLon
    }
    
    func intersects(_ other: QuadtreeRect) -> Bool {
        return !(other.minLat > maxLat || other.maxLat < minLat ||
                 other.minLon > maxLon || other.maxLon < minLon)
    }
    
    static func fromRegion(_ region: MKCoordinateRegion, buffer: Double = 1.0) -> QuadtreeRect {
        let latDelta = region.span.latitudeDelta * buffer
        let lonDelta = region.span.longitudeDelta * buffer
        return QuadtreeRect(
            minLat: region.center.latitude - latDelta / 2,
            maxLat: region.center.latitude + latDelta / 2,
            minLon: region.center.longitude - lonDelta / 2,
            maxLon: region.center.longitude + lonDelta / 2
        )
    }
}

/// A Quadtree implementation for efficient spatial indexing of GPSPoints.
class Quadtree {
    private let boundary: QuadtreeRect
    private let capacity: Int
    private var points: [GPSPoint] = []
    private var subdivided = false
    
    private var northwest: Quadtree?
    private var northeast: Quadtree?
    private var southwest: Quadtree?
    private var southeast: Quadtree?
    
    init(boundary: QuadtreeRect, capacity: Int = 32) {
        self.boundary = boundary
        self.capacity = capacity
    }
    
    @discardableResult
    func insert(_ point: GPSPoint) -> Bool {
        guard boundary.contains(point) else { return false }
        
        if points.count < capacity && !subdivided {
            points.append(point)
            return true
        }
        
        if !subdivided {
            subdivide()
        }
        
        return (northwest?.insert(point) ?? false) ||
               (northeast?.insert(point) ?? false) ||
               (southwest?.insert(point) ?? false) ||
               (southeast?.insert(point) ?? false)
    }
    
    private func subdivide() {
        let midLat = boundary.centerLat
        let midLon = boundary.centerLon
        
        northwest = Quadtree(boundary: QuadtreeRect(minLat: midLat, maxLat: boundary.maxLat, minLon: boundary.minLon, maxLon: midLon), capacity: capacity)
        northeast = Quadtree(boundary: QuadtreeRect(minLat: midLat, maxLat: boundary.maxLat, minLon: midLon, maxLon: boundary.maxLon), capacity: capacity)
        southwest = Quadtree(boundary: QuadtreeRect(minLat: boundary.minLat, maxLat: midLat, minLon: boundary.minLon, maxLon: midLon), capacity: capacity)
        southeast = Quadtree(boundary: QuadtreeRect(minLat: boundary.minLat, maxLat: midLat, minLon: midLon, maxLon: boundary.maxLon), capacity: capacity)
        
        subdivided = true
        
        // Re-insert existing points into children
        let existingPoints = points
        points.removeAll()
        for p in existingPoints {
            _ = insert(p)
        }
    }
    
    func query(in range: QuadtreeRect, found: inout [GPSPoint]) {
        guard boundary.intersects(range) else { return }
        
        for p in points {
            if range.contains(p) {
                found.append(p)
            }
        }
        
        if subdivided {
            northwest?.query(in: range, found: &found)
            northeast?.query(in: range, found: &found)
            southwest?.query(in: range, found: &found)
            southeast?.query(in: range, found: &found)
        }
    }
}
