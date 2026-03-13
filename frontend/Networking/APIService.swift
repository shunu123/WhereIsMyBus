import Foundation

struct APIListResponse<T: Decodable>: Decodable {
    let ok: Bool
    let data: [T]
}

struct APIObjectResponse<T: Decodable>: Decodable {
    let ok: Bool
    let data: T?
}

struct StopsAPIResponse: Decodable {
    let stops: [BusStop]
    
    enum CodingKeys: String, CodingKey {
        case stops
    }
}

// Transit models moved to TransitModels.swift


enum APIError: LocalizedError {
    case serverError(Int, String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .serverError(let code, let msg):
            return "Server error \(code): \(msg)"
        case .decodingError(let msg):
            return "Data error: \(msg)"
        }
    }
}

// MARK: - Admin Creation Models
struct CreateTripStopIn: Encodable {
    let stop_id: Int
    let stop_order: Int
    let arrival: String
    let departure: String
}

struct CreateTripIn: Encodable {
    let bus_id: Int
    let route_id: Int
    let service_date: String
    let start_time: String
    let end_time: String
    let stops: [CreateTripStopIn]
}

final class APIService {

    static let shared = APIService()
    private init() {}

    private let decoder = JSONDecoder()

    private func fetch<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        print("API CALL:", url.absoluteString)

        var request = URLRequest(url: url)
        // Required for loca.lt tunnels — bypasses the browser reminder page
        request.addValue("true", forHTTPHeaderField: "bypass-tunnel-reminder")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("STATUS:", http.statusCode)
            
