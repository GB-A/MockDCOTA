import Foundation
import Observation

@MainActor @Observable
final class DashboardViewModel {
    private let service: DCOTAService
    var summary: FleetSummary?
    var isLoading = false
    var errorMessage: String?

    init(service: DCOTAService) { self.service = service }

    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { summary = try await service.fleetSummary() }
        catch { errorMessage = error.localizedDescription }
    }
}

@MainActor @Observable
final class DevicesViewModel {
    private let service: DCOTAService
    var devices: [Device] = []
    var total = 0
    var hasMore = false
    var search = ""
    var status: DeviceStatus?
    var isLoading = false
    var errorMessage: String?
    private var page = 1
    private var generation = 0   // discards responses from superseded queries

    init(service: DCOTAService) { self.service = service }

    func reload() async {
        generation += 1
        let mine = generation
        page = 1; isLoading = true; errorMessage = nil
        defer { if mine == generation { isLoading = false } }
        do {
            let result = try await service.devices(query: query())
            guard mine == generation else { return }
            devices = result.items; total = result.total; hasMore = result.hasMore
        } catch {
            guard mine == generation else { return }
            devices = []; total = 0; hasMore = false
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        let mine = generation
        isLoading = true
        defer { if mine == generation { isLoading = false } }
        do {
            var q = query(); q.page = page + 1
            let result = try await service.devices(query: q)
            guard mine == generation else { return }
            page += 1
            devices += result.items; total = result.total; hasMore = result.hasMore
        } catch {
            guard mine == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func query() -> DeviceQuery { DeviceQuery(search: search, status: status, page: page, pageSize: 25) }
}

@MainActor @Observable
final class ContentViewModel {
    let service: DCOTAService
    var packages: [ContentPackage] = []
    var isLoading = false
    var errorMessage: String?

    init(service: DCOTAService) { self.service = service }

    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { packages = try await service.packages() }
        catch { packages = []; errorMessage = error.localizedDescription }
    }
}

@MainActor @Observable
final class DeployViewModel {
    private let service: DCOTAService
    let package: ContentPackage
    var stores: [Store] = []
    var selected: Set<String> = []
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String?

    init(service: DCOTAService, package: ContentPackage) {
        self.service = service; self.package = package
    }

    var allSelected: Bool { !stores.isEmpty && selected.count == stores.count }
    var selectedDeviceCount: Int { stores.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.deviceCount } }

    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { stores = try await service.stores() }
        catch { errorMessage = error.localizedDescription }
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    func toggleAll() { selected = allSelected ? [] : Set(stores.map(\.id)) }

    /// Returns the created deployment, or nil with `errorMessage` set.
    func submit() async -> Deployment? {
        isSubmitting = true; errorMessage = nil
        defer { isSubmitting = false }
        do {
            return try await service.createDeployment(
                CreateDeploymentRequest(packageID: package.id, storeIDs: Array(selected)))
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@MainActor @Observable
final class DeploymentsViewModel {
    private let service: DCOTAService
    var deployments: [Deployment] = []
    var isLoading = false
    var errorMessage: String?

    init(service: DCOTAService) { self.service = service }

    func load() async {
        isLoading = deployments.isEmpty; errorMessage = nil
        defer { isLoading = false }
        do { deployments = try await service.deployments() }
        catch { errorMessage = error.localizedDescription }
    }

    func cancel(_ id: String) async {
        errorMessage = nil
        do {
            let updated = try await service.cancelDeployment(id: id)
            if let i = deployments.firstIndex(where: { $0.id == id }) { deployments[i] = updated }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
