import SwiftUI

struct ReportIssueView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) var dismiss
    
    @State private var issueType = "Bug / Crash"
    @State private var description: String = ""
    @State private var email: String = ""
    
    let issueTypes = ["Bus Delay", "Wrong Stop Location", "Bus Condition", "Driver Feedback", "App Fault", "Other"]

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
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.current.text)
                        
                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Please describe the issue in detail...")
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
                        Text("Email (Optional)")
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
                        // Submit action
                    } label: {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Submit Report")
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .leading, endPoint: .trailing))
                        )
                    }
                }
                .padding(16)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

