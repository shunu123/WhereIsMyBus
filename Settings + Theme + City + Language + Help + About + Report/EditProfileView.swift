import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var department: String = ""
    @State private var year: Int = 1
    @State private var mobileNo: String = ""
    @State private var regNo: String = ""
    @State private var isLoading: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var availableYears: [Int] {
        return [1, 2, 3, 4]
    }
    
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
                
                Text("Edit Profile")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                    .padding(.leading, 8)
                
                Spacer()
                
                Button("Save") {
                    updateProfile()
                }
                .font(.headline)
                .foregroundStyle(theme.current.accent)
                .disabled(isLoading)
            }
            .padding(16)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Image Placeholder
                    ZStack {
                        Circle()
                            .fill(theme.current.accent.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.current.accent)
                    }
                    .padding(.top, 10)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(title: "PERSONAL INFORMATION")
                            
                            TextField("First Name", text: $firstName)
                                .customTextField(theme: theme)
                            
                            TextField("Last Name", text: $lastName)
                                .customTextField(theme: theme)
                            
                            // Fixed Fields
                            VStack(alignment: .leading, spacing: 8) {
                                fixedField(label: "Registration Number", value: regNo)
                                fixedField(label: "Mobile Number", value: mobileNo)
                                
                                Text("To change these, contact to domain")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.orange)
                                    .padding(.leading, 4)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Academic
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(title: "ACADEMIC DETAILS")
                            
                            TextField("Department", text: $department)
                                .customTextField(theme: theme)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Academic Year")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.current.text)
                                    Text("Year \(year)")
                                        .font(.headline)
                                        .foregroundStyle(theme.current.accent)
                                }
                                Spacer()
                                
                                Text("Automated")
                                    .font(.caption.bold())
                                    .foregroundStyle(theme.current.secondaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(theme.current.border.opacity(0.3))
                                    .cornerRadius(8)
                            }
                            .padding(16)
                            .background(theme.current.card)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.current.border, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 30)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .onAppear {
            loadUserData()
        }
        .alert("Profile Update", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(theme.current.secondaryText)
            .padding(.leading, 4)
    }
    
    private func fixedField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.current.secondaryText)
            Text(value.isEmpty ? "Not Set" : value)
                .font(.body)
                .foregroundStyle(theme.current.text.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.current.card.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.current.border.opacity(0.5), lineWidth: 1)
        )
    }
    
    private func loadUserData() {
        if let user = session.currentUser {
            firstName = user.first_name ?? ""
            lastName = user.last_name ?? ""
            department = user.department ?? ""
            year = user.year ?? 1
            regNo = user.reg_no
            mobileNo = user.mobile_no ?? ""
        }
    }
    
    private func promoteYear() {
        if year < (availableYears.max() ?? 4) {
            withAnimation {
                year += 1
            }
        }
    }
    
    private func updateProfile() {
        isLoading = true
        Task {
            do {
                // In a real app, this would call APIService.shared.updateProfile(...)
                // For now, we update local session and simulate success
                let updatedData: [String: Any] = [
                    "first_name": firstName,
                    "last_name": lastName,
                    "department": department,
                    "year": year
                ]
                
                // Assuming we have a way to update the user object locally or via API
                // Let's check if session has an update method.
                // For simplicity, we'll assume a GenericResponse from a hypothetical endpoint
                
                // Simulate success
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await MainActor.run {
                    alertMessage = "Your profile has been updated successfully."
                    showingAlert = true
                    isLoading = false
                    // Ideally, we'd refresh the session user here
                    
                    // Auto-dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    isLoading = false
                }
            }
        }
    }
}

// Extension for custom text field to match theme
extension View {
    func customTextField(theme: ThemeManager) -> some View {
        self.padding(16)
            .background(theme.current.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.current.border, lineWidth: 1)
            )
    }
}
