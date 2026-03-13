import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var emailOrRegNo = ""
    @State private var resolvedTarget = ""
    @State private var otp = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var step: Step = .enterEmail
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    enum Step { case enterEmail, enterOTP, resetPassword, done }
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.current.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Icon
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundStyle(theme.current.accent)
                            .padding(.top, 30)
                        
                        // Title
                        VStack(spacing: 6) {
                            Text("Reset Password")
                                .font(.title.bold())
                                .foregroundStyle(theme.current.text)
                            Text(stepSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(theme.current.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Form
                        VStack(spacing: 16) {
                            switch step {
                            case .enterEmail:
                                TextField("Email or Register Number", text: $emailOrRegNo)
                                    .textInputAutocapitalization(.never)
                                    .customTextField()
                                
                            case .enterOTP:
                                VStack(spacing: 8) {
                                    TextField("Enter OTP from Email", text: $otp)
                                        .keyboardType(.numberPad)
                                        .customTextField()
                                    
                                    Button {
                                        resendOTP()
                                    } label: {
                                        Text("Resend OTP")
                                            .font(.caption.bold())
                                            .foregroundStyle(theme.current.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 4)
                                    .padding(.top, -4)
                                }
                                
                            case .resetPassword:
                                SecureField("New Password", text: $newPassword)
                                    .customTextField()
                                SecureField("Confirm New Password", text: $confirmPassword)
                                    .customTextField()
                                
                            case .done:
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal)
                        
                        if step != .done {
                            // Action Button
                            Button {
                                Task { await handleStep() }
                            } label: {
                                if isLoading {
                                    ProgressView().tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                } else {
                                    Text(actionButtonTitle)
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                }
                            }
                            .background(theme.current.accent)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .disabled(isLoading)
                        } else {
                            Button("Back to Login") {
                                dismiss()
                            }
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(theme.current.accent)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Password Reset"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private var stepSubtitle: String {
        switch step {
        case .enterEmail:  return "Enter your registered email or register number."
        case .enterOTP:    return "Enter the 4-digit code we sent to your email."
        case .resetPassword: return "Choose a strong new password."
        case .done:        return "Your password has been reset successfully!"
        }
    }
    
    private var actionButtonTitle: String {
        switch step {
        case .enterEmail:    return "Send OTP"
        case .enterOTP:      return "Verify Code"
        case .resetPassword: return "Reset Password"
        case .done:          return ""
        }
    }
    
    private func resendOTP() {
        isLoading = true
        Task {
            do {
                let targetToReset = resolvedTarget.isEmpty ? emailOrRegNo : resolvedTarget
                let result = try await APIService.shared.sendOTP(target: targetToReset, isAdmin: false, isRegistration: false)
                await MainActor.run {
                    isLoading = false
                    if result.ok {
                        alertMessage = "OTP resent successfully!"
                        showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleStep() async {
        isLoading = true
        
        switch step {
        case .enterEmail:
            guard !emailOrRegNo.isEmpty else {
                alertMessage = "Please enter your email or register number."
                showingAlert = true
                isLoading = false
                return
            }
            do {
                let result = try await APIService.shared.sendOTP(target: emailOrRegNo, isAdmin: false, isRegistration: false)
                if result.ok {
                    if let target = result.target {
                        self.resolvedTarget = target
                    }
                    step = .enterOTP
                } else {
                    alertMessage = "Failed to send OTP. Please try again."
                    showingAlert = true
                }
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            
        case .enterOTP:
            guard !otp.isEmpty else {
                alertMessage = "Please enter the OTP code."
                showingAlert = true
                isLoading = false
                return
            }
            do {
                let code = otp.trimmingCharacters(in: .whitespacesAndNewlines)
                let targetToVerify = resolvedTarget.isEmpty ? emailOrRegNo : resolvedTarget
                _ = try await APIService.shared.verifyOTP(target: targetToVerify, otp: code, isAdmin: false)
                step = .resetPassword
            } catch {
                alertMessage = "Invalid or expired code. Please try again."
                showingAlert = true
            }
            
        case .resetPassword:
            guard !newPassword.isEmpty, newPassword == confirmPassword else {
                alertMessage = newPassword.isEmpty ? "Password cannot be empty." : "Passwords do not match."
                showingAlert = true
                isLoading = false
                return
            }
            do {
                let targetToReset = resolvedTarget.isEmpty ? emailOrRegNo : resolvedTarget
                try await APIService.shared.resetPassword(email: targetToReset, newPassword: newPassword)
                step = .done
            } catch {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            
        case .done:
            break
        }
        
        isLoading = false
    }
}
