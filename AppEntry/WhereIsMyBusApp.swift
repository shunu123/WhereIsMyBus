import SwiftUI
import Firebase
@main
struct WhereIsMyBusApp: App {

    init() {
        let options = FirebaseOptions(contentsOfFile: Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")!)
        options?.databaseURL = "https://where-is-my-bus-6ae1a-default-rtdb.asia-southeast1.firebasedatabase.app"
        FirebaseApp.configure(options: options!)
    }

    @StateObject private var router = AppRouter()
    @StateObject private var theme = ThemeManager()
    @StateObject private var busTracker = BusTrackerService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var languageManager = LanguageManager()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main Content
                RouteShellView()
                
                // Overlay Splash Screen
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environmentObject(router)
            .environmentObject(theme)
            .environmentObject(busTracker)
            .environmentObject(locationManager)
            .environmentObject(languageManager)
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showSplash = false
                        }
                    }
                }
            }
        }
    }
}
