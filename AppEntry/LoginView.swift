import SwiftUI

struct LoginView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var theme: ThemeManager
    
    @State private var regNo = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            theme.current.background
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo or Title
                VStack(spacing: 12) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(theme.current.accent)
                    
                    Text("College Bus Tracker")
                        .font(.largeTitle.bold())
                        .foregroundStyle(theme.current.text)
                    
                    Text("Sign in to continue")
                        .font(.subheadline)
                        .foregroundStyle(theme.current.secondaryText)
                }
                .padding(.top, 50)
                
                // Form Fields
                VStack(spacing: 20) {
                    TextField("Register Number", text: $regNo)
                        .textFieldStyle(RoundedBorderTextFieldStyle()) // Custom style below
                        .textInputAutocapitalization(.characters)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle()) // Custom style below
                    
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            // TODO: Implement Forgot Password
                        }
                        .font(.caption)
                        .foregroundStyle(theme.current.accent)
                    }
                }
                .padding(.horizontal, 30)
                
                // Login Button
                Button {
                    login()
                } label: {
                    Text("Login")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(theme.current.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Login Failed"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func login() {
        guard !regNo.isEmpty, !password.isEmpty else {
            alertMessage = "Please enter both Register Number and Password."
            showingAlert = true
            return
        }
        
        // Mock validation
        if password == "123456" {
            SessionManager.shared.login(regNo: regNo)
            // Router should automatically update based on session state observation in RootShellView
        } else {
            alertMessage = "Invalid credentials. Try '123456'."
            showingAlert = true
        }
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

// Helper for Preview or standard usage
struct RoundedBorderTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(UIColor.systemGray6)) // Fallback or use integration with Theme if possible in this context
            .cornerRadius(10)
    }
}
