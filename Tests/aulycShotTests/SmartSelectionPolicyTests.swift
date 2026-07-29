import CoreGraphics
import XCTest
@testable import aulycShot

final class SmartSelectionPolicyTests: XCTestCase {
    func testOrdersElementBeforeWindowAndScreen() {
        let point = CGPoint(x: 75, y: 75)
        let element = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 50, y: 50, width: 100, height: 40),
            ownerPID: 42,
            role: "AXButton"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: CGRect(x: 20, y: 20, width: 500, height: 400),
            ownerPID: 42,
            role: "AXWindow"
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            element: element,
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [element, window, screen])
    }

    func testRejectsTinyAccessibilityElement() {
        let point = CGPoint(x: 51, y: 51)
        let element = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 50, y: 50, width: 4, height: 4),
            ownerPID: 42,
            role: "AXImage"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: CGRect(x: 20, y: 20, width: 500, height: 400),
            ownerPID: 42
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            element: element,
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [window, screen])
    }

    func testRejectsElementWithSameBoundsAsWindow() {
        let point = CGPoint(x: 75, y: 75)
        let sharedFrame = CGRect(x: 20, y: 20, width: 500, height: 400)
        let element = SmartSelectionCandidate(
            kind: .element,
            frame: sharedFrame,
            ownerPID: 42,
            role: "AXGroup"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: sharedFrame,
            ownerPID: 42
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            element: element,
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [window, screen])
    }

    func testFallsBackToScreenWhenNothingElseContainsPointer() {
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            element: nil,
            window: nil,
            screen: screen,
            at: CGPoint(x: 700, y: 400)
        )

        XCTAssertEqual(candidates, [screen])
    }

    func testReturnsNoCandidateOutsideTargetScreen() {
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            element: nil,
            window: nil,
            screen: screen,
            at: CGPoint(x: 1500, y: 400)
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testCycleWrapsInBothDirections() {
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 0, count: 3, reverse: false), 1)
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 2, count: 3, reverse: false), 0)
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 0, count: 3, reverse: true), 2)
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 1, count: 0, reverse: false), 0)
    }

    func testAcceptsInteractiveAndVisualAccessibilityRoles() {
        XCTAssertTrue(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXButton"))
        XCTAssertTrue(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXImage"))
        XCTAssertTrue(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXGroup"))
    }

    func testRejectsApplicationWindowAndUnknownAccessibilityRoles() {
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXApplication"))
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXWindow"))
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXUnknown"))
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole(nil))
    }

    func testOnlyWindowCandidateExposesWindowCaptureMetadata() {
        let window = SmartSelectionCandidate(
            kind: .window(99),
            frame: CGRect(x: 20, y: 20, width: 500, height: 400)
        )
        let element = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 40, y: 40, width: 100, height: 50)
        )

        XCTAssertTrue(window.isWindowSelection)
        XCTAssertEqual(window.windowID, 99)
        XCTAssertFalse(element.isWindowSelection)
        XCTAssertNil(element.windowID)
    }

    func testHoverStatePreservesSelectedLevelWhenAccessibilityResultArrives() {
        let element = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 40, y: 40, width: 100, height: 50)
        )
        let window = SmartSelectionCandidate(
            kind: .window(99),
            frame: CGRect(x: 20, y: 20, width: 500, height: 400)
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        var state = SmartSelectionHoverState()
        state.replaceCandidates([window, screen])
        state.cycle(reverse: false)

        state.replaceCandidates([element, window, screen], preservingCurrent: true)

        XCTAssertEqual(state.currentCandidate, screen)
    }

    func testHoverStateResetsToMostSpecificCandidateWhenPointerMoves() {
        let window = SmartSelectionCandidate(
            kind: .window(99),
            frame: CGRect(x: 20, y: 20, width: 500, height: 400)
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        var state = SmartSelectionHoverState()
        state.replaceCandidates([screen])

        state.replaceCandidates([window, screen], preservingCurrent: false)

        XCTAssertEqual(state.currentCandidate, window)
    }

    func testFullScreenHoverBorderIsInsetInsideDrawableBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let borderRect = SmartSelectionPolicy.hoverBorderRect(
            candidateRect: bounds,
            drawableBounds: bounds,
            lineWidth: 3
        )

        XCTAssertEqual(borderRect, bounds.insetBy(dx: 1.5, dy: 1.5))
    }

    func testHoverStateFallsBackToFirstCandidateWhenPreviousCandidateDisappears() {
        let oldElement = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 40, y: 40, width: 100, height: 50)
        )
        let window = SmartSelectionCandidate(
            kind: .window(99),
            frame: CGRect(x: 20, y: 20, width: 500, height: 400)
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        var state = SmartSelectionHoverState()
        state.replaceCandidates([oldElement, window, screen])

        state.replaceCandidates([window, screen])

        XCTAssertEqual(state.currentCandidate, window)
    }
}
