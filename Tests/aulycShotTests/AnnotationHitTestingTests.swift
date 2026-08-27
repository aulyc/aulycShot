import AppKit
import XCTest
@testable import aulycShot

final class AnnotationHitTestingTests: XCTestCase {
    func testEmptyAnnotationsHaveNoHit() {
        XCTAssertNil(AnnotationHitTesting.topmostIndex(at: .zero, in: []))
    }

    func testPointOutsideEveryAnnotationHasNoHit() {
        let annotations: [Annotation] = [filledRect(x: 10)]

        XCTAssertNil(AnnotationHitTesting.topmostIndex(at: NSPoint(x: 200, y: 200), in: annotations))
    }

    func testTopmostMatchingAnnotationWins() {
        let annotations: [Annotation] = [filledRect(x: 0), filledRect(x: 20), filledRect(x: 0)]

        XCTAssertEqual(
            AnnotationHitTesting.topmostIndex(at: NSPoint(x: 30, y: 30), in: annotations),
            2
        )
    }

    func testReturnsExistingArrayIndexRatherThanInventingIdentity() {
        let annotations: [Annotation] = [filledRect(x: 100), filledRect(x: 0), filledRect(x: 200)]

        XCTAssertEqual(
            AnnotationHitTesting.topmostIndex(at: NSPoint(x: 30, y: 30), in: annotations),
            1
        )
    }

    func testHandlePolicyKeepsResizeAndRotationGeometryInOnePlace() {
        let annotation = RectAnnotation(
            rect: NSRect(x: 20, y: 30, width: 80, height: 40),
            color: .systemRed,
            lineWidth: 2,
            rotation: .pi / 2
        )

        XCTAssertTrue(AnnotationHandlePolicy.isResizable(annotation))
        XCTAssertEqual(
            AnnotationHandlePolicy.selectionBox(for: annotation),
            NSRect(x: 14, y: 24, width: 92, height: 52)
        )
        XCTAssertEqual(
            AnnotationHandlePolicy.resizeHandlePoint(.topLeft, for: annotation),
            EditorCanvasGeometry.resizeHandlePoint(
                .topLeft,
                boundingRect: annotation.boundingRect,
                rotation: annotation.rotation
            )
        )
        XCTAssertEqual(
            AnnotationHandlePolicy.rotationHandleCenter(for: annotation),
            EditorCanvasGeometry.rotated(
                NSPoint(x: 60, y: 98),
                around: annotation.boundingRect,
                rotation: annotation.rotation
            )
        )
    }

    func testHandlePolicyUsesExplicitHitSlopAroundCircularHandles() {
        let center = NSPoint(x: 30, y: 40)

        XCTAssertTrue(
            AnnotationHandlePolicy.contains(
                NSPoint(x: 39, y: 40),
                around: center,
                handleSize: 10,
                hitSlop: 4
            )
        )
        XCTAssertFalse(
            AnnotationHandlePolicy.contains(
                NSPoint(x: 39.1, y: 40),
                around: center,
                handleSize: 10,
                hitSlop: 4
            )
        )
    }

    func testChromeHitRoutesDeleteButtonThroughTheUnifiedEntryPoint() {
        let annotation = filledRect(x: 20)
        let button = AnnotationHandlePolicy.deleteButtonRect(for: annotation)

        XCTAssertEqual(
            AnnotationHitTesting.chromeHit(
                at: NSPoint(x: button.midX, y: button.midY),
                for: annotation
            ),
            .action(.delete)
        )
    }

    func testChromeHitCanExcludeActionsForShiftSelection() {
        let annotation = filledRect(x: 20)
        let button = AnnotationHandlePolicy.deleteButtonRect(for: annotation)

        XCTAssertNil(AnnotationHitTesting.chromeHit(
            at: NSPoint(x: button.midX, y: button.midY),
            for: annotation,
            includeActions: false
        ))
    }

    func testChromeHitRoutesResizeHandlesThroughTheUnifiedEntryPoint() {
        let annotation = filledRect(x: 20)
        let center = AnnotationHandlePolicy.resizeHandlePoint(.topLeft, for: annotation)

        XCTAssertEqual(
            AnnotationHitTesting.chromeHit(at: center, for: annotation),
            .handle(.resize(.topLeft))
        )
    }

    func testChromeRendererDrawsSelectionOutlineIntoItsContext() throws {
        let width = 120
        let height = 120
        let bytesPerRow = width * 4
        let pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow * height)
        pixels.initialize(repeating: 0, count: bytesPerRow * height)
        defer { pixels.deallocate() }
        let context = try XCTUnwrap(CGContext(
            data: pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let annotation = filledRect(x: 20)

        AnnotationChromeRenderer.drawSelectionOutline(for: annotation, in: context)

        XCTAssertTrue((0..<(bytesPerRow * height)).contains { pixels[$0] != 0 })
    }

    private func filledRect(x: CGFloat) -> RectAnnotation {
        RectAnnotation(
            rect: NSRect(x: x, y: 0, width: 80, height: 80),
            color: .systemRed,
            lineWidth: 2,
            filled: true
        )
    }
}
