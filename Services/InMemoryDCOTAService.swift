import Foundation

/// Backend scenarios selectable at launch with `-dcota-scenario <name>`.
enum Scenario: String {
    case standard   // seeded fleet, everything works
    case empty      // no devices, packages, or deployments
    case error      // every call fails with a server error
    case slow       // every call takes ~2s (loading states, timeouts)
}

/// In-memory implementation: deterministic, fast, no network. Used by default
/// so UI tests are hermetic.
actor InMemoryDCOTAService: DCOTAService {
    private let scenario: Scenario
    private let autoProgress: Bool
    private var allDevices: [Device]
    private var allStores: [Store]
    private var allPackages: [ContentPackage]
    private var allDeployments: [Deployment]
    private var nextDeploymentNumber = 100
    /// How many times each active deployment has been observed (drives progress).
    private var ticks: [String: Int] = [:]

    init(scenario: Scenario = .standard, autoProgress: Bool = true) {
        self.scenario = scenario
        self.autoProgress = autoProgress
        if scenario == .empty {
            allDevices = []; allStores = SeedData.stores; allPackages = []; allDeployments = []
        } else {
            allDevices = SeedData.devices
            allStores = SeedData.storesWithCounts
            allPackages = SeedData.packages
            allDeployments = [
                Deployment(id: "dep-001", packageID: "pkg-001", packageName: "Holiday Demo Loop",
                           packageVersion: "2.1.0", storeIDs: ["store-001"], deviceCount: 40,
                           status: .inProgress, progress: 0.5,
                           createdAt: SeedData.referenceDate.addingTimeInterval(-3_600)),
                Deployment(id: "dep-002", packageID: "pkg-002", packageName: "Trade-In Promo",
                           packageVersion: "1.4.2", storeIDs: ["store-002", "store-003"], deviceCount: 80,
                           status: .completed, progress: 1,
                           createdAt: SeedData.referenceDate.addingTimeInterval(-86_400)),
                Deployment(id: "dep-003", packageID: "pkg-003", packageName: "Accessories Showcase",
                           packageVersion: "3.0.0", storeIDs: ["store-004"], deviceCount: 38,
                           status: .failed, progress: 0.3,
                           createdAt: SeedData.referenceDate.addingTimeInterval(-172_800)),
            ]
        }
    }

    // MARK: - Scenario gate

    private func gate() async throws {
        switch scenario {
        case .error: throw DCOTAError.server("DCOTA service is unavailable. Please try again.")
        case .slow: try await Task.sleep(nanoseconds: 2_000_000_000)
        default: break
        }
    }

    // MARK: - Reads

    func fleetSummary() async throws -> FleetSummary {
        try await gate()
        if scenario == .empty {
            return FleetSummary(totalDevices: 0, online: 0, offline: 0, updating: 0, failed: 0, activeDeployments: 0)
        }
        // Scale the sampled ratios up to the 1.4M-device fleet.
        let n = Double(allDevices.count)
        func scaled(_ s: DeviceStatus) -> Int {
            Int((Double(allDevices.filter { $0.status == s }.count) / n * Double(SeedData.fleetScale)).rounded())
        }
        let online = scaled(.online), offline = scaled(.offline), updating = scaled(.updating)
        let failed = SeedData.fleetScale - online - offline - updating   // totals always reconcile
        return FleetSummary(totalDevices: SeedData.fleetScale, online: online, offline: offline,
                            updating: updating, failed: failed,
                            activeDeployments: allDeployments.filter { $0.status.isActive }.count)
    }

    func devices(query: DeviceQuery) async throws -> Page<Device> {
        try await gate()
        guard query.page >= 1 else { throw DCOTAError.validation("page must be >= 1") }
        guard (1...100).contains(query.pageSize) else { throw DCOTAError.validation("pageSize must be between 1 and 100") }
        let term = query.search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = allDevices.filter { d in
            (query.status == nil || d.status == query.status) &&
            (term.isEmpty || d.serialNumber.lowercased().contains(term)
                          || d.storeName.lowercased().contains(term)
                          || d.model.lowercased().contains(term))
        }
        let start = (query.page - 1) * query.pageSize
        let items = start < filtered.count ? Array(filtered[start..<min(start + query.pageSize, filtered.count)]) : []
        return Page(items: items, page: query.page, pageSize: query.pageSize, total: filtered.count)
    }

    func device(id: String) async throws -> Device {
        try await gate()
        guard let d = allDevices.first(where: { $0.id == id }) else {
            throw DCOTAError.notFound("Device \(id) not found")
        }
        return d
    }

    func stores() async throws -> [Store] { try await gate(); return allStores }
    func packages() async throws -> [ContentPackage] { try await gate(); return allPackages }

    func deployments() async throws -> [Deployment] {
        try await gate()
        if autoProgress { advanceActiveDeployments() }
        return allDeployments.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Writes

    func createDeployment(_ request: CreateDeploymentRequest) async throws -> Deployment {
        try await gate()
        guard let package = allPackages.first(where: { $0.id == request.packageID }) else {
            throw DCOTAError.notFound("Package \(request.packageID) not found")
        }
        let storeIDs = Array(Set(request.storeIDs)).sorted()
        guard !storeIDs.isEmpty else { throw DCOTAError.validation("Select at least one store.") }
        guard storeIDs.count <= DeploymentRules.maxStoresPerDeployment else {
            throw DCOTAError.validation("A deployment can target at most \(DeploymentRules.maxStoresPerDeployment) stores.")
        }
        let targets = allStores.filter { storeIDs.contains($0.id) }
        guard targets.count == storeIDs.count else { throw DCOTAError.validation("One or more stores do not exist.") }

        // Conflict: same package already active in any requested store.
        let busy = allDeployments.filter {
            $0.status.isActive && $0.packageID == package.id && !Set($0.storeIDs).isDisjoint(with: storeIDs)
        }
        if !busy.isEmpty {
            throw DCOTAError.conflict("\(package.name) is already being deployed to one or more selected stores.")
        }

        nextDeploymentNumber += 1
        let deployment = Deployment(
            id: "dep-\(nextDeploymentNumber)", packageID: package.id, packageName: package.name,
            packageVersion: package.version, storeIDs: storeIDs,
            deviceCount: targets.reduce(0) { $0 + $1.deviceCount },
            status: .scheduled, progress: 0, createdAt: Date())
        allDeployments.append(deployment)
        return deployment
    }

    func cancelDeployment(id: String) async throws -> Deployment {
        try await gate()
        guard let i = allDeployments.firstIndex(where: { $0.id == id }) else {
            throw DCOTAError.notFound("Deployment \(id) not found")
        }
        guard allDeployments[i].status.isActive else {
            throw DCOTAError.conflict("Only scheduled or in-progress deployments can be cancelled.")
        }
        allDeployments[i].status = .cancelled
        return allDeployments[i]
    }

    // MARK: - Simulation

    /// scheduled -> inProgress(0.4) -> inProgress(0.8) -> completed, one step per poll.
    private func advanceActiveDeployments() {
        for i in allDeployments.indices where allDeployments[i].status.isActive {
            let id = allDeployments[i].id
            if id == "dep-001" { continue }   // seeded fixture stays in progress for conflict tests
            let t = (ticks[id] ?? 0) + 1
            ticks[id] = t
            switch t {
            case 1: allDeployments[i].status = .inProgress; allDeployments[i].progress = 0.4
            case 2: allDeployments[i].progress = 0.8
            default: allDeployments[i].status = .completed; allDeployments[i].progress = 1
            }
        }
    }
}
