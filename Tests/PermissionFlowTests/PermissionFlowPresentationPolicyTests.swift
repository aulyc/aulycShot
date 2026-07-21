import XCTest
@testable import PermissionFlow

final class PermissionFlowPresentationPolicyTests: XCTestCase {
    func testPackagedResourceBundleTakesPriorityOverSwiftPMBuildFallback() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let bundleURL = root.appendingPathComponent("aulycShot_PermissionFlow.bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let info: [String: Any] = [
            "CFBundleIdentifier": "com.aulyc.permission-flow-test",
            "CFBundleName": "PermissionFlow",
            "CFBundlePackageType": "BNDL",
        ]
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try infoData.write(to: bundleURL.appendingPathComponent("Info.plist"))

        var fallbackUsed = false
        let resolved = PermissionFlowLocalizer.resolveResourceBundle(mainResourceURL: root) {
            fallbackUsed = true
            return Bundle.main
        }

        XCTAssertEqual(resolved.bundleURL.standardizedFileURL, bundleURL.standardizedFileURL)
        XCTAssertFalse(fallbackUsed)
    }

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
