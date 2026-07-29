import AppKit
import XCTest
@testable import aulycShot

final class EditorCursorRoutingPolicyTests: XCTestCase {
    private let selectionRect = NSRect(x: 100, y: 100, width: 400, height: 300)

    func testLockedEditorRoutesInsideSelectionToActiveAnnotationTool() {
        let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: true,
            selectionLocked: true,
            annotationToolActive: true,
            selectionRect: selectionRect,
            point: NSPoint(x: 250, y: 200),
            isOverSelectionHandle: false
        )

        XCTAssertEqual(route, .annotationTool)
    }

    func testLockedEditorRoutesOutsideSelectionToArrow() {
        let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: true,
            selectionLocked: true,
            annotationToolActive: true,
            selectionRect: selectionRect,
            point: NSPoint(x: 50, y: 50),
            isOverSelectionHandle: false
        )

        XCTAssertEqual(route, .arrow)
    }

    func testImmediateToolRefreshOutsideSelectionDoesNotUseAnnotationCursor() {
        let view = SelectionView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.updateSelectionRect(selectionRect)
        view.selectionLocked = true
        view.annotationToolActive = true

        var annotationCursorRefreshCount = 0
        view.refreshAnnotationCursor = {
            annotationCursorRefreshCount += 1
        }

        XCTAssertEqual(
            view.refreshEditorCursor(at: NSPoint(x: 50, y: 50)),
            .arrow
        )
        XCTAssertEqual(annotationCursorRefreshCount, 0)

        XCTAssertEqual(
            view.refreshEditorCursor(at: NSPoint(x: 250, y: 200)),
            .annotationTool
        )
        XCTAssertEqual(annotationCursorRefreshCount, 1)
    }

    func testSelectionHandleTakesPriorityOverAnnotationTool() {
        let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: true,
            selectionLocked: true,
            annotationToolActive: true,
            selectionRect: selectionRect,
            point: selectionRect.origin,
            isOverSelectionHandle: true
        )

        XCTAssertEqual(route, .selectionHandle)
    }

    func testSelectionBorderTakesPriorityOverAnnotationTool() {
        let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: true,
            selectionLocked: true,
            annotationToolActive: true,
            selectionRect: selectionRect,
            point: NSPoint(x: selectionRect.minX + 2, y: selectionRect.midY),
            isOverSelectionHandle: false,
            isOverSelectionBorder: true
        )

        XCTAssertEqual(route, .selectionBorder)
    }

    func testFixedViewportStillRoutesInsideSelectionToActiveAnnotationTool() {
        let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: false,
            selectionLocked: true,
            annotationToolActive: true,
            selectionRect: selectionRect,
            point: NSPoint(x: 250, y: 200),
            isOverSelectionHandle: false
        )

        XCTAssertEqual(route, .annotationTool)
    }

    func testInactiveAnnotationToolRoutesInsideLockedSelectionToArrow() {
        let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: true,
            selectionLocked: true,
            annotationToolActive: false,
            selectionRect: selectionRect,
            point: NSPoint(x: 250, y: 200),
            isOverSelectionHandle: false
        )

        XCTAssertEqual(route, .arrow)
    }

    func testUnlockedSelectionLeavesCursorRoutingToSelectionFlow() {
        let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: true,
            selectionLocked: false,
            annotationToolActive: false,
            selectionRect: selectionRect,
            point: NSPoint(x: 250, y: 200),
            isOverSelectionHandle: false
        )

        XCTAssertNil(route)
    }
}
