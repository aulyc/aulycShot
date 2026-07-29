import AppKit
import XCTest
@testable import aulycShot

final class EditorOptionChromeTests: XCTestCase {
    func testSelectionColorMatchesCaptureSelectionChrome() {
        XCTAssertEqual(
            EditorOptionChrome.selectionColor,
            CaptureSelectionChrome.accentColor
        )
    }

    func testSizeSliderUsesUniformTwoPointTrack() {
        XCTAssertEqual(EditorOptionChrome.sliderTrackHeight, 2, accuracy: 0.001)
    }

    func testShapeFillSelectionUsesBlueOutlineWithoutBackgroundFill() {
        XCTAssertFalse(EditorOptionChrome.shapeFillSelectionDrawsBackground)
        XCTAssertEqual(EditorOptionChrome.shapeFillSelectionBorderWidth, 2, accuracy: 0.001)
    }

    func testLineWidthRangesUseCircularValueBadge() {
        XCTAssertTrue(
            EditorOptionChrome.usesCircularWidthValueBadge(
                minValue: Defaults.editorLineWidthMin,
                maxValue: Defaults.editorLineWidthMax
            )
        )
        XCTAssertTrue(
            EditorOptionChrome.usesCircularWidthValueBadge(
                minValue: Defaults.editorLineWidthMin,
                maxValue: Defaults.markerLineWidthMax
            )
        )
        XCTAssertEqual(
            EditorOptionChrome.lineWidthValueBadgeDiameter,
            HUDSlider.preferredHeight - 2,
            accuracy: 0.001
        )
    }

    func testNonLineWidthRangesKeepAdaptiveValueBadge() {
        XCTAssertFalse(
            EditorOptionChrome.usesCircularWidthValueBadge(
                minValue: Defaults.textFontSizeMin,
                maxValue: Defaults.textFontSizeMax
            )
        )
        XCTAssertFalse(
            EditorOptionChrome.usesCircularWidthValueBadge(
                minValue: Defaults.mosaicBlockSizeMin,
                maxValue: Defaults.mosaicBlockSizeMax
            )
        )
    }

    func testEllipseUsesOnlyDefaultStrokeStyleWithoutStyleControl() {
        XCTAssertFalse(EditWindowController.showsShapeStrokeStyleControl(for: .ellipse))
        for style in ShapeStrokeStyle.allCases {
            XCTAssertEqual(
                EditWindowController.normalizedShapeStrokeStyle(style, for: .ellipse),
                .standard
            )
        }
    }

    func testRectangleUsesOnlyDefaultStrokeStyleWithoutStyleControl() {
        XCTAssertFalse(EditWindowController.showsShapeStrokeStyleControl(for: .rectangle))
        for style in ShapeStrokeStyle.allCases {
            XCTAssertEqual(
                EditWindowController.normalizedShapeStrokeStyle(style, for: .rectangle),
                .standard
            )
        }
    }

    func testArrowUsesThirdStyleWithoutStyleControl() {
        XCTAssertFalse(EditWindowController.showsArrowStyleControl(for: .arrow))
        XCTAssertEqual(ArrowStyle.allCases[2], .line)
        for style in ArrowStyle.allCases {
            XCTAssertEqual(
                EditWindowController.normalizedArrowStyle(style, for: .arrow),
                .line
            )
        }
    }
}
