import SwiftUI
import Observation

enum AppTab: Hashable { case dashboard, devices, content, deployments }

@MainActor @Observable
final class AppState {
    var selectedTab: AppTab = .dashboard
    /// Bumped after a deployment is created so the Deployments tab refreshes.
    var deploymentsRevision = 0
}

@main
struct MockDCOTAApp: App {
    private let service: DCOTAService
    private let config: AppConfig
    @State private var state = AppState()

    init() {
        let config = AppConfig.fromLaunchArguments()
        self.config = config
        self.service = config.makeService()
    }

    var body: some Scene {
        WindowGroup {
            RootView(service: service, skipOnboarding: config.skipOnboarding)
                .environment(state)
        }
    }
}
