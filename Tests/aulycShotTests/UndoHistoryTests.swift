import AppKit
import XCTest
@testable import aulycShot

final class UndoHistoryTests: XCTestCase {
    private struct EditorLikeSnapshot {
        var annotations: [Annotation]
        var numberCounter: Int
    }

    func testEmptyHistoryCannotUndoOrRedo() {
        var history = UndoHistory<String>()

        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertNil(history.undo(current: "current"))
        XCTAssertNil(history.redo(current: "current"))
    }

    func testUndoAndRedoPreserveSnapshotSemantics() {
        var history = UndoHistory<String>()
        history.record("before")

        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.undo(current: "after"), "before")
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)
        XCTAssertEqual(history.redo(current: "before"), "after")
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testHistoryUsesLastInFirstOutOrdering() {
        var history = UndoHistory<Int>()
        history.record(1)
        history.record(2)

        XCTAssertEqual(history.undo(current: 3), 2)
        XCTAssertEqual(history.undo(current: 2), 1)
        XCTAssertEqual(history.redo(current: 1), 2)
        XCTAssertEqual(history.redo(current: 2), 3)
    }

    func testRecordingAfterUndoClearsRedoBranch() {
        var history = UndoHistory<String>()
        history.record("a")
        XCTAssertEqual(history.undo(current: "b"), "a")
        XCTAssertTrue(history.canRedo)

        history.record("c")

        XCTAssertFalse(history.canRedo)
        XCTAssertNil(history.redo(current: "d"))
        XCTAssertEqual(history.undo(current: "d"), "c")
    }

    func testColorMutationRoundTripsThroughUndoAndRedo() throws {
        let before = rectangle()
        let after = before.withColor(.systemBlue)

        try assertAnnotationUndoRoundTrip(before: before, after: after)
    }

    func testLineWidthMutationRoundTripsThroughUndoAndRedo() throws {
        let before = rectangle()
        let after = before.withLineWidth(8)

        try assertAnnotationUndoRoundTrip(before: before, after: after)
    }

    func testFillMutationRoundTripsThroughUndoAndRedo() throws {
        let before = rectangle()
        let after = before.withShapeFillMode(.translucent)

        try assertAnnotationUndoRoundTrip(before: before, after: after)
    }

    func testRotationMutationRoundTripsThroughUndoAndRedo() throws {
        let before = rectangle()
        let after = before.withRotation(.pi / 3)

        try assertAnnotationUndoRoundTrip(before: before, after: after)
    }

    func testControlPointMutationRoundTripsThroughUndoAndRedo() throws {
        let before = ArrowAnnotation(
            startPoint: NSPoint(x: 10, y: 20),
            endPoint: NSPoint(x: 100, y: 80),
            color: .systemRed,
            lineWidth: 4
        )
        let after = before.withControlPoint(NSPoint(x: 70, y: 20))

        try assertAnnotationUndoRoundTrip(before: before, after: after)
    }

    func testImageGeometryMutationRoundTripsThroughUndoAndRedo() throws {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let before = ImageAnnotation(
            image: image,
            rect: NSRect(x: 10, y: 20, width: 80, height: 60)
        )
        let after = before.withRect(NSRect(x: 30, y: 40, width: 120, height: 90))

        try assertAnnotationUndoRoundTrip(before: before, after: after)
    }

    func testMosaicBlockSizeMutationRoundTripsThroughUndoAndRedo() throws {
        let image = NSImage(size: NSSize(width: 80, height: 60))
        let before = MosaicAnnotation(
            rect: NSRect(x: 10, y: 20, width: 80, height: 60),
            pixelatedImage: image,
            blockSize: 12
        )
        let after = MosaicAnnotation(
            rect: before.rect,
            pixelatedImage: NSImage(size: image.size),
            blockSize: 20
        )

        try assertAnnotationUndoRoundTrip(before: before, after: after)
    }

    func testMosaicRerenderWithSameLogicalStateRemainsAnUndoNoOp() {
        let before = MosaicAnnotation(
            rect: NSRect(x: 10, y: 20, width: 80, height: 60),
            pixelatedImage: NSImage(size: NSSize(width: 80, height: 60)),
            blockSize: 12
        )
        let rerendered = MosaicAnnotation(
            rect: before.rect,
            pixelatedImage: NSImage(size: NSSize(width: 80, height: 60)),
            blockSize: before.blockSize
        )

        XCTAssertTrue(before.hasSameUndoState(as: rerendered))
    }

    func testCopiedStrokePathRemainsADistinctUndoState() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 10, y: 10))
        path.line(to: NSPoint(x: 80, y: 60))
        let copiedPath = path.copy() as! NSBezierPath
        let pen = PenAnnotation(path: path, color: .systemRed, lineWidth: 4)
        let copiedPen = PenAnnotation(path: copiedPath, color: .systemRed, lineWidth: 4)
        let marker = MarkerAnnotation(path: path, color: .systemYellow, lineWidth: 4)
        let copiedMarker = MarkerAnnotation(path: copiedPath, color: .systemYellow, lineWidth: 4)

        XCTAssertFalse(pen.hasSameUndoState(as: copiedPen))
        XCTAssertFalse(marker.hasSameUndoState(as: copiedMarker))
    }

    func testValueSnapshotsDoNotChangeWhenTheCurrentEditorStateMutates() throws {
        var history = UndoHistory<EditorLikeSnapshot>()
        let before = EditorLikeSnapshot(annotations: [rectangle()], numberCounter: 2)
        history.record(before)

        var current = before
        current.annotations.append(rectangle().translated(by: NSPoint(x: 20, y: 30)))
        current.numberCounter = 3

        let undone = try XCTUnwrap(history.undo(current: current))
        XCTAssertEqual(undone.numberCounter, 2)
        XCTAssertEqual(undone.annotations.count, 1)
        XCTAssertTrue(undone.annotations[0].hasSameUndoState(as: before.annotations[0]))

        let redone = try XCTUnwrap(history.redo(current: before))
        XCTAssertEqual(redone.numberCounter, 3)
        XCTAssertEqual(redone.annotations.count, 2)
    }

    private func assertAnnotationUndoRoundTrip(
        before: Annotation,
        after: Annotation,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertFalse(before.hasSameUndoState(as: after), file: file, line: line)

        var history = UndoHistory<EditorLikeSnapshot>()
        let beforeSnapshot = EditorLikeSnapshot(annotations: [before], numberCounter: 1)
        let afterSnapshot = EditorLikeSnapshot(annotations: [after], numberCounter: 1)
        history.record(beforeSnapshot)

        let undone = try XCTUnwrap(history.undo(current: afterSnapshot), file: file, line: line)
        XCTAssertTrue(undone.annotations[0].hasSameUndoState(as: before), file: file, line: line)

        let redone = try XCTUnwrap(history.redo(current: beforeSnapshot), file: file, line: line)
        XCTAssertTrue(redone.annotations[0].hasSameUndoState(as: after), file: file, line: line)
    }

    private func rectangle() -> RectAnnotation {
        RectAnnotation(
            rect: NSRect(x: 10, y: 20, width: 80, height: 60),
            color: .systemRed,
            lineWidth: 4,
            fillMode: ShapeFillMode.none,
            roughStyle: RoughShapeStyle(seed: 42, roughness: 0.2)
        )
    }
}
