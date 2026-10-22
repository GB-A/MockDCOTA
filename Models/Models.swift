import Foundation

enum DeviceStatus: String, Codable, CaseIterable, Identifiable {
    case online, offline, updating, failed
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct Store: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let city: String
    let partner: String
    let deviceCount: Int
}

struct Device: Identifiable, Codable, Hashable {
    let id: String
    let serialNumber: String
    let model: String
    let osVersion: String
    let storeID: String
    let storeName: String
    var status: DeviceStatus
    var contentVersion: String?
    let lastCheckIn: Date
}

struct ContentPackage: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let version: String
    let sizeMB: Int
    let category: String
}

enum DeploymentStatus: String, Codable, CaseIterable {
    case scheduled, inProgress, completed, failed, cancelled

    var label: String {
        switch self {
        case .scheduled: "Scheduled"
        case .inProgress: "In Progress"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
    /// A deployment that still occupies its target stores.
    var isActive: Bool { self == .scheduled || self == .inProgress }
}

struct Deployment: Identifiable, Codable, Hashable {
    let id: String
    let packageID: String
    let packageName: String
    let packageVersion: String
    let storeIDs: [String]
    let deviceCount: Int
    var status: DeploymentStatus
    var progress: Double          // 0...1
    let createdAt: Date
}

struct FleetSummary: Codable, Equatable {
    let totalDevices: Int
    let online: Int
    let offline: Int
    let updating: Int
    let failed: Int
    let activeDeployments: Int

    var onlinePercentage: Double {
        totalDevices == 0 ? 0 : Double(online) / Double(totalDevices) * 100
    }
}

struct Page<T: Codable & Equatable>: Codable, Equatable {
    let items: [T]
    let page: Int
    let pageSize: Int
    let total: Int
    var hasMore: Bool { page * pageSize < total }
}

struct DeviceQuery: Equatable {
    var search: String = ""
    var status: DeviceStatus? = nil
    var page: Int = 1
    var pageSize: Int = 25
}

struct CreateDeploymentRequest: Codable, Equatable {
    let packageID: String
    let storeIDs: [String]
}
