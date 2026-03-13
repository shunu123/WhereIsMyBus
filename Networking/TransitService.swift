import Foundation

class TransitService {
    static let shared = TransitService()
    private init() {}
    
    func fetchDirections(rt: String) async throws -> [TransitDirection] {
        let url = URL(string: "\(APIConfig.baseURL)/api/routes/\(rt)/directions")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct DirectionResponse: Decodable {
            let directions: [TransitDirection]
        }
        
        let resp = try JSONDecoder().decode(DirectionResponse.self, from: data)
        return resp.directions
    }
    
    func fetchStops(rt: String, dir: String) async throws -> [BusStop] {
        let encodedDir = dir.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dir
        struct TransitStopObj: Decodable {
            let stpid: String
            let stpnm: String
            let lat: Double
            let lon: Double
        }
        let url = URL(string: "\(APIConfig.baseURL)/api/stops?rt=\(rt)&dir=\(encodedDir)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let ctaStops = try JSONDecoder().decode([TransitStopObj].self, from: data)
        return ctaStops.map { BusStop(id: $0.stpid, name: $0.stpnm, lat: $0.lat, lng: $0.lon) }
    }
}
