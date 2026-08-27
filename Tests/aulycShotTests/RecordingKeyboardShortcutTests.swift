import AppKit
import XCTest
@testable import aulycShot

@MainActor
final class RecordingKeyboardShortcutTests: XCTestCase {
    func testPlainReturnStopsRecordingForMainAndNumericKeyboards() throws {
        let mainReturn = try makeKeyEvent(keyCode: 36, characters: "\r")
        let numericReturn = try makeKeyEvent(
            keyCode: 76,
            characters: "\r",
            modifiers: [.numericPad]
        )

        XCTAssertTrue(RecordingSessionController.isPlainReturn(mainReturn))
        XCTAssertTrue(RecordingSessionController.isPlainReturn(numericReturn))
    }

    func testModifiedReturnDoesNotStopRecording() throws {
        for modifier: NSEvent.ModifierFlags in [.command, .shift, .option, .control] {
            let event = try makeKeyEvent(
                keyCode: 36,
                characters: "\r",
                modifiers: modifier
            )
            XCTAssertFalse(RecordingSessionController.isPlainReturn(event))
        }
    }

    func testPlainEscapeStillCancelsRecording() throws {
        let escape = try makeKeyEvent(keyCode: 53, characters: "\u{1b}")

        XCTAssertTrue(RecordingSessionController.isPlainEscape(escape))
        XCTAssertFalse(RecordingSessionController.isPlainReturn(escape))
    }

    func testCancelledCompletionWinsAndPreservesTemporaryURLForCleanup() throws {
        let url = URL(fileURLWithPath: "/tmp/aulycshot-cancelled.mp4")
        let completion = RecordingSessionController.resolveCompletion(
            cancelRequested: true,
            url: url,
            error: NSError(domain: "test", code: 1)
        )

        guard case .cancelled(let resolvedURL) = completion else {
            return XCTFail("Expected cancelled completion")
        }
        XCTAssertEqual(resolvedURL, url)
    }

    func testSuccessfulAndMissingFrameCompletionsStayDistinct() {
        let url = URL(fileURLWithPath: "/tmp/aulycshot-completed.mp4")
        guard case .completed(let resolvedURL) = RecordingSessionController.resolveCompletion(
            cancelRequested: false,
            url: url,
            error: nil
        ) else {
            return XCTFail("Expected completed recording")
        }
        XCTAssertEqual(resolvedURL, url)

        guard case .failed(let error) = RecordingSessionController.resolveCompletion(
            cancelRequested: false,
            url: nil,
            error: nil
        ) else {
            return XCTFail("Expected missing-frame failure")
        }
        XCTAssertEqual(
            error.localizedDescription,
            RecordingEngine.RecordingError.noFrames.localizedDescription
        )
    }

    private func makeKeyEvent(
        keyCode: UInt16,
        characters: String,
        modifiers: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: keyCode
            )
        )
    }
}
