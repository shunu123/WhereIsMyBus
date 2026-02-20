import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss

    @State private var enableNotifications = true
    @State private var arrivalAlerts = true
    @State private var autoRecenter = false // Screenshot shows off
    @State private var is24h = false
    
    // For navigation/sheet state
    @State private var showLanguage = false
    @State private var showTheme = false
    @State private var showCity = false
    
    @State private var alertDistance: Int = 1
    @State private var showDistanceAlertSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    router.back()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.current.text)
                }
                
                Text(languageManager.localizedString("Settings"))
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // APP PREFERENCES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APP PREFERENCES")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.current.accent)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
                            settingsRow(icon: "globe", title: languageManager.localizedString("Language"), value: languageManager.currentLanguage) {
                                showLanguage = true
                            }
                            
                            Divider().padding(.leading, 50)
                            
                            settingsRow(icon: "mappin.and.ellipse", title: languageManager.localizedString("City"), value: "Chennai (Fixed)") {
                                // showCity = true // Locked to Chennai
                            }
                            
                            Divider().padding(.leading, 50)
                            
                            settingsRow(icon: "paintpalette", title: languageManager.localizedString("Theme"), value: "Light") {
                                showTheme = true
                            }
                            
                            Divider().padding(.leading, 50)
                            
                            toggleRow(icon: "clock", title: "24-Hour Time", isOn: $is24h)
                        }
                        .background(theme.current.card)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                    }
                    
                    // NOTIFICATIONS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTIFICATIONS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.current.accent)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
                            toggleRow(title: "Enable Notifications", isOn: $enableNotifications)
                            
                            Divider().padding(.leading, 16)
                            
                            toggleRow(title: "Arrival Alerts", isOn: $arrivalAlerts)
                            
                            Divider().padding(.leading, 16)
                            
                            settingsRow(title: "Default Alert Distance", value: "\(alertDistance) km before") {
                                showDistanceAlertSheet = true
                            }
                        }
                        .background(theme.current.card)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                    }

                    // MAP SETTINGS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAP SETTINGS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.current.accent)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
                            settingsRow(title: "Default Map Type", value: "Standard") {}
                            
                            Divider().padding(.leading, 16)
                            
                            toggleRow(title: "Auto Recenter on Bus", isOn: $autoRecenter)
                            
                            Divider().padding(.leading, 16)
                            
                            settingsRow(title: "Update Frequency", value: "Every 10 seconds") {}
                        }
                        .background(theme.current.card)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                    }
                    
                    // LOCATION SERVICES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LOCATION SERVICES")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.current.accent)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Permission Status")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(theme.current.text)
                                
                                Spacer()
                                
                                Text("Allowed")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.current.accent)
                            }
                            .padding(16)
                            
                            Divider()
                            
                            Button {
                                // Open iOS Settings
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "iphone")
                                        .font(.body)
                                        .foregroundStyle(theme.current.secondaryText)
                                    
                                    Text("Open iOS Settings")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(theme.current.text)
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .background(theme.current.background)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                    }
                    
                    // SUPPORT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUPPORT")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.current.accent)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
                            settingsRow(icon: "questionmark.circle", title: "Help & FAQ", value: nil) {
                                router.go(.help)
                            }
                            
                            Divider().padding(.leading, 50)
                            
                            settingsRow(icon: "flag", title: "Report Issue", value: nil) {
                                router.go(.report)
                            }
                            
                            Divider().padding(.leading, 50)
                            
                            settingsRow(icon: "envelope", title: "Contact Support", value: nil) {}
                        }
                        .background(theme.current.background)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                    }
                    
                    // ABOUT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABOUT")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.current.accent)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
                            settingsRow(icon: "info.circle", title: "About App", value: "v2.1.0") {
                                router.go(.about)
                            }
                        }
                        .background(theme.current.background)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                    }
                }
                .padding(16)
            }
        }
        .background(theme.current.background.ignoresSafeArea()) // Use theme bg
        .navigationBarHidden(true) // Use custom header
        .sheet(isPresented: $showLanguage) {
            SelectLanguageView()
        }
        .sheet(isPresented: $showTheme) {
            AppThemeView()
        }
        .sheet(isPresented: $showCity) {
            SelectCityView()
        }
        .sheet(isPresented: $showDistanceAlertSheet) {
            VStack(spacing: 20) {
                Text("Select Alert Distance")
                    .font(.headline)
                    .padding(.top)
                
                ForEach([0.5, 1.0, 2.0, 5.0], id: \.self) { km in
                    Button {
                        alertDistance = Int(km)
                        showDistanceAlertSheet = false
                    } label: {
                        HStack {
                            Text("\(String(format: "%.1f", km)) km before")
                                .foregroundStyle(theme.current.text)
                            Spacer()
                            if Double(alertDistance) == km {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.current.accent)
                            }
                        }
                        .padding()
                        .background(theme.current.card)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .presentationDetents([.medium])
        }
    }
    
    // Helper for rows with Icon
    func settingsRow(icon: String? = nil, title: String, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(theme.current.accent)
                        .frame(width: 24)
                }
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.current.text)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(theme.current.secondaryText)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.current.secondaryText)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // Helper for Toggle rows
    func toggleRow(icon: String? = nil, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(theme.current.accent)
                    .frame(width: 24)
            }
            
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.current.text)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.current.accent)
        }
        .padding(16)
    }
}
