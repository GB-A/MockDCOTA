import Foundation

enum TestConfiguration {
    /// Default timeout for waiting for UI elements, configurable via environment variable in CI.
    static var defaultTimeout: TimeInterval {
        if let timeoutString = ProcessInfo.processInfo.environment["UI_TEST_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            return timeout
        }
        return 30.0
    }
}
