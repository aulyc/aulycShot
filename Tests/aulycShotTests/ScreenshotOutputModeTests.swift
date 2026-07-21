import XCTest
@testable import aulycShot

final class ScreenshotOutputModeTests: XCTestCase {
    func testDefaultModePreservesClipboardOnlyBehavior() {
        XCTAssertEqual(ScreenshotOutputMode.defaultValue, .clipboardOnly)
    }

    func testClipboardOnlyModeCopiesWithoutSaving() {
        XCTAssertTrue(ScreenshotOutputMode.clipboardOnly.copiesToClipboard)
        XCTAssertFalse(ScreenshotOutputMode.clipboardOnly.savesToDirectory)
    }

    func testFileOnlyModeSavesWithoutCopying() {
        XCTAssertFalse(ScreenshotOutputMode.fileOnly.copiesToClipboard)
        XCTAssertTrue(ScreenshotOutputMode.fileOnly.savesToDirectory)
    }

    func testClipboardAndFileModePerformsBothOutputs() {
        XCTAssertTrue(ScreenshotOutputMode.clipboardAndFile.copiesToClipboard)
        XCTAssertTrue(ScreenshotOutputMode.clipboardAndFile.savesToDirectory)
    }

    func testSavePathStatePreservesDirectoryWhenOutputModeChanges() {
        let directory = URL(fileURLWithPath: "/tmp/aulycShot-custom-screenshot-path")
        let clipboardOnly = ScreenshotSavePathControlState(
            directory: directory,
            outputMode: .clipboardOnly
        )
        let fileOnly = ScreenshotSavePathControlState(
            directory: directory,
            outputMode: .fileOnly
        )
        let combined = ScreenshotSavePathControlState(
            directory: directory,
            outputMode: .clipboardAndFile
        )

        XCTAssertEqual(clipboardOnly.directory, directory)
        XCTAssertEqual(fileOnly.directory, directory)
        XCTAssertEqual(combined.directory, directory)
        XCTAssertFalse(clipboardOnly.isEnabled)
        XCTAssertTrue(fileOnly.isEnabled)
        XCTAssertTrue(combined.isEnabled)
    }
}
