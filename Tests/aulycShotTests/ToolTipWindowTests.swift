import AppKit
import XCTest
@testable import aulycShot

final class ToolTipWindowTests: XCTestCase {
    func testTooltipBelongsToOwnerFollowsAnchorAndDetachesWhenAppDeactivates() throws {
        _ = NSApplication.shared

        let owner = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        owner.alphaValue = 0
        owner.orderFront(nil)
        defer {
            ToolTipWindow.hide()
            owner.close()
        }

        let initialAnchor = NSRect(x: -9_800, y: -9_800, width: 24, height: 24)
        ToolTipWindow.show(
            text: "Text (T)",
            anchor: initialAnchor,
            relativeTo: owner,
            delay: 0
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let tooltip = try XCTUnwrap(owner.childWindows?.first)
        XCTAssertEqual(tooltip.parent, owner)
        XCTAssertEqual(tooltip.level, owner.level)
        XCTAssertFalse(tooltip.collectionBehavior.contains(.canJoinAllSpaces))

        let initialOrigin = tooltip.frame.origin
        ToolTipWindow.updateAnchor(
            NSRect(x: -9_700, y: -9_700, width: 24, height: 24),
            relativeTo: owner
        )
        XCTAssertNotEqual(tooltip.frame.origin, initialOrigin)

        NotificationCenter.default.post(
            name: NSApplication.didResignActiveNotification,
            object: NSApplication.shared
        )
        XCTAssertNil(tooltip.parent)
        XCTAssertFalse(tooltip.isVisible)
        XCTAssertTrue(owner.childWindows?.isEmpty ?? true)
    }
}
