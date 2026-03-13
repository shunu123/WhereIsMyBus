import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    // Form fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var year = 1
    @State private var email = ""
    @State private var otp = ""
    @State private var collegeName = ""
    @State private var department = ""
    @State private var regNo = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var location = ""
    @State private var stop = ""
    
    @State private var otpStep = false
    @State private var isOTPVerified = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var availableYears: [Int] {
        return [1, 2, 3, 4]
    }
    
    var body: some View {
        ZStack {
            // Premium background
            LinearGradient(colors: theme.current.primaryGradient.map { $0.opacity(0.05) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom))
                            .padding(.bottom, 10)
                        
                        Text("Student Registration")
                            .font(.title.bold())
                            .foregroundStyle(theme.current.text)
                        Text("Enter your details to create an account")
                            .font(.subheadline)
                            .foregroundStyle(theme.current.secondaryText)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 10)
                    
                    VStack(spacing: 20) {
                        // Wrapped in a premium card
                        VStack(spacing: 20) {
                            // --- Personal Section ---
                            sectionHeader(title: "Personal Details")
                            
                            VStack(spacing: 12) {
                                TextField("First Name", text: $firstName)
                                    .customTextField()
                                TextField("Last Name", text: $lastName)
                                    .customTextField()
                                
                                HStack {
                                    Text("Current Year")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.current.secondaryText)
                                    Spacer()
                                    Picker("Year", selection: $year) {
                                        ForEach(availableYears, id: \.self) { y in
                                            Text("\(y)").tag(y)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 180)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .background(theme.current.card.opacity(0.3))
                                .cornerRadius(12)
                            }
                            
                            // --- Account/Verification Section ---
                            sectionHeader(title: "Account Verification")
                            
                            VStack(spacing: 12) {
                                HStack {
                                    TextField("Email Address", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .customTextField()
                                        .disabled(isOTPVerified)
                                    
                                    if isOTPVerified {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.title3)
                                            .padding(.trailing, 8)
                                    }
                                }
                                
                                if !otpStep && !isOTPVerified {
                                    Button {
                                        sendOTP()
                                    } label: {
                                        Text("Verify Email (Send OTP)")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(theme.current.accent)
                                    }
                                    .padding(.top, -5)
                                } else if otpStep && !isOTPVerified {
                                    HStack {
                                        TextField("Enter 4-digit OTP", text: $otp)
                                            .keyboardType(.numberPad)
                                            .customTextField()
                                        
                                        Button {
                                            Task { await verifyOTP(otp.trimmingCharacters(in: .whitespacesAndNewlines)) }
                                        } label: {
                                            if isLoading {
                                                ProgressView().tint(theme.current.accent)
                                            } else {
                                                Text("Verify")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(theme.current.accent)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .disabled(otp.count < 4)
                                    }
                                    
                                    Button {
                                        sendOTP()
                                    } label: {
                                        Text("Resend OTP")
                                            .font(.caption.bold())
                                            .foregroundStyle(theme.current.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 4)
                                    .padding(.top, -4)
                                }
                            }
                            
                            // --- Academic Section ---
                            sectionHeader(title: "Academic Information")
                            
                            VStack(spacing: 12) {
                                TextField("Registration Number (User ID)", text: $regNo)
                                    .textInputAutocapitalization(.characters)
                                    .customTextField()
                                
                                TextField("College Name", text: $collegeName)
                                    .customTextField()
                                    .padding(.vertical, 8)
                                
                                TextField("Department", text: $department)
                                    .customTextField()
                                
                                SecureField("Password", text: $password)
                                    .customTextField()
                                
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .customTextField()
                            }
                            
                            // --- Commute Section ---
                            sectionHeader(title: "Commute Details")
                            
                            VStack(spacing: 12) {
                                TextField("Location", text: $location)
                                    .customTextField()
                                
                                TextField("Pickup Stop", text: $stop)
                                    .customTextField()
                            }
                        }
                        .padding(20)
                        .background(theme.current.card)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(theme.current.border, lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal)
                    
                    Button {
                        Task { await register() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Register Now")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(theme.current.accent)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(isLoading)
                }
            }
        }
        .background(theme.current.background)
        .navigationTitle("Registration")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Registration"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"), action: {
                    if alertMessage.contains("Registration successful") {
                        dismiss()
                    }
                })
            )
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(theme.current.accent)
                .padding(.leading, 4)
            Spacer()
        }
        .padding(.top, 10)
    }
    
    private func sendOTP() {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard predicate.evaluate(with: email) else {
            alertMessage = "Please enter a valid email address."
            showingAlert = true
            return
        }
        
        isLoading = true
        Task {
            do {
                let result = try await APIService.shared.sendOTP(target: email, isAdmin: false, isRegistration: true)
                await MainActor.run {
                        self.isLoading = false
                        if result.ok {
                            otpStep = true
                            alertMessage = "OTP sent successfully! Please check your email inbox."
                            showingAlert = true
                        } else {
                            alertMessage = "Failed to send OTP. Please try again."
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
    
    private func verifyOTP(_ code: String) async {
        isLoading = true
        do {
            _ = try await APIService.shared.verifyOTP(target: email, otp: code, isAdmin: false)
            await MainActor.run {
                isOTPVerified = true
                otpStep = false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                alertMessage = "Invalid OTP. Please try again."
                showingAlert = true
            }
        }
    }
    
    private func validatePassword(_ pass: String) -> Bool {
        let regex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*[!@#$%^&*(),.?\":{}|<>]).{8,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: pass)
    }

    private func register() async {
        guard !regNo.isEmpty, !password.isEmpty, !firstName.isEmpty, isOTPVerified else {
            alertMessage = isOTPVerified ? "Please fill all required fields." : "Please verify your email with OTP"
            showingAlert = true
            return
        }
        
        if password != confirmPassword {
            alertMessage = "Passwords do not match."
            showingAlert = true
            return
        }
        
        if !validatePassword(password) {
            alertMessage = "Password must be 8+ characters with caps, small letters, and symbols."
            showingAlert = true
            return
        }
        
        isLoading = true
        
        do {
            let userData: [String: Any] = [
                "reg_no": regNo,
                "password": password,
                "first_name": firstName,
                "last_name": lastName,
                "year": year,
                "mobile_no": "",
                "email": email,
                "college_name": collegeName,
                "department": department,
                "degree": "N/A",
                "location": location,
                "stop": stop,
                "role": "student"
            ]
            
            let success = try await APIService.shared.register(userData: userData)
            if success {
                alertMessage = "Registration successful! Now you can login."
                showingAlert = true
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
    }
}
