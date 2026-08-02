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

    private func filledRect(x: CGFloat) -> RectAnnotation {
        RectAnnotation(
            rect: NSRect(x: x, y: 0, width: 80, height: 80),
            color: .systemRed,
            lineWidth: 2,
            filled: true
        )
    }
}