            // Permanent fix: check status BEFORE decoding
            guard (200...299).contains(http.statusCode) else {
                // Try to extract a human-readable error message from the JSON body
                var msg = "Unknown error"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let detailStr = json["detail"] as? String {
                        msg = detailStr
                    } else if let detailDict = json["detail"] as? [String: Any],
                              let err = detailDict["error"] as? String {
                        msg = err
                    }
                } else if let rawStr = String(data: data, encoding: .utf8)?.prefix(200).description {
                    msg = rawStr
                }
                throw APIError.decodingError(msg)
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ DECODING ERROR:", error)
            if let rawString = String(data: data, encoding: .utf8) {
                print("📝 Raw Response Body: \(rawString)")
            }
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    private func post<T: Decodable, B: Encodable>(_ url: URL, body: B, as type: T.Type) async throws -> T {
        print("API POST:", url.absoluteString)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        // Required for loca.lt tunnels — bypasses the browser reminder page
        request.addValue("true", forHTTPHeaderField: "bypass-tunnel-reminder")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("STATUS:", http.statusCode)
            guard (200...299).contains(http.statusCode) else {
                var msg = "Unknown error"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let detailStr = json["detail"] as? String {
                        msg = detailStr
                    } else if let detailDict = json["detail"] as? [String: Any],
                              let err = detailDict["error"] as? String {
                        msg = err
                    }
                } else if let rawStr = String(data: data, encoding: .utf8)?.prefix(200).description {
                    msg = rawStr
                }
                throw APIError.decodingError(msg)
            }
        }

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Stops
    func fetchStops(routeId: String, dir: String) async throws -> [BusStop] {
        let url = URL(string: "\(APIConfig.baseURL)/api/stops?rt=\(routeId)&dir=\(dir)")!
        struct TransitStop: Decodable {
            let stpid: String
            let stpnm: String
            let lat: Double
            let lon: Double
        }
        let resp = try await fetch(url, as: [TransitStop].self)
        return resp.map { BusStop(id: $0.stpid, name: $0.stpnm, lat: $0.lat, lng: $0.lon) }
    }

    func fetchAllStops() async throws -> [BusStop] {
        let url = URL(string: "\(APIConfig.baseURL)/stops")!
        struct DBStop: Decodable {
            let id: Int
            let name: String
            let lat: Double
            let lng: Double
        }
        let resp = try await fetch(url, as: APIListResponse<DBStop>.self)
        return resp.data.map { BusStop(id: "\($0.id)", name: $0.name, lat: $0.lat, lng: $0.lng) }
    }

    func fetchRoutes(q: String = "", offset: Int = 0) async throws -> (routes: [BusRoute], total: Int) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/routes")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        struct RouteData: Decodable {
            let id: Int
            let name: String
            let ext_route_id: String?
        }
        
        struct PaginatedResponse: Decodable {
            let ok: Bool
            let data: [RouteData]
            let total: Int
        }
        
        let resp = try await fetch(comps.url!, as: PaginatedResponse.self)
        let routes = resp.data.map { 
            BusRoute(id: $0.id, name: $0.name, ext_route_id: $0.ext_route_id, from_name: nil, to_name: nil, stops: nil) 
        }
        return (routes, resp.total)
    }

    // MARK: - All Daily Buses
    func fetchBuses(forRoute: String? = nil) async throws -> [DailyBusTrip] {
        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "Asia/Kolkata")
            return f.string(from: Date())
        }()
        
        var comps = URLComponents(string: "\(APIConfig.baseURL)/buses")!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "service_date", value: today)]
        if let forRoute { queryItems.append(URLQueryItem(name: "route", value: forRoute)) }
        comps.queryItems = queryItems
        
        let resp = try await fetch(comps.url!, as: APIListResponse<DailyBusTrip>.self)
        
        // Register these buses in the repository so they are available for mapping
        for trip in resp.data {
             let bus = Bus(
                 id: UUID(),
                 number: trip.busNo ?? "N/A",
                 headsign: trip.routeName ?? "Transit Route",
                 departsAt: "--",
                 durationText: "--",
                 status: .onTime,
                 statusDetail: "Live",
                 trackingStatus: .scheduled,
                 etaMinutes: nil,
                 route: Route(from: "", to: "", stops: []),
                 vehicleId: trip.tripId,
                 busId: trip.busId,
                 extTripId: trip.extTripId
             )
             BusRepository.shared.register(bus: bus)
        }
        
        return resp.data
    }

    // MARK: - Search Trips
    func searchRealtime(routeId: String, fromStopId: String) async throws -> [SearchTrip] {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/search/realtime")!
        comps.queryItems = [
            URLQueryItem(name: "rt", value: routeId),
            URLQueryItem(name: "stpid", value: fromStopId)
        ]
        
        // This endpoint returns a list of SearchTrip already formatted by the backend
        let resp = try await fetch(comps.url!, as: APIListResponse<SearchTrip>.self)
        return resp.data
    }

    func searchTrips(fromStopId: String, toStopId: String, routeId: String = "20", dir: String = "Eastbound") async throws -> [SearchTrip] {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/track")!
        comps.queryItems = [
            URLQueryItem(name: "route_id", value: routeId),
            URLQueryItem(name: "from_stop_id", value: fromStopId),
            URLQueryItem(name: "to_stop_id", value: toStopId),
            URLQueryItem(name: "dir", value: dir)
        ]

        let resp = try await fetch(comps.url!, as: TransitTrackResponse.self)
        
        let durStr = resp.duration.replacingOccurrences(of: "m", with: "")
        
        // Convert the backend structure to the iOS SearchTrip model expected by SwiftUI
        let isLive = resp.bus_live_location != nil
        let trip = SearchTrip(
            tripId: Int(resp.trip_id ?? resp.route_id) ?? 0,
            extTripId: resp.trip_id ?? resp.route_id,
            busId: nil,
            busNo: "Transit Route \(resp.route_id)",
            label: resp.duration,
            routeId: Int(resp.route_id) ?? 0,
            routeName: "Route \(resp.route_id)",
            extRouteId: resp.route_id,
            fromDeparture: resp.schedule.departure_time,
            toArrival: resp.schedule.arrival_time,
            durationMinutes: Int(durStr),
            status: isLive ? "Live" : "Scheduled",
            busLiveLocation: resp.bus_live_location,
            nextStopName: nil,
            currentStopName: nil
        )
        return [trip]
    }

    /// Name-based bus search — calls /api/routes/search with stop name strings.
    /// Returns all buses that travel from `fromName` → `toName` without requiring stop IDs.
    func fetchRoutesSearch(fromName: String, toName: String) async throws -> [SearchTrip] {
        guard let fromEnc = fromName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let toEnc = toName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        let url = URL(string: "\(APIConfig.baseURL)/api/routes/search?from_stop=\(fromEnc)&to_stop=\(toEnc)")!
        let resp = try await fetch(url, as: APIListResponse<SearchTrip>.self)
        return resp.data
    }

    func fetchFullTripDetails(routeId: String, direction: String, vehicleId: String) async throws -> TransitFullTripResponse {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/trip/full_details")!
        comps.queryItems = [
            URLQueryItem(name: "rt", value: routeId),
            URLQueryItem(name: "dir", value: direction),
            URLQueryItem(name: "vid", value: vehicleId)
        ]
        
        return try await fetch(comps.url!, as: TransitFullTripResponse.self)
    }

    func fetchRouteStops(routeId: Int) async throws -> [Stop] {
        let url = URL(string: "\(APIConfig.baseURL)/api/routes/\(routeId)/stops")!
        struct StopNode: Decodable {
            let stop_id: Int
            let name: String
            let lat: Double
            let lng: Double
            let stop_order: Int
        }
        let resp = try await fetch(url, as: APIListResponse<StopNode>.self)
        return resp.data.map { node in
            Stop(id: "\(node.stop_id)", name: node.name, coordinate: Coord(lat: node.lat, lon: node.lng), timeText: nil, stopOrder: node.stop_order)
        }
    }

    // MARK: - Timeline
    func fetchTimeline(tripId: Int? = nil, extTripId: String? = nil) async throws -> [TimelineStop] {
        let identifier = extTripId ?? "\(tripId ?? 0)"
        let urlString = "\(APIConfig.baseURL)/trips/\(identifier)/timeline"
        let url = URL(string: urlString)!
        
        do {
            let resp = try await fetch(url, as: APIListResponse<TimelineStop>.self)
            return resp.data
        } catch {
            let resp = try await fetch(url, as: [TimelineStop].self)
            return resp
        }
    }

    // MARK: - Latest GPS
    func fetchLatestGPS(tripId: Int? = nil, extTripId: String? = nil, routeId: Int? = nil) async throws -> GPSPoint? {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/gps/latest")!
        var items: [URLQueryItem] = []
        if let tid = tripId {
            items.append(URLQueryItem(name: "trip_id", value: "\(tid)"))
        }
        if let etid = extTripId {
            items.append(URLQueryItem(name: "ext_trip_id", value: etid))
        }
        comps.queryItems = items

        let resp = try await fetch(comps.url!, as: APIObjectResponse<GPSPoint>.self)
        return resp.data
    }

    // MARK: - Live Fleet Mapping
    func fetchLiveFleetGPS() async throws -> [GPSPoint] {
        let url = URL(string: "\(APIConfig.baseURL)/gps/live")!
        let resp = try await fetch(url, as: APIListResponse<GPSPoint>.self)
        return resp.data
    }

    // MARK: - Update GPS
    func updateGPS(tripId: Int, busId: Int, lat: Double, lng: Double, speed: Double? = nil, heading: Double? = nil) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/gps")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = GPSIn(
            trip_id: tripId,
            bus_id: busId,
            lat: lat,
            lng: lng,
            speed: speed,
            heading: heading,
            ts: nil
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("GPS update failed with status: \(http.statusCode)")
        }
    }

    // MARK: - Recent Searches
    func saveRecentSearch(fromStopId: String, toStopId: String, fromName: String, toName: String, userId: Int? = nil) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/recent_searches")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "from_stop_id": fromStopId,
            "to_stop_id": toStopId,
            "from_name": fromName,
            "to_name": toName,
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let uid = userId {
            body["user_id"] = uid
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("saveRecentSearch failed with status: \(http.statusCode)")
        } else {
            print("saveRecentSearch success")
        }
    }

    func saveStudentStopSearch(studentId: Int, lat: Double, lng: Double, nearestStopId: Int, distance: Double) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/student-stop-search")!
        let body: [String: Any] = [
            "student_id": studentId,
            "current_lat": lat,
            "current_lng": lng,
            "nearest_stop_id": nearestStopId,
            "distance": distance,
            "search_time": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            print("saveStudentStopSearch failed: \(http.statusCode)")
        }
    }

    func fetchBusesForStop(stopId: String) async throws -> [DailyBusTrip] {
        let url = URL(string: "\(APIConfig.baseURL)/buses?stop_id=\(stopId)")!
        let resp = try await fetch(url, as: APIListResponse<DailyBusTrip>.self)
        return resp.data
    }

    func fetchRecentSearches(role: String = "student", userId: Int? = nil) async throws -> [RecentSearch] {
        var urlComp = URLComponents(string: "\(APIConfig.baseURL)/recent_searches")!
        var items = [URLQueryItem(name: "role", value: role)]
        if let uid = userId {
            items.append(URLQueryItem(name: "user_id", value: "\(uid)"))
        }
        urlComp.queryItems = items
        
        let resp = try await fetch(urlComp.url!, as: APIListResponse<RecentSearch>.self)
        return resp.data
    }

    func fetchTripHistory(tripId: Int) async throws -> [GPSPoint] {
        let url = URL(string: "\(APIConfig.baseURL)/gps/history?trip_id=\(tripId)")!
        let resp = try await fetch(url, as: APIListResponse<GPSPoint>.self)
        return resp.data
    }
    
    func fetchFleetHistory(date: String) async throws -> [FleetTrip] {
        let url = URL(string: "\(APIConfig.baseURL)/fleet/history?date=\(date)")!
        let resp = try await fetch(url, as: FleetHistoryResponse.self)
        return resp.data
    }

    // AUTH
    func login(regNoOrEmail: String, password: [String: String]) async throws -> (user: User?, requiresOTP: Bool, target: String?) {
        let url = URL(string: "\(APIConfig.baseURL)/login")!
        let body = ["reg_no_or_email": regNoOrEmail, "password": password["password"] ?? ""]
        let resp = try await post(url, body: body, as: AuthResponse.self)
        
        if resp.requires_otp == true {
            return (nil, true, resp.target)
        }
        
        if let user = resp.user {
            return (user, false, nil)
        }
        throw APIError.serverError(401, resp.detail ?? "Login failed")
    }

    func register(userData: [String: Any]) async throws -> Bool {
        let url = URL(string: "\(APIConfig.baseURL)/register")!
        let resp = try await post(url, body: userData.compactMapValues { "\($0)" }, as: GenericResponse.self)
        return resp.ok
    }

    func sendOTP(target: String, isAdmin: Bool = false, isRegistration: Bool = false) async throws -> (ok: Bool, target: String?) {
        let url = URL(string: "\(APIConfig.baseURL)/send_otp")!
        let body: [String: Any] = ["target": target, "is_admin": isAdmin, "is_registration": isRegistration]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
             let msg = String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown API Error"
             throw APIError.serverError(http.statusCode, msg)
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ok = json["ok"] as? Bool {
            return (ok, json["target"] as? String)
        }
        
        return (true, nil)
    }

    func verifyOTP(target: String, otp: String, isAdmin: Bool = false) async throws -> User? {
        let url = URL(string: "\(APIConfig.baseURL)/verify_otp")!
        let body: [String: Any] = ["target": target, "code": otp, "is_admin": isAdmin]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
             let msg = String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown API Error"
             throw APIError.serverError(http.statusCode, msg)
        }
        
        let decoder = JSONDecoder()
        let resp = try decoder.decode(AuthResponse.self, from: data)
        return resp.user
    }
    
    func resetPassword(email: String, newPassword: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/reset_password")!
        let body: [String: Any] = ["email": email, "new_password": newPassword]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
             let msg = String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unknown API Error"
             throw APIError.serverError(http.statusCode, msg)
        }
    }

    // SUPPORT
    func postReport(email: String?, subject: String, message: String, category: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/report")!
        let body: [String: Any] = [
            "user_email": email ?? "",
            "subject": subject,
            "message": message,
            "category": category
        ]
        _ = try await post(url, body: body.compactMapValues { "\($0)" }, as: GenericResponse.self)
    }

    func postContact(email: String?, subject: String, message: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/contact")!
        let body: [String: Any] = [
            "user_email": email ?? "",
            "subject": subject,
            "message": message
        ]
        _ = try await post(url, body: body.compactMapValues { "\($0)" }, as: GenericResponse.self)
    }

    func postDriverReport(email: String, busNumber: String, driverInfo: String, description: String) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/report_driver")!
        let body: [String: Any] = [
            "user_email": email,
            "bus_number": busNumber,
            "driver_info": driverInfo,
            "description": description
        ]
        _ = try await post(url, body: body.compactMapValues { "\($0)" }, as: GenericResponse.self)
    }

    /// Admin: Fetch all registered students
    func fetchStudents() async throws -> [StudentRecord] {
        let url = URL(string: "\(APIConfig.baseURL)/students")!
        let res = try await fetch(url, as: StudentsResponse.self)
        if !res.ok {
            throw APIError.serverError(0, "Failed to load students")
        }
        return res.students
    }

    // MARK: - Admin Scheduling
    func createTrip(_ trip: CreateTripIn) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/trips")!
        let _ = try await post(url, body: trip, as: APIObjectResponse<Int>.self)
    }
}

