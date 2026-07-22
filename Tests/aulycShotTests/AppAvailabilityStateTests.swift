import XCTest
@testable import aulycShot

final class PermissionFeatureAvailabilityTests: XCTestCase {
    func testNoPermissionsMakeFeatureUnavailable() {
        let availability = PermissionFeatureAvailability.make(
            accessibilityGranted: false,
            screenRecordingGranted: false
        )

        XCTAssertFalse(availability.isAvailable)
    }

    func testScreenRecordingAloneKeepsFeatureUnavailable() {
        let availability = PermissionFeatureAvailability.make(
            accessibilityGranted: false,
            screenRecordingGranted: true
        )

        XCTAssertFalse(availability.isAvailable)
    }

    func testAccessibilityAloneKeepsFeatureUnavailable() {
        let availability = PermissionFeatureAvailability.make(
            accessibilityGranted: true,
            screenRecordingGranted: false
        )

        XCTAssertFalse(availability.isAvailable)
    }

    func testAllPermissionsEnableFeature() {
        let availability = PermissionFeatureAvailability.make(
            accessibilityGranted: true,
            screenRecordingGranted: true
        )

        XCTAssertTrue(availability.isAvailable)
    }
}
