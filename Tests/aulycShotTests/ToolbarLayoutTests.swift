import AppKit
import XCTest
@testable import aulycShot

final class ToolbarLayoutTests: XCTestCase {
    override func tearDown() {
        ToolbarTooltipHoverGate.reset()
        super.tearDown()
    }

    func testMosaicUsesPixelatedTileSymbol() {
        XCTAssertEqual(ToolbarItemID.mosaic.symbolName, "squareshape.split.3x3")
    }

    func testTextToolUsesLiteralTInsteadOfLocalizedFormatSymbol() {
        XCTAssertEqual(ToolbarItemID.text.toolbarLetterGlyph, "T")
        XCTAssertNotEqual(ToolbarItemID.text.symbolName, "textformat")
        XCTAssertNotNil(ToolbarItemID.text.toolbarIconImage(pointSize: 14))
        XCTAssertNil(ToolbarItemID.rectangle.toolbarLetterGlyph)
    }

    func testRemovedItemsAreDroppedFromPersistedLayout() {
        let layout = ToolbarLayout(dictionary: [
            "primary": ["rectangle", "moveSelection", "ocr", "beautify", "colorPicker", "ellipse"],
            "side": ["save"],
            "hidden": [],
        ]).normalized()

        let rawValues = layout.dictionary.values.flatMap { $0 }
        XCTAssertFalse(rawValues.contains("moveSelection"))
        XCTAssertFalse(rawValues.contains("ocr"))
        XCTAssertFalse(rawValues.contains("beautify"))
        XCTAssertFalse(rawValues.contains("colorPicker"))
        XCTAssertTrue(rawValues.contains("magnifier"))
        XCTAssertEqual(Set(rawValues), Set(ToolbarItemID.allCases.map(\.rawValue)))
    }

    func testSelectionBorderHitTestingClaimsOnlyTheEdgeBand() {
        let rect = NSRect(x: 100, y: 80, width: 300, height: 200)

        XCTAssertTrue(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.midX, y: rect.minY),
                rect: rect,
                hitSize: 7
            )
        )
        XCTAssertTrue(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.maxX + 4, y: rect.midY),
                rect: rect,
                hitSize: 7
            )
        )
        XCTAssertFalse(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.midX, y: rect.midY),
                rect: rect,
                hitSize: 7
            )
        )
        XCTAssertFalse(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.maxX + 8, y: rect.midY),
                rect: rect,
                hitSize: 7
            )
        )
    }

    func testScrollingSuppressesHoverWhilePointerRemainsStationary() {
        let pointer = NSPoint(x: 240, y: 180)

        ToolbarTooltipHoverGate.suppressForScroll(at: pointer)

        XCTAssertFalse(ToolbarTooltipHoverGate.permitsHover(at: pointer))
        XCTAssertFalse(
            ToolbarTooltipHoverGate.resumeAfterMouseMove(
                at: NSPoint(x: pointer.x + 0.5, y: pointer.y)
            )
        )
    }

    func testHoverResumesAfterPointerActuallyMoves() {
        let pointer = NSPoint(x: 240, y: 180)
        ToolbarTooltipHoverGate.suppressForScroll(at: pointer)

        XCTAssertTrue(
            ToolbarTooltipHoverGate.resumeAfterMouseMove(
                at: NSPoint(x: pointer.x + 2, y: pointer.y)
            )
        )
        XCTAssertTrue(ToolbarTooltipHoverGate.permitsHover(at: pointer))
    }
}
