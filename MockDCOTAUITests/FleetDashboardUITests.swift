import XCTest

final class FleetDashboardUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Fail immediately on assertion failures to preserve execution context
        continueAfterFailure = false

        app = XCUIApplication()
        
        // Pass launch arguments to configure app state predictably
        app.launchArguments = [
            "-dcota-skip-onboarding", "YES",
            "-dcota-backend", "inmemory",
            "-dcota-scenario", "standard"
        ]
        
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Scenarios

    @MainActor
    func testFleetTotalIsShownForWholeFleet() throws {
        // Expected fleet scale defined in SeedData (1,400,000 formatted as "1,400,000")
        let expectedFleetTotal = "1,400,000"

        let dashboardPage = DashboardPage(app: app)

        dashboardPage
            .waitForPageToLoad()
            .assertTotalDevicesEquals(expectedFleetTotal)
            .assertOnlinePercentageIsVisible()
    }
}
