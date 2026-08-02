import XCTest
@testable import aulycShot

final class AppActivityAvailabilityTests: XCTestCase {
    func testIdleAllowsActivityAndStartsEitherEntry() {
        let availability = AppActivityAvailability(overlayActive: false, recordingActive: false)

        XCTAssertTrue(availability.canBeginActivity)
        XCTAssertFalse(availability.hasConflictingActivities)
        XCTAssertEqual(availability.screenshotEntryDecision, .beginCapture)
        XCTAssertEqual(availability.recordingEntryDecision, .beginSelection)
    }

    func testOverlayBlocksNewEntriesWithoutBecomingAConflict() {
        let availability = AppActivityAvailability(overlayActive: true, recordingActive: false)

        XCTAssertFalse(availability.canBeginActivity)
        XCTAssertFalse(availability.hasConflictingActivities)
        XCTAssertEqual(availability.screenshotEntryDecision, .ignore)
        XCTAssertEqual(availability.recordingEntryDecision, .ignore)
    }

    func testRecordingTurnsScreenshotEntryIntoStopAndBlocksRecordingEntry() {
        let availability = AppActivityAvailability(overlayActive: false, recordingActive: true)

        XCTAssertFalse(availability.canBeginActivity)
        XCTAssertFalse(availability.hasConflictingActivities)
        XCTAssertEqual(availability.screenshotEntryDecision, .stopRecording)
        XCTAssertEqual(availability.recordingEntryDecision, .ignore)
    }

    func testConflictingActivitiesAreDetectedAndDoNotStartAnotherEntry() {
        let availability = AppActivityAvailability(overlayActive: true, recordingActive: true)

        XCTAssertFalse(availability.canBeginActivity)
        XCTAssertTrue(availability.hasConflictingActivities)
        XCTAssertEqual(availability.screenshotEntryDecision, .stopRecording)
        XCTAssertEqual(availability.recordingEntryDecision, .ignore)
    }
}
