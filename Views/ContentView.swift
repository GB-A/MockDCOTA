import SwiftUI

struct ContentView: View {
    let service: DCOTAService
    @State private var vm: ContentViewModel
    @State private var deployTarget: ContentPackage?

    init(service: DCOTAService) {
        self.service = service
        _vm = State(initialValue: ContentViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            List {
                if let message = vm.errorMessage {
                    ErrorBanner(message: message) { Task { await vm.load() } }
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                ForEach(vm.packages) { pkg in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pkg.name).font(.headline)
                            Text("v\(pkg.version) · \(pkg.sizeMB) MB · \(pkg.category)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Deploy") { deployTarget = pkg }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(AID.Content.deployButton(pkg.id))
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AID.Content.row(pkg.id))
                }
            }
            .scrollIndicators(.visible)
            .accessibilityIdentifier(AID.Content.list)
            .overlay {
                if vm.isLoading && vm.packages.isEmpty { LoadingView() }
                else if !vm.isLoading && vm.packages.isEmpty && vm.errorMessage == nil {
                    ContentUnavailableView("No content packages", systemImage: "shippingbox")
                        .accessibilityIdentifier(AID.Common.emptyState)
                }
            }
            .navigationTitle("Content")
            .refreshable { await vm.load() }
        }
        .accessibilityIdentifier(AID.Content.screen)
        .task { await vm.load() }
        .sheet(item: $deployTarget) { pkg in
            DeploySheet(vm: DeployViewModel(service: service, package: pkg))
        }
    }
}

struct DeploySheet: View {
    @State var vm: DeployViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Package") {
                    Text("\(vm.package.name) v\(vm.package.version)")
                }
                Section {
                    if FeatureFlags.bulkSelect {
                        Button(vm.allSelected ? "Deselect all" : "Select all") { vm.toggleAll() }
                            .accessibilityIdentifier(AID.DeploySheet.selectAll)
                    }
                    ForEach(vm.stores) { store in
                        Button { vm.toggle(store.id) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(store.name).foregroundStyle(.primary)
                                    Text("\(store.partner) · \(store.deviceCount) devices")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if vm.selected.contains(store.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier(AID.DeploySheet.store(store.id))
                        .accessibilityAddTraits(vm.selected.contains(store.id) ? .isSelected : [])
                    }
                } header: {
                    Text("Target stores")
                } footer: {
                    Text("\(vm.selected.count) stores · \(vm.selectedDeviceCount) devices")
                        .accessibilityIdentifier(AID.DeploySheet.selectionCount)
                }
                if let message = vm.errorMessage {
                    Text(message).foregroundStyle(.red)
                        .accessibilityIdentifier(AID.DeploySheet.error)
                }
            }
            .scrollIndicators(.visible)
            .overlay { if vm.isLoading && vm.stores.isEmpty { LoadingView() } }
            .navigationTitle("Deploy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier(AID.DeploySheet.cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.isSubmitting ? "Deploying…" : "Deploy") {
                        Task {
                            if await vm.submit() != nil {
                                appState.deploymentsRevision += 1
                                appState.selectedTab = .deployments
                                dismiss()
                            }
                        }
                    }
                    .disabled(vm.isSubmitting)   // note: empty selection is allowed → server validates
                    .accessibilityIdentifier(AID.DeploySheet.submit)
                }
            }
            .task { await vm.load() }
        }
        .accessibilityIdentifier(AID.DeploySheet.screen)
    }
}
