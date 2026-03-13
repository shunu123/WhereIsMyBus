import SwiftUI

struct StudentRosterView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    
    @State private var students: [StudentRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var searchText = ""

    var filteredStudents: [StudentRecord] {
        if searchText.isEmpty {
            return students
        } else {
            return students.filter { student in
                let nameMatches = student.displayName.localizedCaseInsensitiveContains(searchText)
                let regMatches = student.reg_no.localizedCaseInsensitiveContains(searchText)
                let deptMatches = (student.department ?? "").localizedCaseInsensitiveContains(searchText)
                return nameMatches || regMatches || deptMatches
            }
        }
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
                
                Text("Student Data")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                    .padding(.leading, 8)
                
                Spacer()
                
                Text("\(filteredStudents.count)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.current.accent)
                    .cornerRadius(12)
            }
            .padding(16)
            .background(theme.current.background)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.current.secondaryText)
                TextField("Search name, reg no, department...", text: $searchText)
                    .font(.body)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.current.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(theme.current.card)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Content
            Group {
                if isLoading {
                    Spacer()
                    ProgressView("Loading students...")
                    Spacer()
                } else if let err = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.current.secondaryText)
                        Button("Retry") {
                            Task { await loadData() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.current.accent)
                    }
                    .padding()
                    Spacer()
                } else if filteredStudents.isEmpty {
                    Spacer()
                    Text("No students found.")
                        .font(.headline)
                        .foregroundStyle(theme.current.secondaryText)
                    Spacer()
                } else {
                    List {
                        ForEach(filteredStudents) { student in
                            StudentRow(student: student)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadData()
                    }
                }
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if SessionManager.shared.userRole != "admin" {
                router.go(.home) // Security fail-safe
            } else {
                Task { await loadData() }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            students = try await APIService.shared.fetchStudents()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct StudentRow: View {
    let student: StudentRecord
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.displayName)
                        .font(.headline)
                        .foregroundStyle(theme.current.text)
                    Text(student.reg_no)
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.current.accent)
                }
                Spacer()
                if let year = student.year {
                    Text("Year \(year)")
                        .font(.caption.bold())
                        .foregroundStyle(theme.current.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.current.border.opacity(0.3))
                        .cornerRadius(6)
                }
            }
            
            Divider()
            
            HStack {
                if let dept = student.department {
                    Text(dept)
                        .font(.subheadline)
                        .foregroundStyle(theme.current.secondaryText)
                }
                Spacer()
                if let mobile = student.mobile_no {
                    Text(mobile)
                        .font(.caption)
                        .foregroundStyle(theme.current.secondaryText)
                }
            }
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
