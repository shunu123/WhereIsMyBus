import SwiftUI

@main
struct WhereIsMyBusApp: App {

    init() {
        // Firebase removed
        // Clear any stale session so login is always required on fresh launch
        SessionManager.shared.logout()
        // Pre-warm stop suggestions cache at launch
        StopSuggestionService.shared.prefetch()
    }

    @StateObject private var router = AppRouter()
    @StateObject private var theme = ThemeManager()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var session = SessionManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Gate between Login and Main App
                if session.isLoggedIn {
                    // Main Content
                    RouteShellView()
                } else {
                    NavigationStack(path: $router.path) {
                        LoginView()
                            .navigationDestination(for: AppRouter.AppPage.self) { route in
                                if case .registration = route {
                                    RegistrationView()
                                        .environmentObject(router)
                                        .environmentObject(theme)
                                }
                            }
                    }
                }

                // Overlay Splash Screen
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .applyCustomAppTheme(theme)
            .environmentObject(router)
            .environmentObject(theme)
            .environmentObject(locationManager)
            .environmentObject(languageManager)
            .environmentObject(session)
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
