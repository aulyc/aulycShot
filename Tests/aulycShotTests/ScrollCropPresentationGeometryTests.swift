import AppKit
import XCTest
@testable import aulycShot

final class ScrollCropPresentationGeometryTests: XCTestCase {
    @MainActor
    func testCropPresentationCanSuppressFullscreenBackdrop() {
        let view = SelectionView(frame: NSRect(x: 0, y: 0, width: 1_440, height: 900))

        XCTAssertFalse(view.cropPresentationActive)
        view.cropPresentationActive = true
        XCTAssertTrue(view.cropPresentationActive)
        view.cropPresentationActive = false
        XCTAssertFalse(view.cropPresentationActive)
    }

    func testCropFrameIsLimitedToOriginalSelection() throws {
        let frame = try XCTUnwrap(ScrollCropPresentationGeometry.cropFrame(
            selectionRect: NSRect(x: 120, y: 80, width: 640, height: 720),
            hostBounds: NSRect(x: 0, y: 0, width: 1_440, height: 900)
        ))

        XCTAssertEqual(frame, NSRect(x: 120, y: 80, width: 640, height: 720))
    }

    func testCropFrameClipsToHostInsteadOfExpandingToFullScreen() throws {
        let frame = try XCTUnwrap(ScrollCropPresentationGeometry.cropFrame(
            selectionRect: NSRect(x: -30, y: 50, width: 500, height: 900),
            hostBounds: NSRect(x: 0, y: 0, width: 800, height: 600)
        ))

        XCTAssertEqual(frame, NSRect(x: 0, y: 50, width: 470, height: 550))
    }

    func testCropFrameRejectsSelectionOutsideHost() {
        XCTAssertNil(ScrollCropPresentationGeometry.cropFrame(
            selectionRect: NSRect(x: 900, y: 700, width: 100, height: 100),
            hostBounds: NSRect(x: 0, y: 0, width: 800, height: 600)
        ))
    }

    func testControlPrefersBelowSelection() {
        let origin = ScrollCropPresentationGeometry.controlOrigin(
            anchorRect: NSRect(x: 200, y: 200, width: 400, height: 300),
            visibleFrame: NSRect(x: 0, y: 0, width: 1_000, height: 800)
        )

        XCTAssertEqual(origin, NSPoint(x: 372, y: 144))
    }

    func testControlMovesAboveSelectionWhenBottomSpaceIsUnavailable() {
        let origin = ScrollCropPresentationGeometry.controlOrigin(
            anchorRect: NSRect(x: 40, y: 20, width: 300, height: 240),
            visibleFrame: NSRect(x: 0, y: 0, width: 600, height: 500)
        )

        XCTAssertEqual(origin, NSPoint(x: 162, y: 272))
    }

    func testControlStaysVisibleForNearlyFullScreenSelection() {
        let visibleFrame = NSRect(x: 100, y: 20, width: 500, height: 320)
        let size = ScrollCropPresentationGeometry.controlSize
        let origin = ScrollCropPresentationGeometry.controlOrigin(
            anchorRect: NSRect(x: 100, y: 20, width: 500, height: 320),
            visibleFrame: visibleFrame
        )
        let controlFrame = NSRect(origin: origin, size: size)

        XCTAssertTrue(visibleFrame.insetBy(dx: 12, dy: 12).contains(controlFrame))
    }

    func testControlClampsHorizontallyNearScreenEdge() {
        let origin = ScrollCropPresentationGeometry.controlOrigin(
            anchorRect: NSRect(x: 0, y: 200, width: 20, height: 100),
            visibleFrame: NSRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin.x, 12)
    }
}
