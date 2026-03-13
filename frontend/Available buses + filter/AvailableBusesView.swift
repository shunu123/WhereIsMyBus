import SwiftUI
import CoreLocation
import MapKit



struct AvailableBusesView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter

    let origin: String
    let destination: String
    let fromID: String?
    let toID: String?
    let fromCoord: CLLocationCoordinate2D?
    let toCoord: CLLocationCoordinate2D?
    let via: String?


    @StateObject private var vm = AvailableBusesViewModel()
    @State private var showFilter = false

    var body: some View {
        ZStack(alignment: .top) {
            theme.current.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { router.back() } label: {
                        Image(systemName: "arrow.left")
                            .font(.title2.bold())
                            .foregroundStyle(theme.current.text)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(origin)  →  \(destination)")

                            .font(.headline.bold())
                            .foregroundStyle(theme.current.text)
                        if let via {
                            Text("via \(via)")
                                .font(.caption)
                                .foregroundStyle(theme.current.secondaryText)
                        }
                    }

                    Spacer()

                    Button { showFilter = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(theme.current.accent)
                            .padding(8)
                            .background(Circle().fill(theme.current.card))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.current.card)
                
                // Route Map and Info Card
                VStack(spacing: 0) {
                    routeMapView
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    
                    if vm.estimatedDistance != nil {
                        estimationCard
                            .padding(.horizontal, 16)
                            .padding(.top, -30) // Overlap map slightly
                            .zIndex(10)
                    }
                }
                .padding(.bottom, 12)


                if vm.visibleBuses.isEmpty {
                    if let error = vm.errorText {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "bus.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(theme.current.accent.opacity(0.3))
                            Text(error)
                                .font(.headline)
                                .foregroundStyle(theme.current.secondaryText)
                            Spacer()
                        }
                    } else {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Searching for buses...")
                                .font(.subheadline)
                                .foregroundStyle(theme.current.secondaryText)
                                .padding(.top, 16)
                            Spacer()
                        }
                    }
                } else {
                    TimelineScheduleView(
                        buses: vm.visibleBuses,
                        from: origin,
                        to: destination,
                        onSelectBus: { bus in
                            router.go(.busSchedule(
                                busID: bus.id.uuidString, 
                                searchPoint: origin, 
                                destinationStop: destination,
                                sourceLat: fromCoord?.latitude,
                                sourceLon: fromCoord?.longitude,
                                destLat: toCoord?.latitude,
                                destLon: toCoord?.longitude
                            ))
                        },
                        onLoadMore: {
                            vm.loadMore()
                        }
                    )
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { vm.load(from: origin, to: destination, fromID: fromID, toID: toID, fromCoord: fromCoord, toCoord: toCoord, via: via) }

        .sheet(isPresented: $showFilter) {
            FilterSheetView(
                showOnTime: $vm.showOnTime,
                showDelayed: $vm.showDelayed,
                sortOption: $vm.sortOption
            ) {
                vm.applyFilterState(from: origin, to: destination, fromID: fromID, toID: toID, via: via)

                showFilter = false
            }
            .environmentObject(theme)
        }
    }

    private var routeMapView: some View {
        Map {
            if !vm.routePolyline.isEmpty {
                MapPolyline(coordinates: vm.routePolyline)
                    .stroke(theme.current.accent, lineWidth: 4)
            }
            
            // Markers for Start and End
            if let start = vm.routePolyline.first {
                Annotation("Start", coordinate: start) {
                    Circle().fill(theme.current.accent).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if let end = vm.routePolyline.last {
                Annotation("End", coordinate: end) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .background(Circle().fill(.white))
                }
            }
            
            // Live Buses on Route
            ForEach(vm.liveBusesOnRoute) { bus in
                if let lastCoord = bus.actualPolyline.last {
                    Annotation(bus.number, coordinate: lastCoord.cl) {
                        Image(systemName: "bus.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(theme.current.accent))
                            .shadow(radius: 2)
                            .onTapGesture {
                                router.go(.busSchedule(
                                    busID: bus.id.uuidString,
                                    searchPoint: origin,
                                    destinationStop: destination,
                                    sourceLat: fromCoord?.latitude,
                                    sourceLon: fromCoord?.longitude,
                                    destLat: toCoord?.latitude,
                                    destLon: toCoord?.longitude
                                ))
                            }
                    }
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted))
    }

    private var estimationCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ESTIMATED DISTANCE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.current.secondaryText)
                Text(vm.estimatedDistance ?? "--")
                    .font(.headline.bold())
                    .foregroundStyle(theme.current.accent)
            }
            
            Divider().frame(height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ESTIMATED TIME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.current.secondaryText)
                Text(vm.estimatedTime ?? "--")
                    .font(.headline.bold())
                    .foregroundStyle(theme.current.accent)
            }
            
            Spacer()
            
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.title2)
                .foregroundStyle(theme.current.accent)
        }
        .padding(16)
        .background(theme.current.card)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.current.border, lineWidth: 1)
        )
    }
}
