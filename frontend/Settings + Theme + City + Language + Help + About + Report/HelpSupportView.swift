import SwiftUI

struct HelpSupportView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) var dismiss
    
    @State private var expandedFAQ: String? = nil
    @State private var showingMailSuccess = false
    @State private var message: String = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let faqs = [
        (q: "How do I track my bus?", a: "Go to the Home screen, enter your starting and ending stops, or search by bus number directly. Once you find your bus, tap the 'TRACK' button to see its live location on the map."),
        (q: "Is the tracking real-time?", a: "Yes, our system updates the bus location every 1-5 seconds. You can see the bus moving smoothly along its route in real-time. If you notice a delay, please check your internet connection."),
        (q: "What should I do if a bus is diverted?", a: "Diverted routes are shown in red on the map. This happens due to traffic or construction. The system will automatically calculate the best path and keep you updated on the ETA."),
        (q: "How do I report a driver issue?", a: "Go to Settings -> Report Driver Behavior. You can provide the bus number and details of the incident. This report is sent directly to our administration for immediate action."),
        (q: "Can I set an arrival alarm?", a: "Yes! When tracking a bus, tap the 'Alarm' icon to set an alert for 1km, 2km, or 5km before your destination. The app will notify you even if it's in the background."),
        (q: "How do I change the app language or theme?", a: "Navigate to Settings. Under 'APP PREFERENCES', you can select 'Language' to switch between English and Tamil, or 'Theme' to toggle between Light, Dark, and Blue modes.")
    ]

    var body: some View {
        ZStack {
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
                    
                    Text("Help & Support")
                        .font(.title2.bold())
                        .foregroundStyle(theme.current.text)
                        .padding(.leading, 8)
                    
                    Spacer()
                }
                .padding(16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // FAQ List
                        VStack(spacing: 0) {
                            ForEach(faqs, id: \.q) { faq in
                                VStack(spacing: 0) {
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            expandedFAQ = expandedFAQ == faq.q ? nil : faq.q
                                        }
                                    } label: {
                                        HStack {
                                            Text(faq.q)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(theme.current.text)
                                                .multilineTextAlignment(.leading)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                                .foregroundStyle(theme.current.secondaryText)
                                                .rotationEffect(.degrees(expandedFAQ == faq.q ? 180 : 0))
                                        }
                                        .padding(16)
                                        .background(theme.current.card)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if expandedFAQ == faq.q {
                                        Text(faq.a)
                                            .font(.caption)
                                            .foregroundStyle(theme.current.secondaryText)
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 16)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(theme.current.card)
                                            .transition(.opacity)
                                    }
                                }
                                
                                if faq.q != faqs.last?.q {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(theme.current.card)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.current.border, lineWidth: 1)
                        )
                        
                        // Contact Support Card
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.white)
                            
                            Text("Still need help?")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("Our support team is here for you.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            TextField("How can we help you?", text: $message, axis: .vertical)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(8)
                                .foregroundStyle(.black)
                                .lineLimit(3...5)
                            
                            Button {
                                submitSupport()
                            } label: {
                                HStack {
                                    if isSubmitting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "envelope.fill")
                                        Text("Send Message")
                                    }
                                }
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.8, green: 0.3, blue: 0.1))
                                )
                            }
                            .disabled(message.isEmpty || isSubmitting)
                            .opacity(message.isEmpty || isSubmitting ? 0.7 : 1.0)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: theme.current.primaryGradient, startPoint: .top, endPoint: .bottom))
                        )
                    }
                    .padding(16)
                }
            }
            .background(theme.current.background.ignoresSafeArea())
            
            // Success Overlay
            if showingMailSuccess {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        Text("Message Sent!")
                            .font(.headline)
                        
                        Text("We'll get back to you soon.")
                            .font(.subheadline)
                            .foregroundStyle(theme.current.secondaryText)
                    }
                    .padding(30)
                    .background(theme.current.card)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("Status", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func submitSupport() {
        isSubmitting = true
        Task {
            do {
                try await APIService.shared.postContact(
                    email: SessionManager.shared.currentUser?.email,
                    subject: "General Support Request",
                    message: message
                )
                withAnimation { showingMailSuccess = true }
                message = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showingMailSuccess = false }
                }
            } catch {
                alertMessage = "Failed to send message: \(error.localizedDescription)"
                showAlert = true
            }
            isSubmitting = false
        }
    }
}

