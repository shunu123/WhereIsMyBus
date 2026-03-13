import SwiftUI
import MapKit

// MARK: - AdminHistoryView
/// Admin-only screen: select a past date, see timeline of all trips that day,
/// tap a trip to open the historical map with its GPS breadcrumb polyline.
struct AdminHistoryView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter

    // Calendar & selection state
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var activeDates: Set<String> = []
    @State private var isLoadingDates = false

    // Trip list for selected date
    @State private var trips: [AdminHistoryTrip] = []
    @State private var isLoadingTrips = false
    @State private var errorMessage: String? = nil

    // Detail sheet
    @State private var selectedTrip: AdminHistoryTrip? = nil
    @State private var showingMap = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ZStack(alignment: .top) {
            theme.current.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    LinearGradient(colors: theme.current.primaryGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: 8) {
                        HStack {
                            Button { router.back() } label: {
                                Image(systemName: "arrow.left")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text("Trip History")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Spacer()
                            Button { fetchTripsForSelected() } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 56)

                        // Date subtitle
                        Text(selectedDate, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, 12)
                    }
                }
                .frame(height: 130)

                // Calendar — past dates only
                VStack(spacing: 0) {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(theme.current.accent)
                    .padding(.horizontal, 12)
                    .onChange(of: selectedDate) { _, _ in fetchTripsForSelected() }
                }
                .background(theme.current.card)

                Divider()

                // Trips list
                if isLoadingTrips {
                    VStack { Spacer(); ProgressView("Loading trips…"); Spacer() }
                } else if let err = errorMessage {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(theme.current.secondaryText)
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(theme.current.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Retry") { fetchTripsForSelected() }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                } else if trips.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "tram.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(theme.current.accent.opacity(0.3))
                        Text("No recorded trips for this date.")
                            .font(.headline)
                            .foregroundStyle(theme.current.secondaryText)
                            .padding(.top, 12)
                        Spacer()
                    }
                } else {
                    List(trips) { trip in
                        Button {
                            selectedTrip = trip
                            showingMap = true
                        } label: {
                            HStack(spacing: 14) {
                                // Route Color Dot (hash-based)
                                Circle()
                                    .fill(routeColor(for: trip.route_name))
                                    .frame(width: 14, height: 14)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.bus_number)
                                        .font(.headline)
                                        .foregroundStyle(theme.current.text)
                                    Text(trip.route_name)
                                        .font(.caption)
                                        .foregroundStyle(theme.current.secondaryText)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(trip.points.count) pts")
                                        .font(.caption2.bold())
                                        .foregroundStyle(theme.current.secondaryText)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(theme.current.secondaryText)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(theme.current.card)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { fetchActiveDates(); fetchTripsForSelected() }
        .sheet(isPresented: $showingMap) {
            if let trip = selectedTrip {
                AdminHistoryMapSheet(trip: trip, date: dateFormatter.string(from: selectedDate))
                    .environmentObject(theme)
            }
        }
    }

    // MARK: - Logic
    private func fetchActiveDates() {
        isLoadingDates = true
        Task {
            do {
                let dates = try await APIService.shared.fetchAdminHistoryDates()
                await MainActor.run {
                    activeDates = Set(dates)
                    isLoadingDates = false
                }
            } catch {
                await MainActor.run { isLoadingDates = false }
            }
        }
    }

    private func fetchTripsForSelected() {
        let dateStr = dateFormatter.string(from: selectedDate)
        isLoadingTrips = true
        errorMessage = nil
        Task {
            do {
                let fetched = try await APIService.shared.fetchAdminHistoryMap(date: dateStr)
                await MainActor.run {
                    trips = fetched
                    isLoadingTrips = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not load trips: \(error.localizedDescription)"
                    isLoadingTrips = false
                }
            }
        }
    }

    private func routeColor(for name: String) -> Color {
        let palette: [Color] = [.blue, .orange, .green, .purple, .red, .teal, .pink, .yellow, .indigo, .cyan]
        let hash = abs(name.hashValue) % palette.count
        return palette[hash]
    }
}


// MARK: - AdminHistoryMapSheet
/// Displays the historical GPS polyline for a single trip on the map.
struct AdminHistoryMapSheet: View {
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss

    let trip: AdminHistoryTrip
    let date: String

    @State private var timeline: [AdminHistoryStop] = []
    @State private var position: MapCameraPosition = .automatic
    @State private var showTimeline = true

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map
            Map(position: $position) {
                // Traveled polyline
                if !trip.points.isEmpty {
                    MapPolyline(coordinates: trip.points.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                    })
                    .stroke(routeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }

                // Stop markers from timeline
                ForEach(timeline) { stop in
                    Annotation(stop.stop_name, coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng)) {
                        VStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text(stop.stop_name)
                                    .font(.system(size: 9, weight: .bold))
                                    .lineLimit(1)
                                if let actual = stop.actual_arrival {
                                    Text(String(actual.suffix(8)))
                                        .font(.system(size: 8))
                                        .foregroundStyle(stop.delay_mins != nil ? .red : .green)
                                }
                            }
                            .padding(4)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                            .shadow(radius: 2)

                            Image(systemName: "mappin.fill")
                                .foregroundStyle(routeColor)
                                .font(.system(size: 14))
                        }
                    }
                }
            }
            .ignoresSafeArea()

            // Top controls (Refresh + Dismiss — no overlap)
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    Spacer()
                    Button {
                        withAnimation { position = .automatic }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3.bold())
                            .foregroundStyle(theme.current.accent)
                            .padding(10)
                            .background(Circle().fill(Color.white).shadow(radius: 2))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                Spacer()
            }

            // Bottom: Mini Timeline card — toggle-able
            VStack(spacing: 0) {
                // Handle + toggle
                Button {
                    withAnimation { showTimeline.toggle() }
                } label: {
                    HStack {
                        Text(trip.route_name)
                            .font(.headline.bold())
                            .foregroundStyle(theme.current.text)
                        Spacer()
                        Image(systemName: showTimeline ? "chevron.down" : "chevron.up")
                            .foregroundStyle(theme.current.secondaryText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .background(theme.current.card)

                if showTimeline {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(timeline.enumerated()), id: \.element.id) { idx, stop in
                                HStack(alignment: .top, spacing: 12) {
                                    // Color dot + line
                                    VStack(spacing: 0) {
                                        if idx > 0 {
                                            Rectangle()
                                                .fill(routeColor.opacity(0.4))
                                                .frame(width: 2, height: 10)
                                        }
                                        Circle()
                                            .fill(stop.actual_arrival != nil ? routeColor : Color.gray.opacity(0.3))
                                            .frame(width: 10, height: 10)
                                        if idx < timeline.count - 1 {
                                            Rectangle()
                                                .fill(routeColor.opacity(0.4))
                                                .frame(width: 2)
                                                .frame(maxHeight: .infinity)
                                        }
                                    }
                                    .frame(width: 14)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stop.stop_name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(theme.current.text)
                                        HStack(spacing: 6) {
                                            if let actual = stop.actual_arrival {
                                                Text("Arrived: \(String(actual.suffix(8)))")
                                                    .font(.caption)
                                                    .foregroundStyle(.green)
                                            }
                                            if let delay = stop.delay_mins {
                                                Text("(+\(delay) min late)")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.red)
                                            } else if stop.actual_arrival == nil {
                                                Text("Not reached")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 240)
                    .background(theme.current.background)
                }
            }
            .background(theme.current.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.1), radius: 20, y: -5)
        }
        .onAppear { fetchTimeline() }
    }

    private var routeColor: Color {
        let palette: [Color] = [.blue, .orange, .green, .purple, .red, .teal, .pink, .yellow, .indigo, .cyan]
        let hash = abs(trip.route_name.hashValue) % palette.count
        return palette[hash]
    }

    private func fetchTimeline() {
        Task {
            do {
                let stops = try await APIService.shared.fetchAdminHistoryTimeline(date: date, tripId: trip.trip_id)
                await MainActor.run { timeline = stops }
            } catch {
                print("AdminHistoryMapSheet: failed to fetch timeline: \(error)")
            }
        }
    }
}
