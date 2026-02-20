import Foundation
import Combine

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var isLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    
    @Published var currentUserRegNo: String? {
        didSet {
            UserDefaults.standard.set(currentUserRegNo, forKey: "currentUserRegNo")
        }
    }
    
    private var idleTimer: Timer?
    private let idleInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.currentUserRegNo = UserDefaults.standard.string(forKey: "currentUserRegNo")
        if isLoggedIn {
            startIdleTimer()
        }
    }
    
    func login(regNo: String) {
        self.currentUserRegNo = regNo
        self.isLoggedIn = true
        startIdleTimer()
    }
    
    func logout() {
        self.currentUserRegNo = nil
        self.isLoggedIn = false
        stopIdleTimer()
    }
    
    func resetIdleTimer() {
        guard isLoggedIn else { return }
        stopIdleTimer()
        startIdleTimer()
    }
    
    private func startIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleInterval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.logout()
            }
        }
    }
    
    private func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
}