struct RecentSearch: Codable, Identifiable {
    let id: Int
    let from_stop_id: String
    let to_stop_id: String
    let from_name: String
    let to_name: String
    let ts: String
}

struct GPSIn: Codable {
    let trip_id: Int
    let bus_id: Int
    let lat: Double
    let lng: Double
    var speed: Double? = nil
    var heading: Double? = nil
    var ts: String? = nil
}

// MARK: - Admin History Models
struct AdminHistoryStop: Codable, Identifiable {
    var id: Int { stop_id }
    let stop_id: Int
    let stop_name: String
    let lat: Double
    let lng: Double
    let stop_order: Int
    let sched_arrival: String?
    let sched_departure: String?
    let actual_arrival: String?
    let actual_departure: String?
    let status: String?
    let delay_mins: Int?
}

struct AdminHistoryMapPoint: Codable {
    let lat: Double
    let lng: Double
    let speed: Double?
    let ts: String?
}

struct AdminHistoryTrip: Codable, Identifiable {
    let trip_id: Int?
    let bus_number: String
    let route_name: String
    let points: [AdminHistoryMapPoint]
    let ext_vehicle_id: String?
    
    var id: String {
        if let tid = trip_id, tid != 0 { return "\(tid)" }
        return ext_vehicle_id ?? bus_number
    }
}

