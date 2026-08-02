import XCTest
@testable import aulycShot

final class AppActivityEntryRoutingTests: XCTestCase {
    func testIdleScreenshotEntryBeginsCaptureWithoutStoppingRecording() {
        let availability = AppActivityAvailability(overlayActive: false, recordingActive: false)
        var captureStartCount = 0
        var recordingStopCount = 0

        let decision = AppActivityEntryRouter.routeScreenshot(
            availability: availability,
            beginCapture: { captureStartCount += 1 },
            stopRecording: { recordingStopCount += 1 }
        )

        XCTAssertEqual(decision, .beginCapture)
        XCTAssertEqual(captureStartCount, 1)
        XCTAssertEqual(recordingStopCount, 0)
    }

    func testScreenshotEntryStopsActiveRecordingWithoutBeginningCapture() {
        let availability = AppActivityAvailability(overlayActive: false, recordingActive: true)
        var captureStartCount = 0
        var recordingStopCount = 0

        let decision = AppActivityEntryRouter.routeScreenshot(
            availability: availability,
            beginCapture: { captureStartCount += 1 },
            stopRecording: { recordingStopCount += 1 }
        )

        XCTAssertEqual(decision, .stopRecording)
        XCTAssertEqual(captureStartCount, 0)
        XCTAssertEqual(recordingStopCount, 1)
    }

    func testIdleRecordingEntryBeginsSelection() {
        let availability = AppActivityAvailability(overlayActive: false, recordingActive: false)
        var recordingSelectionCount = 0

        let decision = AppActivityEntryRouter.routeRecordingSelection(
            availability: availability,
            beginSelection: { recordingSelectionCount += 1 }
        )

        XCTAssertEqual(decision, .beginSelection)
        XCTAssertEqual(recordingSelectionCount, 1)
    }

    func testOverlayBlocksScreenshotAndRecordingSelectionEntries() {
        let availability = AppActivityAvailability(overlayActive: true, recordingActive: false)
        var captureStartCount = 0
        var recordingStopCount = 0
        var recordingSelectionCount = 0

        let screenshotDecision = AppActivityEntryRouter.routeScreenshot(
            availability: availability,
            beginCapture: { captureStartCount += 1 },
            stopRecording: { recordingStopCount += 1 }
        )
        let recordingDecision = AppActivityEntryRouter.routeRecordingSelection(
            availability: availability,
            beginSelection: { recordingSelectionCount += 1 }
        )

        XCTAssertEqual(screenshotDecision, .ignore)
        XCTAssertEqual(recordingDecision, .ignore)
        XCTAssertEqual(captureStartCount, 0)
        XCTAssertEqual(recordingStopCount, 0)
        XCTAssertEqual(recordingSelectionCount, 0)
    }

    func testRecordingHandoffWaitsForSelectionOverlayToReleaseThenBlocksNewRecordingEntry() {
        var recordingStartCount = 0

        let whileSelecting = AppActivityAvailability(overlayActive: true, recordingActive: false)
        let didStartWhileSelecting = AppActivityEntryRouter.routeRecordingHandoff(
            availability: whileSelecting,
            beginRecording: { recordingStartCount += 1 }
        )

        let afterSelectionRelease = AppActivityAvailability(overlayActive: false, recordingActive: false)
        let didStartAfterRelease = AppActivityEntryRouter.routeRecordingHandoff(
            availability: afterSelectionRelease,
            beginRecording: { recordingStartCount += 1 }
        )

        var newSelectionCount = 0
        let whileRecording = AppActivityAvailability(overlayActive: false, recordingActive: true)
        let newEntryDecision = AppActivityEntryRouter.routeRecordingSelection(
            availability: whileRecording,
            beginSelection: { newSelectionCount += 1 }
        )

        XCTAssertFalse(didStartWhileSelecting)
        XCTAssertTrue(didStartAfterRelease)
        XCTAssertEqual(recordingStartCount, 1)
        XCTAssertEqual(newEntryDecision, .ignore)
        XCTAssertEqual(newSelectionCount, 0)
    }
}
