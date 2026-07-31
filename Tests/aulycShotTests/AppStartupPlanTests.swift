import XCTest
@testable import aulycShot

final class AppStartupPlanTests: XCTestCase {
    func testProcessLaunchInitializesInMenuBarWithoutOpeningSettings() {
        let plan = AppStartupPlan.silent

        XCTAssertTrue(plan.shouldCreateStatusBar)
        XCTAssertTrue(plan.shouldInitializeApp)
        XCTAssertFalse(plan.shouldShowStartupDialog)
    }
}
