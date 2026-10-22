/// Single source of truth for accessibility identifiers.
/// Documented contract for the external UI-test project: renaming one is a breaking change.
enum AID {
    enum Tab {
        static let dashboard = "tab.dashboard"
        static let devices = "tab.devices"
        static let content = "tab.content"
        static let deployments = "tab.deployments"
    }
    enum Dashboard {
        static let screen = "dashboard.screen"
        static let totalDevices = "dashboard.total"
        static let online = "dashboard.online"
        static let offline = "dashboard.offline"
        static let updating = "dashboard.updating"
        static let failed = "dashboard.failed"
        static let activeDeployments = "dashboard.activeDeployments"
        static let onlinePercentage = "dashboard.onlinePercentage"
    }
    enum Devices {
        static let screen = "devices.screen"
        static let list = "devices.list"
        static let statusFilter = "devices.statusFilter"
        static let loadMore = "devices.loadMore"
        static let resultCount = "devices.resultCount"
        static func row(_ id: String) -> String { "devices.row.\(id)" }
    }
    enum DeviceDetail {
        static let screen = "deviceDetail.screen"
        static let serial = "deviceDetail.serial"
        static let status = "deviceDetail.status"
        static let store = "deviceDetail.store"
        static let model = "deviceDetail.model"
        static let content = "deviceDetail.content"
    }
    enum Content {
        static let screen = "content.screen"
        static let list = "content.list"
        static func row(_ id: String) -> String { "content.row.\(id)" }
        static func deployButton(_ id: String) -> String { "content.deploy.\(id)" }
    }
    enum DeploySheet {
        static let screen = "deploySheet.screen"
        static let selectAll = "deploySheet.selectAll"
        static let submit = "deploySheet.submit"
        static let cancel = "deploySheet.cancel"
        static let error = "deploySheet.error"
        static let selectionCount = "deploySheet.selectionCount"
        static func store(_ id: String) -> String { "deploySheet.store.\(id)" }
    }
    enum Deployments {
        static let screen = "deployments.screen"
        static let list = "deployments.list"
        static func row(_ id: String) -> String { "deployments.row.\(id)" }
        static func status(_ id: String) -> String { "deployments.status.\(id)" }
        static func progress(_ id: String) -> String { "deployments.progress.\(id)" }
        static func cancel(_ id: String) -> String { "deployments.cancel.\(id)" }
    }
    enum Common {
        static let loading = "common.loading"
        static let errorBanner = "common.error"
        static let retry = "common.retry"
        static let emptyState = "common.empty"
        static let onboarding = "onboarding.screen"
        static let onboardingDismiss = "onboarding.dismiss"
    }
}
