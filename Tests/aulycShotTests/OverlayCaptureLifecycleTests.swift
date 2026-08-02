import AppKit
import XCTest
@testable import aulycShot

@MainActor
final class OverlayCaptureLifecycleTests: XCTestCase {
    func testEscapeCancelsOnlyWhenDeliveredToOverlayApplication() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: 53
            )
        )

        XCTAssertTrue(
            OverlayCancellationPolicy.shouldCancel(
                event,
                deliveryScope: .overlayApplication,
                isTextEditing: false
            )
        )
        XCTAssertFalse(
            OverlayCancellationPolicy.shouldCancel(
                event,
                deliveryScope: .outsideApplication,
                isTextEditing: false
            )
        )
    }

    func testRightClickCancelsOnlyWhenDeliveredToOverlayApplication() throws {
        let event = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )

        XCTAssertTrue(
            OverlayCancellationPolicy.shouldCancel(
                event,
                deliveryScope: .overlayApplication,
                isTextEditing: false
            )
        )
        XCTAssertFalse(
            OverlayCancellationPolicy.shouldCancel(
                event,
                deliveryScope: .outsideApplication,
                isTextEditing: false
            )
        )
    }

    func testTextEditingKeepsEscapeAndRightClickAvailableToEditor() throws {
        let escape = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\u{1b}",
                charactersIgnoringModifiers: "\u{1b}",
                isARepeat: false,
                keyCode: 53
            )
        )
        let rightClick = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )

        XCTAssertFalse(
            OverlayCancellationPolicy.shouldCancel(
                escape,
                deliveryScope: .overlayApplication,
                isTextEditing: true
            )
        )
        XCTAssertFalse(
            OverlayCancellationPolicy.shouldCancel(
                rightClick,
                deliveryScope: .overlayApplication,
                isTextEditing: true
            )
        )
    }

    func testCapturePresentationPolicyStaysAboveOrdinaryApplications() {
        XCTAssertEqual(OverlayPresentationPolicy.windowLevel, .screenSaver)
        XCTAssertFalse(OverlayPresentationPolicy.hidesOnDeactivate)
        XCTAssertTrue(OverlayPresentationPolicy.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(OverlayPresentationPolicy.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}
