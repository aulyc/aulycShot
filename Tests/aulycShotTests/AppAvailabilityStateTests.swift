import XCTest
@testable import aulycShot

final class AppAvailabilityStateTests: XCTestCase {
    func testNoPermissionsIsUnavailable() {
        XCTAssertEqual(
            AppAvailabilityState.make(
                accessibilityGranted: false,
                screenRecordingGranted: false
            ),
            .unavailable
        )
    }

    func testOnePermissionIsPartiallyAvailable() {
        XCTAssertEqual(
            AppAvailabilityState.make(
                accessibilityGranted: true,
                screenRecordingGranted: false
            ),
            .partiallyAvailable
        )
        XCTAssertEqual(
            AppAvailabilityState.make(
                accessibilityGranted: false,
                screenRecordingGranted: true
            ),
            .partiallyAvailable
        )
    }

    func testAllPermissionsIsNormallyAvailable() {
        XCTAssertEqual(
            AppAvailabilityState.make(
                accessibilityGranted: true,
                screenRecordingGranted: true
            ),
            .normallyAvailable
        )
    }
}
