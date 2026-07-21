import XCTest
@testable import aulycShot

final class ScreenshotImageQualityTests: XCTestCase {
    func testSharedPreferenceUsesThePersistedSharedValue() {
        XCTAssertEqual(
            ScreenshotImageQuality.resolveSharedPreference(
                sharedRawValue: "compressed",
                legacySaveRawValue: "original",
                legacyClipboardRawValue: "original"
            ),
            .compressed
        )
    }

    func testLegacyPreferencesStayCompressedWhenBothWereCompressed() {
        XCTAssertEqual(
            ScreenshotImageQuality.resolveSharedPreference(
                sharedRawValue: nil,
                legacySaveRawValue: "compressed",
                legacyClipboardRawValue: "compressed"
            ),
            .compressed
        )
    }

    func testLegacyPreferenceConflictMigratesToOriginalQuality() {
        XCTAssertEqual(
            ScreenshotImageQuality.resolveSharedPreference(
                sharedRawValue: nil,
                legacySaveRawValue: "compressed",
                legacyClipboardRawValue: "original"
            ),
            .original
        )
    }

    func testLegacyBalancedAndCompactValuesMigrateToCompressed() {
        XCTAssertEqual(
            ScreenshotImageQuality.resolveSharedPreference(
                sharedRawValue: nil,
                legacySaveRawValue: "balanced",
                legacyClipboardRawValue: "compact"
            ),
            .compressed
        )
    }
}
