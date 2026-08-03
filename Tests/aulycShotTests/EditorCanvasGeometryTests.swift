import AppKit
import XCTest
@testable import aulycShot

final class EditorCanvasGeometryTests: XCTestCase {
    func testRectFromTwoPointsNormalizesBothAxes() {
        XCTAssertEqual(
            EditorCanvasGeometry.rectFromTwoPoints(
                NSPoint(x: 30, y: 10),
                NSPoint(x: 5, y: 40)
            ),
            NSRect(x: 5, y: 10, width: 25, height: 30)
        )
    }

    func testShiftConstrainsLinesToDominantAxisAndShapesToSquare() {
        XCTAssertEqual(
            EditorCanvasGeometry.constrainedShapeEnd(
                from: NSPoint(x: 10, y: 10),
                to: NSPoint(x: 50, y: 30),
                tool: .line,
                modifiers: .shift
            ),
            NSPoint(x: 50, y: 10)
        )
        XCTAssertEqual(
            EditorCanvasGeometry.constrainedShapeEnd(
                from: NSPoint(x: 10, y: 10),
                to: NSPoint(x: -10, y: 40),
                tool: .rectangle,
                modifiers: .shift
            ),
            NSPoint(x: -20, y: 40)
        )
    }

    func testSelectionChromePointRotatesAroundBoundingRectCenter() {
        let point = EditorCanvasGeometry.rotated(
            NSPoint(x: 2, y: 1),
            around: NSRect(x: 0, y: 0, width: 2, height: 2),
            rotation: .pi / 2
        )

        XCTAssertEqual(point.x, 1, accuracy: 0.000_001)
        XCTAssertEqual(point.y, 2, accuracy: 0.000_001)
    }

    func testCanvasClampKeepsPointInsideEveryEdge() {
        XCTAssertEqual(
            EditorCanvasGeometry.clamped(
                NSPoint(x: -5, y: 120),
                to: NSRect(x: 0, y: 0, width: 100, height: 80)
            ),
            NSPoint(x: 0, y: 80)
        )
    }

    func testUnrotatedCornerResizeKeepsOppositeCornerFixed() {
        XCTAssertEqual(
            EditorCanvasGeometry.resizedRect(
                from: NSRect(x: 10, y: 20, width: 100, height: 50),
                anchor: .topRight,
                currentMouse: NSPoint(x: 130, y: 90),
                minimumSize: 4
            ),
            NSRect(x: 10, y: 20, width: 120, height: 70)
        )
    }

    func testRotatedEdgeResizeWorksInAnnotationLocalCoordinates() {
        let result = EditorCanvasGeometry.resizedRotatedRect(
            from: NSRect(x: 0, y: 0, width: 100, height: 50),
            rotation: .pi / 2,
            anchor: .right,
            currentMouse: NSPoint(x: 50, y: 125),
            minimumSize: 4
        )

        assertRect(result, equals: NSRect(x: -25, y: 25, width: 150, height: 50))
    }

    func testResizeConstraintsPreserveAspectRatioOrMakeSquare() {
        let aspect = EditorCanvasGeometry.resizedRotatedRect(
            from: NSRect(x: 0, y: 0, width: 100, height: 50),
            rotation: 0,
            anchor: .right,
            currentMouse: NSPoint(x: 200, y: 25),
            minimumSize: 4,
            constraint: .preserveAspectRatio
        )
        let square = EditorCanvasGeometry.resizedRotatedRect(
            from: NSRect(x: 0, y: 0, width: 100, height: 50),
            rotation: 0,
            anchor: .topRight,
            currentMouse: NSPoint(x: 120, y: 80),
            minimumSize: 4,
            constraint: .square
        )

        assertRect(aspect, equals: NSRect(x: 0, y: -25, width: 200, height: 100))
        assertRect(square, equals: NSRect(x: 0, y: 0, width: 120, height: 120))
    }

    private func assertRect(
        _ actual: NSRect,
        equals expected: NSRect,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.000_001, file: file, line: line)
    }
}
