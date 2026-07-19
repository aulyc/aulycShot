import XCTest
@testable import aulycShot

final class AppStartupPlanTests: XCTestCase {
    func testManualLaunchWithoutPermissionsStillCreatesStatusBar() {
        let plan = AppStartupPlan.make(
            launchAtLoginEnabled: false,
            allRequiredPermissionsGranted: false,
            hasPendingOpenImages: false
        )

        XCTAssertTrue(plan.shouldCreateStatusBar)
        XCTAssertFalse(plan.shouldInitializeApp)
        XCTAssertTrue(plan.shouldShowStartupDialog)
    }

    func testLoginLaunchWithPermissionsInitializesWithoutStartupDialog() {
        let plan = AppStartupPlan.make(
            launchAtLoginEnabled: true,
            allRequiredPermissionsGranted: true,
            hasPendingOpenImages: false
        )

        XCTAssertTrue(plan.shouldCreateStatusBar)
        XCTAssertTrue(plan.shouldInitializeApp)
        XCTAssertFalse(plan.shouldShowStartupDialog)
    }

    func testPendingImageInitializesEvenWhenPermissionsAreMissing() {
        let plan = AppStartupPlan.make(
            launchAtLoginEnabled: false,
            allRequiredPermissionsGranted: false,
            hasPendingOpenImages: true
        )

        XCTAssertTrue(plan.shouldCreateStatusBar)
        XCTAssertTrue(plan.shouldInitializeApp)
        XCTAssertFalse(plan.shouldShowStartupDialog)
    }
}
