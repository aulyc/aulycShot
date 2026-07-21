import AppKit
import XCTest
@testable import aulycShot

final class AboutActionHitTargetTests: XCTestCase {
    func testContentSizedButtonIgnoresBlankAreaOutsideItsContent() {
        let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 440, height: 28))
        let content = NSView(frame: NSRect(x: 112, y: 4, width: 160, height: 20))
        button.addSubview(content)
        button.interactiveContentView = content

        XCTAssertIdentical(button.hitTest(NSPoint(x: 150, y: 14)), button)
        XCTAssertNil(button.hitTest(NSPoint(x: 360, y: 14)))
        XCTAssertFalse(button.interactiveBounds.contains(NSPoint(x: 360, y: 14)))
    }

    func testOtherHoverButtonsKeepTheirFullBoundsInteractive() {
        let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 220, height: 44))

        XCTAssertEqual(button.interactiveBounds, button.bounds)
        XCTAssertIdentical(button.hitTest(NSPoint(x: 210, y: 22)), button)
    }

    func testHoverButtonTracksCursorUpdatesAcrossItsInteractiveBounds() {
        let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 440, height: 28))
        let content = NSView(frame: NSRect(x: 112, y: 4, width: 160, height: 20))
        button.addSubview(content)
        button.interactiveContentView = content

        button.updateTrackingAreas()

        XCTAssertTrue(button.trackingAreas.contains { area in
            area.options.contains(.cursorUpdate)
        })
    }
}
