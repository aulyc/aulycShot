import XCTest
@testable import PermissionFlow

final class PermissionFlowPresentationPolicyTests: XCTestCase {
    func testPanelClosesOnlyWhenSystemSettingsLeavesTheForeground() {
        XCTAssertFalse(PermissionFlowPresentationPolicy.shouldClosePanel(
            wasSettingsFrontmost: false,
            isSettingsFrontmost: false
        ))
        XCTAssertFalse(PermissionFlowPresentationPolicy.shouldClosePanel(
            wasSettingsFrontmost: false,
            isSettingsFrontmost: true
        ))
        XCTAssertFalse(PermissionFlowPresentationPolicy.shouldClosePanel(
            wasSettingsFrontmost: true,
            isSettingsFrontmost: true
        ))
        XCTAssertTrue(PermissionFlowPresentationPolicy.shouldClosePanel(
            wasSettingsFrontmost: true,
            isSettingsFrontmost: false
        ))
    }

    func testHiddenWindowEndsTrackingOnlyAfterAVisibleWindowWasObserved() {
        XCTAssertFalse(SettingsWindowVisibilityPolicy.shouldEndTracking(
            hadVisibleFrame: false,
            consecutiveMissingPolls: 12,
            threshold: 12
        ))
        XCTAssertFalse(SettingsWindowVisibilityPolicy.shouldEndTracking(
            hadVisibleFrame: true,
            consecutiveMissingPolls: 11,
            threshold: 12
        ))
        XCTAssertTrue(SettingsWindowVisibilityPolicy.shouldEndTracking(
            hadVisibleFrame: true,
            consecutiveMissingPolls: 12,
            threshold: 12
        ))
    }
}
