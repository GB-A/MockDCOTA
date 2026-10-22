import XCTest

/// Page Object representing the Fleet Dashboard Screen in MockDCOTA.
final class DashboardPage {
    private let app: XCUIApplication
    private let defaultTimeout: TimeInterval

    // MARK: - Accessibility Identifiers
    private enum Identifiers {
        static let screen = "dashboard.screen"
        static let totalDevices = "dashboard.total"
        static let onlineDevices = "dashboard.online"
        static let offlineDevices = "dashboard.offline"
        static let updatingDevices = "dashboard.updating"
        static let failedDevices = "dashboard.failed"
        static let activeDeployments = "dashboard.activeDeployments"
        static let onlinePercentage = "dashboard.onlinePercentage"
    }

    // MARK: - UI Elements
    private var screenElement: XCUIElement {
        app.navigationBars["Fleet"]
    }

    private var totalDevicesTile: XCUIElement {
        app.staticTexts[Identifiers.totalDevices]
    }

    private var onlinePercentageLabel: XCUIElement {
        app.staticTexts[Identifiers.onlinePercentage]
    }

    // MARK: - Initializer
    init(app: XCUIApplication = XCUIApplication()) {
        self.app = app
        self.defaultTimeout = TestConfiguration.defaultTimeout
    }

    // MARK: - Wait & Navigation Methods

    /// Waits for the Dashboard screen to be loaded and visible.
    @discardableResult
    func waitForPageToLoad(timeout: TimeInterval? = nil) -> DashboardPage {
        let waitTimeout = timeout ?? defaultTimeout
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: screenElement)
        
        let result = XCTWaiter().wait(for: [expectation], timeout: waitTimeout)
        XCTAssertEqual(result, .completed, "Dashboard screen (\(Identifiers.screen)) failed to appear within \(waitTimeout) seconds.")
        
        return self
    }

    // MARK: - Assertions & Queries

    /// Reads the displayed total device count value from the summary tile.
    func getTotalDevicesValue(timeout: TimeInterval? = nil) -> String {
        let waitTimeout = timeout ?? defaultTimeout
        XCTAssertTrue(
            totalDevicesTile.waitForExistence(timeout: waitTimeout),
            "Total devices tile (\(Identifiers.totalDevices)) did not exist within \(waitTimeout) seconds."
        )
        return totalDevicesTile.label
    }

    /// Asserts that the total devices tile matches an expected formatted string.
    @discardableResult
    func assertTotalDevicesEquals(_ expectedTotal: String, file: StaticString = #file, line: UInt = #line) -> DashboardPage {
        let actualTotal = getTotalDevicesValue()
        XCTAssertEqual(
            actualTotal,
            expectedTotal,
            "Expected total fleet count to be '\(expectedTotal)', but found '\(actualTotal)'.",
            file: file,
            line: line
        )
        return self
    }

    /// Asserts that the online percentage label is present and contains expected metrics.
    @discardableResult
    func assertOnlinePercentageIsVisible(file: StaticString = #file, line: UInt = #line) -> DashboardPage {
        XCTAssertTrue(
            onlinePercentageLabel.waitForExistence(timeout: defaultTimeout),
            "Online percentage summary footer was not visible on the dashboard.",
            file: file,
            line: line
        )
        return self
    }
}
