import XCTest
@testable import aulycShot

final class UndoHistoryTests: XCTestCase {
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
}
