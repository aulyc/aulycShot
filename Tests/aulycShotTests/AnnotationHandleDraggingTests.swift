import AppKit
import XCTest
@testable import aulycShot

final class AnnotationHandleDraggingTests: XCTestCase {
    func testRotationUsesTheDragStartAngle() throws {
        let annotation = rectangle()
        let center = NSPoint(x: annotation.rect.midX, y: annotation.rect.midY)
        let result = try transformed(
            annotation,
            handle: .rotate,
            currentMouse: NSPoint(x: center.x, y: center.y + 100),
            startAngle: 0
        ) as? RectAnnotation

        XCTAssertEqual(try XCTUnwrap(result).rotation, .pi / 2, accuracy: 0.0001)
    }

    func testShiftRotationSnapsToFifteenDegreeSteps() throws {
        let annotation = rectangle()
        let center = NSPoint(x: annotation.rect.midX, y: annotation.rect.midY)
        let angle = CGFloat.pi / 9
        let result = try transformed(
            annotation,
            handle: .rotate,
            currentMouse: NSPoint(
                x: center.x + cos(angle) * 100,
                y: center.y + sin(angle) * 100
            ),
            startAngle: 0,
            shiftPressed: true
        ) as? RectAnnotation

        XCTAssertEqual(try XCTUnwrap(result).rotation, .pi / 12, accuracy: 0.0001)
    }

    func testCurveHandleSnapsBackToStraightNearItsMidpoint() throws {
        let arrow = ArrowAnnotation(
            startPoint: NSPoint(x: 20, y: 20),
            endPoint: NSPoint(x: 180, y: 100),
            color: .systemRed,
            lineWidth: 4,
            controlPoint: NSPoint(x: 80, y: 30)
        )
        let result = try transformed(
            arrow,
            handle: .curve,
            currentMouse: arrow.defaultCurveMid
        ) as? ArrowAnnotation

        XCTAssertNil(try XCTUnwrap(result).controlPoint)
    }

    func testNumberTipInsideBadgeRemovesTheArrow() throws {
        let number = NumberAnnotation(
            center: NSPoint(x: 100, y: 100),
            tip: NSPoint(x: 160, y: 100),
            number: 1,
            color: .systemRed
        )
        let result = try transformed(
            number,
            handle: .tip,
            currentMouse: NSPoint(x: 102, y: 100)
        ) as? NumberAnnotation

        XCTAssertNil(try XCTUnwrap(result).tip)
    }

    func testRectangleResizePreservesStyleAndChangesGeometry() throws {
        let annotation = rectangle()
        let result = try transformed(
            annotation,
            handle: .resize(.topRight),
            currentMouse: NSPoint(x: 180, y: 140)
        ) as? RectAnnotation
        let resized = try XCTUnwrap(result)

        XCTAssertNotEqual(resized.rect, annotation.rect)
        XCTAssertEqual(resized.color, annotation.color)
        XCTAssertEqual(resized.lineWidth, annotation.lineWidth)
        XCTAssertEqual(resized.fillMode, annotation.fillMode)
        XCTAssertEqual(resized.strokeStyle, annotation.strokeStyle)
    }

    func testMosaicResizeRequiresTheUntouchedBaseImage() {
        let mosaic = MosaicAnnotation(
            rect: NSRect(x: 20, y: 20, width: 80, height: 60),
            pixelatedImage: NSImage(size: NSSize(width: 80, height: 60)),
            blockSize: 12
        )

        XCTAssertNil(AnnotationHandleDragging.transformedAnnotation(
            from: mosaic,
            handle: .resize(.topRight),
            currentMouse: NSPoint(x: 180, y: 140),
            startAngle: 0,
            startRotation: 0,
            context: context()
        ))
    }

    private func transformed(
        _ annotation: Annotation,
        handle: AnnotationHitTesting.Handle,
        currentMouse: NSPoint,
        startAngle: CGFloat = 0,
        shiftPressed: Bool = false
    ) throws -> Annotation {
        try XCTUnwrap(AnnotationHandleDragging.transformedAnnotation(
            from: annotation,
            handle: handle,
            currentMouse: currentMouse,
            startAngle: startAngle,
            startRotation: annotation.rotation,
            context: context(shiftPressed: shiftPressed)
        ))
    }

    private func context(shiftPressed: Bool = false) -> AnnotationHandleDragging.Context {
        AnnotationHandleDragging.Context(
            canvasBounds: NSRect(x: 0, y: 0, width: 500, height: 400),
            shiftPressed: shiftPressed,
            baseImage: nil
        )
    }

    private func rectangle() -> RectAnnotation {
        RectAnnotation(
            rect: NSRect(x: 20, y: 20, width: 100, height: 60),
            color: .systemRed,
            lineWidth: 4,
            fillMode: .translucent,
            strokeStyle: .rounded,
            roughStyle: RoughShapeStyle(seed: 42, roughness: 0.2)
        )
    }
}
