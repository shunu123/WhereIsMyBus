import SwiftUI

struct AllRoutesView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var router: AppRouter
    @StateObject private var vm = AllRoutesViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                Button { router.back() } label: {
                    Image(systemName: "arrow.left")
                        .font(.title2.bold())
                        .foregroundStyle(theme.current.text)
                }

                Text("All Routes")
                    .font(.title2.bold())
                    .foregroundStyle(theme.current.text)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(theme.current.card)

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.current.secondaryText)
                TextField("Search routes...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(theme.current.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.current.border, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if vm.isLoading {
                Spacer()
                ProgressView()
                Text("Loading routes...")
                    .font(.caption)
                    .foregroundStyle(theme.current.secondaryText)
                    .padding(.top, 8)
                Spacer()
            } else if let error = vm.error {
                Spacer()
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
                Button("Retry") {
                    Task { await vm.loadRoutes() }
                }
                Spacer()
            } else if vm.filteredRoutes.isEmpty {
                Spacer()
                Image(systemName: "bus.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.current.secondaryText.opacity(0.2))
                Text("No routes found")
                    .font(.headline)
                    .foregroundStyle(theme.current.secondaryText)
                    .padding(.top, 12)
                Spacer()
            } else {
                List {
                    ForEach(vm.filteredRoutes) { route in
                        Button {
                            // Find the first bus associated with this route, or handle lack thereof
                            let buses = BusRepository.shared.allBuses.filter { $0.headsign == route.name || $0.number == route.name || $0.extRouteId == String(route.id) }
                            if let firstBus = buses.first {
                                router.go(.busSchedule(busID: firstBus.id.uuidString))
                            } else {
                                // Default fallback if no bus object maps nicely
                                router.go(.routeDetail(routeID: "\(route.id)"))

                            }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "map.fill")
                                    .foregroundStyle(theme.current.accent)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(route.name)
                                        .font(.headline)
                                        .foregroundStyle(theme.current.text)
                                    HStack(spacing: 8) {
                                        if let extId = route.ext_route_id {
                                            Text("ID: \(extId)")
                                                .font(.caption)
                                                .foregroundStyle(theme.current.secondaryText)
                                        }
                                        if route.isNightOwl {
                                            Text("24/7")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.indigo)
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(theme.current.secondaryText)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(theme.current.card)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }

                    if !vm.filteredRoutes.isEmpty {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                vm.loadMore()
                            }
                    }

                    if vm.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await vm.loadRoutes()
        }
    }
}
