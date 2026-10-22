import SwiftUI

struct DevicesView: View {
    @State private var vm: DevicesViewModel

    init(service: DCOTAService) { _vm = State(initialValue: DevicesViewModel(service: service)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Status", selection: $vm.status) {
                        Text("All").tag(DeviceStatus?.none)
                        ForEach(DeviceStatus.allCases) { Text($0.label).tag(DeviceStatus?.some($0)) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier(AID.Devices.statusFilter)
                    Text("\(vm.total) devices")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier(AID.Devices.resultCount)
                }

                if let message = vm.errorMessage {
                    ErrorBanner(message: message) { Task { await vm.reload() } }
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }

                Section {
                    ForEach(vm.devices) { device in
                        NavigationLink(value: device) { DeviceRow(device: device) }
                            .accessibilityIdentifier(AID.Devices.row(device.id))
                            .onAppear {
                                // Infinite scroll: fetch the next page when the last row appears.
                                if device.id == vm.devices.last?.id { Task { await vm.loadMore() } }
                            }
                    }
                    if vm.hasMore {
                        Button("Load more") { Task { await vm.loadMore() } }
                            .accessibilityIdentifier(AID.Devices.loadMore)
                    }
                }
            }
            .scrollIndicators(.visible)
            .accessibilityIdentifier(AID.Devices.list)
            .overlay {
                if vm.isLoading && vm.devices.isEmpty { LoadingView() }
                else if !vm.isLoading && vm.devices.isEmpty && vm.errorMessage == nil {
                    ContentUnavailableView("No devices found", systemImage: "ipad.slash",
                                           description: Text("Try a different search or filter."))
                        .accessibilityIdentifier(AID.Common.emptyState)
                }
            }
            .navigationTitle("Devices")
            .navigationDestination(for: Device.self) { DeviceDetailView(device: $0) }
            .searchable(text: $vm.search, prompt: "Serial, model or store")
            .refreshable { await vm.reload() }
        }
        .accessibilityIdentifier(AID.Devices.screen)
        // Re-runs (and cancels the previous run) when the search text or filter changes → debounce.
        .task(id: "\(vm.search)|\(vm.status?.rawValue ?? "all")") {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await vm.reload()
        }
    }
}

private struct DeviceRow: View {
    let device: Device
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.serialNumber).font(.body.monospaced())
                Text("\(device.model) · \(device.storeName)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(text: device.status.label, color: device.status.color)
        }
    }
}

struct DeviceDetailView: View {
    let device: Device

    var body: some View {
        List {
            row("Serial", device.serialNumber, AID.DeviceDetail.serial)
            row("Model", device.model, AID.DeviceDetail.model)
            row("OS", device.osVersion, nil)
            row("Store", device.storeName, AID.DeviceDetail.store)
            row("Status", device.status.label, AID.DeviceDetail.status)
            row("Content version", device.contentVersion ?? "None", AID.DeviceDetail.content)
            row("Last check-in", device.lastCheckIn.formatted(date: .abbreviated, time: .shortened), nil)
        }
        .navigationTitle("Device")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AID.DeviceDetail.screen)
    }

    @ViewBuilder
    private func row(_ title: String, _ value: String, _ id: String?) -> some View {
        LabeledContent(title) {
            if let id { Text(value).accessibilityIdentifier(id) } else { Text(value) }
        }
    }
}
