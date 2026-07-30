import CoreGraphics
import XCTest
@testable import aulycShot

final class SmartSelectionPolicyTests: XCTestCase {
    func testOrdersRegionBeforeWindowAndScreen() {
        let point = CGPoint(x: 75, y: 75)
        let element = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 40, y: 40, width: 160, height: 100),
            ownerPID: 42,
            role: "AXGroup"
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
            elements: [element],
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
            role: "AXGroup"
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
            elements: [element],
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
            elements: [element],
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
            elements: [],
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
            elements: [],
            window: nil,
            screen: screen,
            at: CGPoint(x: 1500, y: 400)
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testChoosesOnlyLargestStructuralRegionBeforeWindowAndScreen() {
        let point = CGPoint(x: 75, y: 75)
        let button = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 50, y: 50, width: 100, height: 40),
            ownerPID: 42,
            role: "AXButton"
        )
        let content = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 40, y: 40, width: 300, height: 200),
            ownerPID: 42,
            role: "AXGroup"
        )
        let dialog = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 20, y: 20, width: 500, height: 400),
            ownerPID: 42,
            role: "AXGroup"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            ownerPID: 42
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            elements: [button, content, dialog],
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [dialog, window, screen])
    }

    func testDeduplicatesAccessibilityAncestorsWithSameBounds() {
        let point = CGPoint(x: 75, y: 75)
        let group = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 20, y: 20, width: 500, height: 400),
            ownerPID: 42,
            role: "AXGroup"
        )
        let duplicateWebArea = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 20.5, y: 20.5, width: 500, height: 400),
            ownerPID: 42,
            role: "AXWebArea"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            ownerPID: 42
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            elements: [group, duplicateWebArea],
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [group, window, screen])
    }

    func testRejectsLargeLeafControlFromAutomaticSelection() {
        let point = CGPoint(x: 200, y: 150)
        let button = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 100, y: 100, width: 500, height: 300),
            ownerPID: 42,
            role: "AXButton"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            ownerPID: 42
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            elements: [button],
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [window, screen])
    }

    func testRejectsRegionBelowWindowAreaThreshold() {
        let point = CGPoint(x: 75, y: 75)
        let smallRegion = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 20, y: 20, width: 120, height: 80),
            ownerPID: 42,
            role: "AXGroup"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
            ownerPID: 42
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            elements: [smallRegion],
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [window, screen])
    }

    func testRejectsRootRegionThatNearlyFillsWindow() {
        let point = CGPoint(x: 200, y: 150)
        let rootRegion = SmartSelectionCandidate(
            kind: .element,
            frame: CGRect(x: 10, y: 10, width: 780, height: 580),
            ownerPID: 42,
            role: "AXWebArea"
        )
        let window = SmartSelectionCandidate(
            kind: .window(9),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            ownerPID: 42
        )
        let screen = SmartSelectionCandidate(
            kind: .screen(1),
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )

        let candidates = SmartSelectionPolicy.orderedCandidates(
            elements: [rootRegion],
            window: window,
            screen: screen,
            at: point
        )

        XCTAssertEqual(candidates, [window, screen])
    }

    func testCycleWrapsInBothDirections() {
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 0, count: 3, reverse: false), 1)
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 2, count: 3, reverse: false), 0)
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 0, count: 3, reverse: true), 2)
        XCTAssertEqual(SmartSelectionPolicy.cycledIndex(current: 1, count: 0, reverse: false), 0)
    }

    func testAcceptsOnlyStructuralAccessibilityRoles() {
        XCTAssertTrue(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXGroup"))
        XCTAssertTrue(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXScrollArea"))
        XCTAssertTrue(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXWebArea"))
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXButton"))
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXStaticText"))
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXImage"))
        XCTAssertFalse(SmartSelectionPolicy.isMeaningfulAccessibilityRole("AXTextField"))
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

        state.replaceCandidates(
            [element, window, screen],
            preservingCurrent: state.hasManuallyCycledCandidate
        )

        XCTAssertEqual(state.currentCandidate, screen)
    }

    func testHoverStateUsesNewAccessibilityCandidateWhenPointerMovesWithoutManualCycle() {
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
        state.resetManualCycle()

        state.replaceCandidates(
            [element, window, screen],
            preservingCurrent: state.hasManuallyCycledCandidate
        )

        XCTAssertEqual(state.currentCandidate, element)
    }

    func testPointerMovementClearsManualCyclePreservation() {
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
        XCTAssertTrue(state.hasManuallyCycledCandidate)

        state.resetManualCycle()

        XCTAssertFalse(state.hasManuallyCycledCandidate)
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
