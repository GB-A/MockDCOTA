import SwiftUI

struct DashboardView: View {
    @State private var vm: DashboardViewModel

    init(service: DCOTAService) { _vm = State(initialValue: DashboardViewModel(service: service)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let message = vm.errorMessage {
                        ErrorBanner(message: message) { Task { await vm.load() } }
                    }
                    if vm.isLoading && vm.summary == nil {
                        LoadingView().padding(.top, 60)
                    } else if let s = vm.summary {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            tile("Total devices", s.totalDevices.grouped, .primary, AID.Dashboard.totalDevices)
                            tile("Online", s.online.grouped, .green, AID.Dashboard.online)
                            tile("Offline", s.offline.grouped, .gray, AID.Dashboard.offline)
                            tile("Updating", s.updating.grouped, .blue, AID.Dashboard.updating)
                            tile("Failed", s.failed.grouped, .red, AID.Dashboard.failed)
                            tile("Active deployments", s.activeDeployments.grouped, .orange, AID.Dashboard.activeDeployments)
                        }
                        .padding(.horizontal)
                        Text("\(s.onlinePercentage, specifier: "%.1f")% of the fleet is online")
                            .font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier(AID.Dashboard.onlinePercentage)
                    }
                }
                .padding(.vertical)
            }
            .scrollIndicators(.visible)
            .navigationTitle("Fleet")
            .refreshable { await vm.load() }
            .accessibilityIdentifier(AID.Dashboard.screen)
        }
        .task { await vm.load() }
    }

    private func tile(_ title: String, _ value: String, _ color: Color, _ id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
