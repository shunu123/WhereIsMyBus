import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss

    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("arrivalAlerts") private var arrivalAlerts = true
    @AppStorage("autoRecenter") private var autoRecenter = false
    @AppStorage("is24h") private var is24h = false
    @AppStorage("alertDistance") private var alertDistance: Int = 1
    @AppStorage("selectedAlarmSound") private var selectedAlarmSound: String = ""
    
    // For navigation/sheet state
    @State private var showTheme = false
    @State private var showCity = false
    
    @State private var showDistanceAlertSheet = false
    @State private var showAlarmSoundSheet = false

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
            .background(theme.current.background) // Header background
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // APP PREFERENCES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APP PREFERENCES")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.current.accent)
                            .padding(.leading, 16)
                        
                        VStack(spacing: 0) {
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
                            
                            settingsRow(title: "Alarm Sound", value: selectedAlarmSound.isEmpty ? "Default" : (selectedAlarmSound.components(separatedBy: ".").first?.capitalized ?? "Custom")) {
                                showAlarmSoundSheet = true
                            }
                            
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
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
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

                    // ADMINISTRATION (Admin Only)
                    if SessionManager.shared.userRole == "admin" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ADMINISTRATION")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.current.accent)
                                .padding(.leading, 16)
                            
                            VStack(spacing: 0) {
                                settingsRow(icon: "person.3.sequence.fill", title: "Student Data", value: nil) {
                                    router.go(.studentData)
                                }
                            }
                            .background(theme.current.card)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.current.border, lineWidth: 1)
                            )
                        }
                    }

                    // SUPPORT & FEEDBACK (Student Only)
                    if SessionManager.shared.userRole != "admin" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SUPPORT & FEEDBACK")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.current.accent)
                                .padding(.leading, 16)
                            
                            VStack(spacing: 0) {
                                settingsRow(icon: "questionmark.circle", title: "Help & FAQ", value: nil) {
                                    router.go(.help)
                                }
                                
                                Divider().padding(.leading, 50)
                                
                                settingsRow(icon: "exclamationmark.bubble", title: "Report Issue", value: nil) {
                                    router.go(.report)
                                }
                            }
                            .background(theme.current.card)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.current.border, lineWidth: 1)
                            )
                        }
                    }

                    // LOGOUT
                    Button {
                        session.logout()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title3)
                                .foregroundStyle(.red)
                            
                            Text("Logout")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
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
        .sheet(isPresented: $showAlarmSoundSheet) {
            VStack(spacing: 20) {
                Text("Select Alarm Sound")
                    .font(.headline)
                    .padding(.top)
                
                let sounds = [("Default", ""), ("Chime", "chime.caf"), ("Radar", "radar.caf"), ("Beacon", "beacon.caf")]
                
                ForEach(sounds, id: \.1) { (label, file) in
                    Button {
                        selectedAlarmSound = file
                        NotificationManager.shared.selectedSoundName = file
                        showAlarmSoundSheet = false
                    } label: {
                        HStack {
                            Text(label)
                                .foregroundStyle(theme.current.text)
                            Spacer()
                            if selectedAlarmSound == file {
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
