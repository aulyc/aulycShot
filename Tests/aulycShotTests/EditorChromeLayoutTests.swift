import AppKit
import XCTest
@testable import aulycShot

final class EditorChromeLayoutTests: XCTestCase {
    private let bounds = NSRect(x: 0, y: 0, width: 500, height: 400)

    func testPrimaryToolbarPrefersBelowSelectionAndCentersHorizontally() {
        let layout = EditorChromeLayout(
            selectionRect: NSRect(x: 150, y: 150, width: 200, height: 100)
        )

        XCTAssertEqual(
            layout.toolbarRect(in: bounds, size: NSSize(width: 100, height: 36)),
            NSRect(x: 200, y: 106, width: 100, height: 36)
        )
    }

    func testPrimaryToolbarFlipsAboveSelectionAndClampsToLeftMargin() {
        let layout = EditorChromeLayout(
            selectionRect: NSRect(x: -20, y: 10, width: 40, height: 100)
        )

        XCTAssertEqual(
            layout.toolbarRect(in: bounds, size: NSSize(width: 100, height: 36)),
            NSRect(x: 8, y: 118, width: 100, height: 36)
        )
    }

    func testSideToolbarFlipsLeftAtRightEdge() {
        let layout = EditorChromeLayout(
            selectionRect: NSRect(x: 300, y: 100, width: 180, height: 100)
        )

        XCTAssertEqual(
            layout.sideToolbarRect(in: bounds, size: NSSize(width: 40, height: 120)),
            NSRect(x: 252, y: 90, width: 40, height: 120)
        )
    }

    func testSideToolbarMovesAboveIntersectingPrimaryToolbar() {
        let layout = EditorChromeLayout(
            selectionRect: NSRect(x: 100, y: 100, width: 200, height: 100)
        )

        XCTAssertEqual(
            layout.sideToolbarRect(
                in: bounds,
                size: NSSize(width: 40, height: 120),
                avoiding: NSRect(x: 300, y: 70, width: 120, height: 36)
            ),
            NSRect(x: 308, y: 114, width: 40, height: 120)
        )
    }

    func testSubToolbarFlipsAbovePrimaryNearBottomEdge() {
        let layout = EditorChromeLayout(selectionRect: .zero)

        XCTAssertEqual(
            layout.subToolbarRect(
                width: 140,
                height: 36,
                toolbarFrame: NSRect(x: 200, y: 20, width: 100, height: 36),
                in: bounds
            ),
            NSRect(x: 180, y: 60, width: 140, height: 36)
        )
    }
}
