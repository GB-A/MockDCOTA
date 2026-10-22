import Foundation

/// The seam that makes the app testable: every screen depends on this protocol,
/// never on a concrete backend.
protocol DCOTAService: Sendable {
    func fleetSummary() async throws -> FleetSummary
    func devices(query: DeviceQuery) async throws -> Page<Device>
    func device(id: String) async throws -> Device
    func stores() async throws -> [Store]
    func packages() async throws -> [ContentPackage]
    func deployments() async throws -> [Deployment]
    func createDeployment(_ request: CreateDeploymentRequest) async throws -> Deployment
    func cancelDeployment(id: String) async throws -> Deployment
}

/// Business rules shared by every implementation of the mock backend.
enum DeploymentRules {
    static let maxStoresPerDeployment = 10
}
