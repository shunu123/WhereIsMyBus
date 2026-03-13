import SwiftUI

struct LoginView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var theme: ThemeManager
    
    // Core login fields
    @State private var regNoOrEmail = ""
    @State private var password = ""
    
    // Admin OTP Modal State
    @State private var requiresOTP = false
    @State private var adminEmailTarget = ""
    @State private var otpCode = ""
    @State private var isSendingOTP = false
    
    // Sheet State
    @State private var showRegistration = false
    @State private var showForgotPassword = false
    
    // UI State
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background with vibrant premium gradient
            LinearGradient(colors: [theme.current.accent, theme.current.accent.opacity(0.4), theme.current.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            // Subtle floating shapes for premium feel
            Circle()
                .fill(theme.current.accent.opacity(0.1))
                .frame(width: 400, height: 400)
                .offset(x: -200, y: -200)
                .blur(radius: 60)
            
            Circle()
                .fill(theme.current.accent.opacity(0.05))
                .frame(width: 300, height: 300)
                .offset(x: 200, y: 400)
                .blur(radius: 50)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Top Animation Area
                BusSearchAnimation()
                    .frame(height: 180)
                    .padding(.bottom, 20)
                
                // Form Container
                VStack(spacing: 30) {
                    // Logo or Title
                    VStack(spacing: 12) {
                        Text("Where Is My Bus?")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(theme.current.text)
                        
                        Text("Real-time Campus Transit")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.current.secondaryText)
                    }
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CREDENTIALS")
                                .font(.caption2.bold())
                                .foregroundStyle(theme.current.secondaryText)
                                .padding(.leading, 4)
                            
                            TextField("Register Number or Email", text: $regNoOrEmail)
                                .customTextField()
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            
                            SecureField("Password", text: $password)
                                .customTextField()
                        }
                        
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.caption.bold())
                            .foregroundStyle(theme.current.accent)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Login Button
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        } else {
                            Text("SIGN IN")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                        }
                    }
                    .background(theme.current.accent)
                    .cornerRadius(16)
                    .shadow(color: theme.current.accent.opacity(0.3), radius: 10, y: 5)
                    .padding(.horizontal, 32)
                    .disabled(isLoading || requiresOTP)
                    
                    // Register Button
                    Button {
                        // Clear credentials as requested before navigating
                        regNoOrEmail = ""
                        password = ""
                        router.go(.registration)
                    } label: {
                        HStack(spacing: 4) {
                            Text("New here?")
                                .foregroundStyle(theme.current.secondaryText)
                            Text("Create Account")
                                .foregroundStyle(theme.current.accent)
                        }
                        .font(.subheadline.bold())
                    }
                    .padding(.top, 10)
                    .disabled(requiresOTP)
                }
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(theme.current.card)
                        .background(.ultraThinMaterial)
                )
                .cornerRadius(32)
                .padding(.horizontal, 24)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                
                Spacer()
            }
            .blur(radius: requiresOTP ? 8 : 0) // Blur the main view so UI elements do not bleed through!
            .animation(.easeInOut, value: requiresOTP)
            
            // Hidden Admin OTP Overlay
            if requiresOTP {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { requiresOTP = false }
                    .zIndex(1)
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Admin Verification")
                            .font(.title3.bold())
                            .foregroundStyle(theme.current.text)
                        
                        Text("We sent a verification code to\n\(adminEmailTarget)")
                            .font(.subheadline)
                            .foregroundStyle(theme.current.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(spacing: 16) {
                        TextField("Enter OTP Code", text: $otpCode)
                            .keyboardType(.numberPad)
                            .padding(14)
                            .background(theme.current.background)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.current.border, lineWidth: 1))
                        
                        Button {
                            Task { await verifyAdminOTP(otpCode.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        } label: {
                            if isSendingOTP {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Verify & Continue")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                        }
                        .background(theme.current.accent)
                        .cornerRadius(10)
                        .disabled(isSendingOTP)
                        
                        Button {
                            Task { await resendAdminOTP() }
                        } label: {
                            Text("Resend OTP")
                                .font(.caption.bold())
                                .foregroundStyle(theme.current.secondaryText)
                        }
                        .padding(.top, 4)
                        
                        Button("Cancel") {
                            requiresOTP = false
                        }
                        .font(.body.weight(.medium))
                        .foregroundStyle(theme.current.accent)
                    }
                }
                .padding(24)
                .background(Color(UIColor.systemBackground)) // Solid opaque background
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 15)
                .padding(.horizontal, 32)
                .zIndex(2)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Login Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showRegistration) {
            RegistrationView()
                .environmentObject(router)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(theme)
        }
    }
    
    private func login() async {
        guard !regNoOrEmail.isEmpty, !password.isEmpty else {
            alertMessage = "Please enter both Register Number (or Email) and Password."
            showingAlert = true
            return
        }
        
        isLoading = true
        do {
            let response = try await APIService.shared.login(regNoOrEmail: regNoOrEmail, password: ["password": password])
            
            if response.requiresOTP == true, let target = response.target {
                // Secret Admin route engaged
                _ = try await APIService.shared.sendOTP(target: target, isAdmin: true)
                self.adminEmailTarget = target
                self.requiresOTP = true
            } else if let user = response.user {
                // Standard Student route engaged
                SessionManager.shared.login(user: user)
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        isLoading = false
    }
    
    private func verifyAdminOTP(_ code: String) async {
        guard !code.isEmpty else { return }
        isSendingOTP = true
        do {
            if let adminUser = try await APIService.shared.verifyOTP(target: adminEmailTarget, otp: code, isAdmin: true) {
                // Successfully verified via email logic
                requiresOTP = false
                SessionManager.shared.login(user: adminUser)
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        isSendingOTP = false
    }

    private func resendAdminOTP() async {
        isSendingOTP = true
        do {
            let result = try await APIService.shared.sendOTP(target: adminEmailTarget, isAdmin: true)
            if result.ok {
                alertMessage = "New verification code sent to \(adminEmailTarget)"
                showingAlert = true
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        isSendingOTP = false
    }
}

// Custom TextField Style modifier for consistency
struct CustomTextFieldStyle: ViewModifier {
    @EnvironmentObject var theme: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(theme.current.card)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.current.border, lineWidth: 1)
            )
            .foregroundStyle(theme.current.text)
    }
}

extension View {
    func customTextField() -> some View {
        modifier(CustomTextFieldStyle())
    }
}

struct RoundedBorderTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(UIColor.systemGray6)) 
            .cornerRadius(10)
    }
}

