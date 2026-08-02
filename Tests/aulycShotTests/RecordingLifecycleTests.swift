import XCTest
@testable import aulycShot

final class RecordingLifecycleTests: XCTestCase {
    func testNormalStopTransitionsThroughStoppingAndCompletesOnce() {
        var lifecycle = RecordingLifecycle()

        XCTAssertTrue(lifecycle.start())
        XCTAssertTrue(lifecycle.markCaptureStarted())
        XCTAssertTrue(lifecycle.requestStop())
        XCTAssertEqual(lifecycle.state, .stopping)
        XCTAssertEqual(lifecycle.terminationIntent, .finish)
        XCTAssertTrue(lifecycle.complete())
        XCTAssertEqual(lifecycle.state, .idle)
        XCTAssertFalse(lifecycle.complete())
    }

    func testImmediateStopConvergesBeforeCaptureStarts() {
        var lifecycle = RecordingLifecycle()

        XCTAssertTrue(lifecycle.start())
        XCTAssertTrue(lifecycle.requestStop())
        XCTAssertFalse(lifecycle.allowsStartupWork)
        XCTAssertEqual(lifecycle.terminationIntent, .finish)
        XCTAssertTrue(lifecycle.complete())
        XCTAssertEqual(lifecycle.state, .idle)
    }

    func testImmediateCancelConvergesBeforeCaptureStarts() {
        var lifecycle = RecordingLifecycle()

        XCTAssertTrue(lifecycle.start())
        XCTAssertTrue(lifecycle.requestCancel())
        XCTAssertFalse(lifecycle.allowsStartupWork)
        XCTAssertEqual(lifecycle.terminationIntent, .cancel)
        XCTAssertTrue(lifecycle.complete())
        XCTAssertEqual(lifecycle.state, .idle)
    }

    func testPauseAndResumePreserveStartingAndActivePhases() {
        var lifecycle = RecordingLifecycle()

        XCTAssertTrue(lifecycle.start())
        XCTAssertTrue(lifecycle.pause())
        XCTAssertEqual(lifecycle.state, .paused)
        XCTAssertTrue(lifecycle.isPaused)
        XCTAssertTrue(lifecycle.resume())
        XCTAssertEqual(lifecycle.state, .recording)

        XCTAssertTrue(lifecycle.markCaptureStarted())
        XCTAssertTrue(lifecycle.pause())
        XCTAssertEqual(lifecycle.state, .paused)
        XCTAssertTrue(lifecycle.resume())
        XCTAssertEqual(lifecycle.state, .recording)
    }

    func testRepeatedStopIsIgnored() {
        var lifecycle = RecordingLifecycle()

        XCTAssertTrue(lifecycle.start())
        XCTAssertTrue(lifecycle.markCaptureStarted())
        XCTAssertTrue(lifecycle.requestStop())
        XCTAssertFalse(lifecycle.requestStop())
        XCTAssertEqual(lifecycle.terminationIntent, .finish)
    }

    func testStopWinsStopCancelRace() {
        var lifecycle = RecordingLifecycle()

        XCTAssertTrue(lifecycle.start())
        XCTAssertTrue(lifecycle.requestStop())
        XCTAssertFalse(lifecycle.requestCancel())
        XCTAssertEqual(lifecycle.terminationIntent, .finish)
    }

    func testCancelWinsCancelStopRace() {
        var lifecycle = RecordingLifecycle()

        XCTAssertTrue(lifecycle.start())
        XCTAssertTrue(lifecycle.requestCancel())
        XCTAssertFalse(lifecycle.requestStop())
        XCTAssertEqual(lifecycle.terminationIntent, .cancel)
    }

    func testInvalidTransitionsDoNotCreateASecondCompletionPath() {
        var lifecycle = RecordingLifecycle()

        XCTAssertFalse(lifecycle.pause())
        XCTAssertFalse(lifecycle.resume())
        XCTAssertFalse(lifecycle.requestStop())
        XCTAssertFalse(lifecycle.requestCancel())
        XCTAssertFalse(lifecycle.markCaptureStarted())
        XCTAssertFalse(lifecycle.complete())

        XCTAssertTrue(lifecycle.start())
        XCTAssertFalse(lifecycle.start())
        XCTAssertTrue(lifecycle.requestCancel())
        XCTAssertFalse(lifecycle.pause())
        XCTAssertFalse(lifecycle.resume())
        XCTAssertTrue(lifecycle.complete())
        XCTAssertFalse(lifecycle.complete())
    }
}
