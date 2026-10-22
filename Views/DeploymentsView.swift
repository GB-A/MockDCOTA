import SwiftUI

struct DeploymentsView: View {
    @State private var vm: DeploymentsViewModel
    @Environment(AppState.self) private var appState

    init(service: DCOTAService) { _vm = State(initialValue: DeploymentsViewModel(service: service)) }

    var body: some View {
        NavigationStack {
            List {
                if let message = vm.errorMessage {
                    ErrorBanner(message: message) { Task { await vm.load() } }
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                ForEach(vm.deployments) { dep in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(dep.packageName) v\(dep.packageVersion)").font(.headline)
                            Spacer()
                            StatusBadge(text: dep.status.label, color: dep.status.color)
                                .accessibilityIdentifier(AID.Deployments.status(dep.id))
                        }
                        Text("\(dep.storeIDs.count) stores · \(dep.deviceCount) devices")
                            .font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: dep.progress)
                            .accessibilityIdentifier(AID.Deployments.progress(dep.id))
                            .accessibilityValue("\(Int(dep.progress * 100)) percent")
                        if dep.status.isActive {
                            Button("Cancel deployment", role: .destructive) {
                                Task { await vm.cancel(dep.id) }
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier(AID.Deployments.cancel(dep.id))
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AID.Deployments.row(dep.id))
                }
            }
            .scrollIndicators(.visible)
            .accessibilityIdentifier(AID.Deployments.list)
            .overlay {
                if vm.isLoading && vm.deployments.isEmpty { LoadingView() }
                else if !vm.isLoading && vm.deployments.isEmpty && vm.errorMessage == nil {
                    ContentUnavailableView("No deployments yet", systemImage: "paperplane")
                        .accessibilityIdentifier(AID.Common.emptyState)
                }
            }
            .navigationTitle("Deployments")
            .refreshable { await vm.load() }
        }
        .accessibilityIdentifier(AID.Deployments.screen)
        // Poll while the tab is on screen; restarts when a new deployment is created.
        .task(id: appState.deploymentsRevision) {
            while !Task.isCancelled {
                await vm.load()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }
}
