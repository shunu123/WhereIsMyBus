import SwiftUI

struct DrawerView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var locationManager: LocationManager

    @Binding var isOpen: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // ... rest same ...
                // Drawer Content
                if isOpen {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                             HStack {
                                 ZStack {
                                     Circle()
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        .frame(width: 48, height: 48)
                                     
                                     Image(systemName: "person.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                 }
                                 
                                 Spacer()
                                 
                                 Button {
                                     withAnimation { isOpen = false }
                                 } label: {
                                    Image(systemName: "xmark")
                                         .font(.title3)
                                         .foregroundStyle(.white.opacity(0.8))
                                 }
                             }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("\(SessionManager.shared.currentUser?.first_name ?? "Welcome") \(SessionManager.shared.currentUser?.last_name ?? "Back")!")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    
                                    Button {
                                        go(.editProfile)
                                    } label: {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                                
                                if let regNo = SessionManager.shared.currentUserRegNo {
                                    Text("\(regNo) • \(SessionManager.shared.userRole == "admin" ? "Admin" : (SessionManager.shared.currentUser?.department ?? "Student"))")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.caption)
                                    Text(locationManager.currentAddress)
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(20)
                        .padding(.top, 50) // Status bar
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom))
                        
                        // Menu Items
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // Settings / Quick Action
                                Button {
                                    go(.settings)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "gearshape.fill")
                                            .foregroundStyle(theme.current.accent)
                                            .font(.title3)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Settings")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(theme.current.text)
                                            
                                            Text("Theme & more")
                                                .font(.caption)
                                                .foregroundStyle(theme.current.secondaryText)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(theme.current.accent.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                
                                // Navigation
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("NAVIGATION")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme.current.accent)
                                    
                                    drawerRow(icon: "house.fill", title: "Home") { go(.home) }
                                    drawerRow(icon: "bookmark.fill", title: "Saved Routes") { go(.savedRoutes) }
                                    drawerRow(icon: "clock.fill", title: "Recent Searches") { go(.recentSearches) }
                                    
                                    if SessionManager.shared.userRole == "admin" {
                                        drawerRow(icon: "map.fill", title: "Fleet Activity") { go(.activeFleet) }
                                        drawerRow(icon: "calendar.badge.plus", title: "Add Bus Schedule") { go(.adminScheduling) }
                                    }
                                }
                                
                                Divider()
                                
                                // Reports (Student Only)
                                if SessionManager.shared.userRole != "admin" {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("REPORTS")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.orange)
                                        
                                        drawerRow(icon: "exclamationmark.bubble.fill", title: "Report Issue") { go(.report) }
                                    }
                                    
                                    Divider()
                                }
                                
                                // Support
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("SUPPORT")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.green)
                                    
                                    if SessionManager.shared.userRole != "admin" {
                                        drawerRow(icon: "questionmark.circle", title: "Help & FAQ") { go(.help) }
                                    }
                                    drawerRow(icon: "info.circle", title: "About") { go(.about) }
                                    drawerRow(icon: "star", title: "Rate App") {
                                        withAnimation {
                                            isOpen = false
                                            router.showRateUs = true
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                // Logout
                                Button {
                                    session.logout()
                                } label: {
                                    HStack(spacing: 16) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.body)
                                            .foregroundStyle(.red)
                                            .frame(width: 24)
                                        
                                        Text("Logout")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.red)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(20)
                        }
                        
                        // Footer
                        VStack(spacing: 8) {
                            Divider()
                            Text("Where is My Bus v2.2.0")
                                .font(.caption)
                                .foregroundStyle(theme.current.secondaryText)
                                .padding(.vertical, 16)
                        }
                    }
                    .frame(width: geometry.size.width * 0.85) // Wider drawer
                    .background(theme.current.background)
                    .transition(.move(edge: .leading))
                }
            }
        }
    }

    private func drawerRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(theme.current.secondaryText)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.current.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func go(_ route: AppRouter.AppPage) {
        withAnimation { isOpen = false }
        router.go(route)
    }
}