private struct AdminHistoryTimelineResponse: Codable {
    let ok: Bool
    let trip_id: Int?
    let date: String?
    let timeline: [AdminHistoryStop]?
    let error: String?
}

private struct AdminHistoryMapResponse: Codable {
    let ok: Bool
    let date: String?
    let trips: [AdminHistoryTrip]?
    let error: String?
}

private struct AdminHistoryDatesResponse: Codable {
    let ok: Bool
    let dates: [String]
}

// MARK: - Admin History API methods
extension APIService {
    func fetchAdminHistoryDates() async throws -> [String] {
        let url = URL(string: "\(APIConfig.baseURL)/api/admin/history/dates")!
        let resp = try await fetch(url, as: AdminHistoryDatesResponse.self)
        return resp.dates
    }

    func fetchAdminHistoryTimeline(date: String, tripId: Int?) async throws -> [AdminHistoryStop] {
        let tid = tripId ?? 0
        let url = URL(string: "\(APIConfig.baseURL)/api/admin/history/timeline?date=\(date)&trip_id=\(tid)")!
        let resp = try await fetch(url, as: AdminHistoryTimelineResponse.self)
        return resp.timeline ?? []
    }

    func fetchAdminHistoryMap(date: String, routeName: String? = nil, tripId: Int? = nil) async throws -> [AdminHistoryTrip] {
        var urlStr = "\(APIConfig.baseURL)/api/admin/history/map?date=\(date)"
        if let r = routeName { urlStr += "&route_name=\(r.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? r)" }
        if let t = tripId   { urlStr += "&trip_id=\(t)" }
        let url = URL(string: urlStr)!
        let resp = try await fetch(url, as: AdminHistoryMapResponse.self)
        return resp.trips ?? []
    }
}
