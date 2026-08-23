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

        XCTAssertTrue(AppDelegate.isPlainReturn(mainReturn))
        XCTAssertTrue(AppDelegate.isPlainReturn(numericReturn))
    }

    func testModifiedReturnDoesNotStopRecording() throws {
        for modifier: NSEvent.ModifierFlags in [.command, .shift, .option, .control] {
            let event = try makeKeyEvent(
                keyCode: 36,
                characters: "\r",
                modifiers: modifier
            )
            XCTAssertFalse(AppDelegate.isPlainReturn(event))
        }
    }

    func testPlainEscapeStillCancelsRecording() throws {
        let escape = try makeKeyEvent(keyCode: 53, characters: "\u{1b}")

        XCTAssertTrue(AppDelegate.isPlainEscape(escape))
        XCTAssertFalse(AppDelegate.isPlainReturn(escape))
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
