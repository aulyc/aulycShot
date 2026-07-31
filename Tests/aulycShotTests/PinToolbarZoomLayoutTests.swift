import AppKit
import XCTest
@testable import aulycShot

final class PinToolbarZoomLayoutTests: XCTestCase {
    func testZoomControlsUsePlainMinusAndPlusSymbols() {
        XCTAssertEqual(PinToolbarZoomLayout.zoomOutSymbolName, "minus")
        XCTAssertEqual(PinToolbarZoomLayout.zoomInSymbolName, "plus")
    }

    func testZoomControlsStayCompactAndCentered() {
        let availableRect = NSRect(x: 40, y: 0, width: 146, height: 34)
        let layout = PinToolbarZoomLayout.make(
            availableRect: availableRect,
            buttonY: 3,
            buttonSide: 28
        )

        XCTAssertEqual(layout.zoomOutFrame.maxX, layout.labelFrame.minX)
        XCTAssertEqual(layout.labelFrame.maxX, layout.zoomInFrame.minX)
        XCTAssertEqual(layout.labelFrame.width, 44)
        XCTAssertEqual(layout.zoomOutFrame.minX, 67)
        XCTAssertEqual(layout.zoomInFrame.maxX, 159)
        XCTAssertEqual(
            (layout.zoomOutFrame.minX + layout.zoomInFrame.maxX) / 2,
            availableRect.midX
        )
    }
}
