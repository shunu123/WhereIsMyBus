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
    
    @Published var userRole: String? {
        didSet {
            UserDefaults.standard.set(userRole, forKey: "userRole")
        }
    }
    
    @Published var currentUser: User? {
        didSet {
            if let user = currentUser, let encoded = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(encoded, forKey: "currentUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentUser")
            }
        }
    }
    
    private init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.currentUserRegNo = UserDefaults.standard.string(forKey: "currentUserRegNo")
        self.userRole = UserDefaults.standard.string(forKey: "userRole")
        
        if let savedUser = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: savedUser) {
            self.currentUser = user
        }
    }
    
    func login(user: User) {
        self.currentUserRegNo = user.reg_no
        self.userRole = user.role
        self.currentUser = user
        self.isLoggedIn = true
    }
    
    func logout() {
        self.currentUserRegNo = nil
        self.userRole = nil
        self.currentUser = nil
        self.isLoggedIn = false
    }

    func resetIdleTimer() {
        // Disabled auto-logout
    }
}
