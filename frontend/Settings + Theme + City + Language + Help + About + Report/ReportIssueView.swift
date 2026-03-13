import SwiftUI

struct ReportIssueView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var issueType = "General Inquiry"
    @State private var description: String = ""
    @State private var email: String = ""
    @State private var busNumber: String = ""
    @State private var driverInfo: String = ""
    
    let issueTypes = [
        "Bus Delay",
        "Route Diversion",
        "Driver Behavior",
        "Bus Condition",
        "Wrong Stop Location",
        "App Fault / Bug",
        "General Inquiry",
        "Other"
    ]

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
                
                Text("Report Issue")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Issue Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Issue Type")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.current.text)
                        
                        Menu {
                            ForEach(issueTypes, id: \.self) { type in
                                Button(type) {
                                    issueType = type
                                }
                            }
                        } label: {
                            HStack {
                                Text(issueType)
                                    .foregroundStyle(theme.current.text)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(theme.current.secondaryText)
                            }
                            .padding(16)
                            .background(theme.current.card)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.current.border, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Conditional Fields for Bus/Driver
                    if issueType == "Bus Delay" || issueType == "Driver Behavior" || issueType == "Route Diversion" {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bus Number (Optional)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.current.text)
                                
                                TextField("e.g. 505 / 241", text: $busNumber)
                                    .padding(16)
                                    .background(theme.current.card)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(theme.current.border, lineWidth: 1)
                                    )
                            }
                            
                            if issueType == "Driver Behavior" {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Driver Name / Description (Optional)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.current.text)
                                    
                                    TextField("e.g. Name or appearance", text: $driverInfo)
                                        .padding(16)
                                        .background(theme.current.card)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(theme.current.border, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.current.text)
                        
                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Please provide as much detail as possible...")
                                    .foregroundStyle(Color.gray.opacity(0.5))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            }
                            
                            TextEditor(text: $description)
                                .frame(height: 160)
                                .padding(12)
                                .scrollContentBackground(.hidden)
                                .background(theme.current.card)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.current.border, lineWidth: 1)
                                )
                        }
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact Email")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.current.text)
                        
                        TextField("your@email.com", text: $email)
                            .padding(16)
                            .background(theme.current.card)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(theme.current.border, lineWidth: 1)
                            )
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    // Submit Button
                    Button {
                        submitReport()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Submit Report")
                            }
                        }
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing))
                    )
                    .disabled(description.isEmpty || isSubmitting)
                    .opacity(description.isEmpty || isSubmitting ? 0.6 : 1.0)
                }
                .padding(16)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if let user = session.currentUser {
                email = user.email ?? ""
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") { 
                if alertTitle == "Success" {
                    router.back()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    func submitReport() {
        isSubmitting = true
        Task {
            do {
                // Combine details for the backend call
                var finalMessage = description
                if !busNumber.isEmpty {
                    finalMessage += "\n\nBus Number: \(busNumber)"
                }
                if !driverInfo.isEmpty {
                    finalMessage += "\nDriver Info: \(driverInfo)"
                }
                
                try await APIService.shared.postReport(
                    email: email.isEmpty ? nil : email,
                    subject: "[\(issueType)] User Feedback",
                    message: finalMessage,
                    category: "Support"
                )
                alertTitle = "Success"
                alertMessage = "Your report has been submitted successfully."
                showAlert = true
            } catch {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isSubmitting = false
        }
    }
}

