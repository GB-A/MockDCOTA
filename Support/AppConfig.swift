import Foundation

/// Launch-argument driven configuration so an external UI-test project can
/// control the app without any code changes:
///
///   -dcota-backend inmemory|remote        (default inmemory)
///   -dcota-base-url http://localhost:8080 (remote only)
///   -dcota-scenario standard|empty|error|slow
///   -dcota-no-progress YES                (freeze deployment progress)
///   -dcota-skip-onboarding YES            (skip the first-run welcome sheet)
///   -dcota-feature-bulk-select YES|NO     (feature flag, see FeatureFlags)
struct AppConfig {
    enum Backend: String { case inmemory, remote }

    let backend: Backend
    let baseURL: URL
    let scenario: Scenario
    let autoProgress: Bool
    let skipOnboarding: Bool

    static func fromLaunchArguments(_ defaults: UserDefaults = .standard) -> AppConfig {
        AppConfig(
            backend: Backend(rawValue: defaults.string(forKey: "dcota-backend") ?? "") ?? .inmemory,
            baseURL: URL(string: defaults.string(forKey: "dcota-base-url") ?? "") ?? URL(string: "http://localhost:8080")!,
            scenario: Scenario(rawValue: defaults.string(forKey: "dcota-scenario") ?? "") ?? .standard,
            autoProgress: !defaults.bool(forKey: "dcota-no-progress"),
            skipOnboarding: defaults.bool(forKey: "dcota-skip-onboarding"))
    }

    func makeService() -> DCOTAService {
        switch backend {
        case .inmemory: InMemoryDCOTAService(scenario: scenario, autoProgress: autoProgress)
        case .remote: RemoteDCOTAService(baseURL: baseURL)
        }
    }
}

/// Feature flags, overridable at launch for flag-matrix testing.
enum FeatureFlags {
    static func isEnabled(_ name: String, default value: Bool, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: "dcota-feature-\(name)") == nil ? value : defaults.bool(forKey: "dcota-feature-\(name)")
    }
    /// Show store-select-all in the deploy sheet.
    static var bulkSelect: Bool { isEnabled("bulk-select", default: true) }
}
