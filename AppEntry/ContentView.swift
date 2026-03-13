import SwiftUI

struct ContentView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var theme = ThemeManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var locationManager = LocationManager.shared

    var body: some View {
        RouteShellView()
            .applyCustomAppTheme(theme)
            .environmentObject(router)
            .environmentObject(theme)
            .environmentObject(languageManager)
            .environmentObject(locationManager)
    }
}
