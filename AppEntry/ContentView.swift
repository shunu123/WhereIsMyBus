import SwiftUI

struct ContentView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var theme = ThemeManager()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        RouteShellView()
            .environmentObject(router)
            .environmentObject(theme)
            .environmentObject(languageManager)
            .environmentObject(locationManager)
    }
}
