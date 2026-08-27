import Carbon
import CoreGraphics
import XCTest
@testable import aulycShot

@MainActor
final class StatusMenuScreenshotPreflightTests: XCTestCase {
    func testMatchingShortcutRequestsSynchronousCaptureAndSwallow() {
        XCTAssertEqual(
            StatusMenuScreenshotEventPolicy.disposition(
                eventType: .keyDown,
                keyCode: UInt32(kVK_ANSI_3),
                flags: [.maskCommand],
                configuredHotkey: (
                    keyCode: UInt32(kVK_ANSI_3),
                    modifiers: UInt32(cmdKey)
                )
            ),
            .swallowAndCapture
        )
    }

    func testDisabledTapRequestsReenableAndPassthrough() {
        XCTAssertEqual(
            StatusMenuScreenshotEventPolicy.disposition(
                eventType: .tapDisabledByTimeout,
                keyCode: 0,
                flags: [],
                configuredHotkey: nil
            ),
            .reenableAndPassthrough
        )
    }

    func testCaptureDispositionDisablesTapAndCapturesBeforeReturningSwallow() {
        var events: [String] = []

        let shouldSwallow = StatusMenuScreenshotEventPolicy.perform(
            .swallowAndCapture,
            reenableTap: { events.append("reenable") },
            disableTap: { events.append("disable") },
            capture: { events.append("capture") }
        )

        XCTAssertTrue(shouldSwallow)
        XCTAssertEqual(events, ["disable", "capture"])
    }

    func testReenableDispositionReenablesTapAndReturnsPassthrough() {
        var events: [String] = []

        let shouldSwallow = StatusMenuScreenshotEventPolicy.perform(
            .reenableAndPassthrough,
            reenableTap: { events.append("reenable") },
            disableTap: { events.append("disable") },
            capture: { events.append("capture") }
        )

        XCTAssertFalse(shouldSwallow)
        XCTAssertEqual(events, ["reenable"])
    }

    func testConfiguredScreenshotShortcutIsCapturedAtSystemEventTap() {
        XCTAssertTrue(
            StatusMenuScreenshotEventPolicy.shouldCapture(
                eventType: .keyDown,
                keyCode: UInt32(kVK_ANSI_3),
                flags: [.maskCommand],
                configuredHotkey: (
                    keyCode: UInt32(kVK_ANSI_3),
                    modifiers: UInt32(cmdKey)
                )
            )
        )
    }

    func testChangedScreenshotShortcutIsUsedInsteadOfHardCodedCommandThree() {
        let configuredHotkey = (
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(cmdKey | shiftKey)
        )

        XCTAssertTrue(
            StatusMenuScreenshotEventPolicy.shouldCapture(
                eventType: .keyDown,
                keyCode: UInt32(kVK_ANSI_X),
                flags: [.maskCommand, .maskShift],
                configuredHotkey: configuredHotkey
            )
        )
        XCTAssertFalse(
            StatusMenuScreenshotEventPolicy.shouldCapture(
                eventType: .keyDown,
                keyCode: UInt32(kVK_ANSI_3),
                flags: [.maskCommand],
                configuredHotkey: configuredHotkey
            )
        )
    }

    func testWrongModifiersAreNotCaptured() {
        XCTAssertFalse(
            StatusMenuScreenshotEventPolicy.shouldCapture(
                eventType: .keyDown,
                keyCode: UInt32(kVK_ANSI_3),
                flags: [.maskCommand, .maskShift],
                configuredHotkey: (
                    keyCode: UInt32(kVK_ANSI_3),
                    modifiers: UInt32(cmdKey)
                )
            )
        )
    }

    func testMouseEventsRemainRegularMenuInput() {
        XCTAssertFalse(
            StatusMenuScreenshotEventPolicy.shouldCapture(
                eventType: .leftMouseUp,
                keyCode: UInt32(kVK_ANSI_3),
                flags: [.maskCommand],
                configuredHotkey: (
                    keyCode: UInt32(kVK_ANSI_3),
                    modifiers: UInt32(cmdKey)
                )
            )
        )
    }

    func testUnconfiguredScreenshotShortcutIsNotCaptured() {
        XCTAssertFalse(
            StatusMenuScreenshotEventPolicy.shouldCapture(
                eventType: .keyDown,
                keyCode: UInt32(kVK_ANSI_3),
                flags: [.maskCommand],
                configuredHotkey: nil
            )
        )
    }

    func testStatusMenuTransitionShowsFrozenOverlayBeforeClosingMenuOnce() {
        var events: [String] = []
        let dismissal = CaptureEventTrackingDismissal {
            events.append("close-menu")
        }

        OverlayEventTrackingTransition.perform(
            statusMenuDismissal: dismissal,
            presentOverlay: {
                events.append("present-overlay")
            },
            dismissUnknownSurface: {
                events.append("dismiss-unknown-surface")
            },
            scheduleOverlay: { _ in
                events.append("schedule-overlay")
            }
        )
        dismissal.perform()

        XCTAssertEqual(events, ["present-overlay", "close-menu"])
    }

    func testUnknownTrackingSurfaceKeepsGenericDismissalFallback() {
        var events: [String] = []
        var scheduledPresentation: (() -> Void)?

        OverlayEventTrackingTransition.perform(
            statusMenuDismissal: nil,
            presentOverlay: {
                events.append("present-overlay")
            },
            dismissUnknownSurface: {
                events.append("dismiss-unknown-surface")
            },
            scheduleOverlay: { presentation in
                events.append("schedule-overlay")
                scheduledPresentation = presentation
            }
        )

        XCTAssertEqual(events, ["dismiss-unknown-surface", "schedule-overlay"])
        scheduledPresentation?()
        XCTAssertEqual(
            events,
            ["dismiss-unknown-surface", "schedule-overlay", "present-overlay"]
        )
    }
}
