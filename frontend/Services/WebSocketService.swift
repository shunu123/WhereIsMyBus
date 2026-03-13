import Foundation
import Combine

// MARK: - Decoded Vehicle from WebSocket push
struct WSVehicle: Decodable {
    let vid: String?          // vehicle ID
    let rt: String?           // route ID (e.g. "20")
    let des: String?          // destination / headsign
    let lat: String?
    let lon: String?
    let spd: Int?             // speed mph
    let hdg: String?          // heading degrees
    let tmstmp: String?       // timestamp string
    let dly: Bool?            // delayed flag
    let dir: String?          // direction

    // computed helpers
    var latDouble: Double { Double(lat ?? "") ?? 0 }
    var lonDouble: Double { Double(lon ?? "") ?? 0 }
}

struct WSGPSPayload: Decodable {
    let type: String
    let vehicles: [WSVehicle]?
    let ts: String?
}

// MARK: - WebSocket Service
/// Singleton that maintains a single WebSocket connection to /ws/gps.
/// Publishes decoded [WSVehicle] arrays to any subscriber.
/// Automatically reconnects on disconnect with exponential backoff.
final class WebSocketService: NSObject {
    static let shared = WebSocketService()
    private override init() { super.init() }

    // Publisher that emits whenever fresh GPS arrives
    let gpsPublisher = PassthroughSubject<[WSVehicle], Never>()
    // Connection state for UI indicator
    @Published var isConnected: Bool = false

    private var task: URLSessionWebSocketTask?
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectDelay: TimeInterval = 3
    private let maxReconnectDelay: TimeInterval = 30

    // MARK: - Connect
    func connect() {
        guard task == nil || task?.state != .running else { return }
        let wsURL = APIConfig.wsBaseURL + "/ws/gps"
        guard let url = URL(string: wsURL) else {
            print("WebSocketService: invalid URL \(wsURL)")
            return
        }
        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        reconnectDelay = 3
        print("WebSocketService: connecting to \(wsURL)")
        listen()
        startPing()
    }

    // MARK: - Disconnect
    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        pingTask?.cancel()
        reconnectTask?.cancel()
        isConnected = false
    }

    // MARK: - Listen loop
    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.listen() // chain for next message
            case .failure(let error):
                print("WebSocketService receive error: \(error)")
                self.scheduleReconnect()
            }
        }
    }

    // MARK: - Handle incoming data
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        var text: String?
        switch message {
        case .string(let s): text = s
        case .data(let d): text = String(data: d, encoding: .utf8)
        @unknown default: break
        }
        guard let text, let data = text.data(using: .utf8) else { return }
        do {
            let payload = try JSONDecoder().decode(WSGPSPayload.self, from: data)
            if payload.type == "gps_update", let vehicles = payload.vehicles {
                DispatchQueue.main.async {
                    self.gpsPublisher.send(vehicles)
                }
            }
        } catch {
            // Could be a ping/pong — ignore decode errors silently
        }
    }

    // MARK: - Keep-alive ping every 20s
    private func startPing() {
        pingTask?.cancel()
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                let ping = "{\"type\":\"ping\"}"
                try? await task?.send(.string(ping))
            }
        }
    }

    // MARK: - Reconnect with backoff
    private func scheduleReconnect() {
        isConnected = false
        task = nil
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
        print("WebSocketService: reconnecting in \(delay)s")
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self.connect() }
        }
    }
}
