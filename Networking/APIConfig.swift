import Foundation

enum APIConfig {

    /// 🌐 OPTION 1: GLOBAL ACCESS via loca.lt tunnel
    /// Run: lt --port 8000 --subdomain fast-numbers-beam
    /// The bypass-tunnel-reminder header is automatically added by APIService for all requests.
    static let publicURL = "https://fast-numbers-beam.loca.lt"

    /// 📶 OPTION 2: SAME Wi-Fi ACCESS (Mac + iPhone on same network — no tunnel needed)
    static let localHostName = "http://bujjuus-MacBook-Air.local:8000"

    /// 🛠️ OPTION 3: Simulator only
    static let localIP = "http://127.0.0.1:8000"

    /// 🚀 THE FINAL URL THE APP USES
    static var baseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"], !envURL.isEmpty {
            return envURL
        }
        #if targetEnvironment(simulator)
        return localIP         // Simulator: use localhost directly
        #else
        return localHostName   // Real device: use local Mac hostname over Wi-Fi (no tunnel needed)
        #endif
    }

    /// 🔌 WebSocket base URL (ws:// or wss://) — derived from baseURL automatically
    static var wsBaseURL: String {
        baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
    }
}