struct BusSearchAnimation: View {
    @State private var busOffset: CGFloat = -150
    @State private var showMarker1 = false
    @State private var showMarker2 = false
    @State private var showMarker3 = false
    
    var body: some View {
        ZStack {
            // Path Line
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 300, height: 4)
            
            // Markers
            HStack(spacing: 80) {
                MarkerPopup(icon: "mappin.and.ellipse", isVisible: showMarker1)
                MarkerPopup(icon: "bus.fill", isVisible: showMarker2)
                MarkerPopup(icon: "flag.checkered", isVisible: showMarker3)
            }
            
            // Moving Bus
            Image(systemName: "bus")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .offset(x: busOffset)
                .onAppear {
                    withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 5).repeatForever(autoreverses: false)) {
                        busOffset = 150
                    }
                    
                    // Staggered marker appearances with smoother timing
                    Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                        showMarker1 = false; showMarker2 = false; showMarker3 = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation(.easeOut(duration: 0.6)) { showMarker1 = true } }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation(.easeOut(duration: 0.6)) { showMarker2 = true } }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { withAnimation(.easeOut(duration: 0.6)) { showMarker3 = true } }
                    }.fire()
                }
        }
    }
}

struct MarkerPopup: View {
    let icon: String
    let isVisible: Bool
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(6)
                .background(Circle().fill(theme.current.accent))
                .scaleEffect(isVisible ? 1 : 0)
                .opacity(isVisible ? 1 : 0)
            
            RoundedRectangle(cornerRadius: 1)
                .fill(theme.current.accent)
                .frame(width: 2, height: 10)
                .scaleEffect(y: isVisible ? 1 : 0)
        }
        .offset(y: -25)
    }
}
