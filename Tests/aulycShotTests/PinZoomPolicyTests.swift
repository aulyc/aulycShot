import AppKit
import XCTest
@testable import aulycShot

final class PinZoomPolicyTests: XCTestCase {
    func testPolicyConstantsKeepExistingInteractionValues() {
        XCTAssertEqual(PinZoom.minScale, 0.25)
        XCTAssertEqual(PinZoom.maxScale, 5)
        XCTAssertEqual(PinZoom.buttonStep, 0.1)
        XCTAssertEqual(PinZoom.wheelSensitivity, 0.002)
        XCTAssertEqual(PinZoom.expandedViewportScaleThreshold, 1.5)
        XCTAssertEqual(PinZoom.expandedViewportWidthRatio, 0.5)
        XCTAssertEqual(PinZoom.expandedViewportVerticalInset, 16)
        XCTAssertEqual(PinZoom.viewportTransitionDuration, 0.22)
        XCTAssertEqual(PinZoom.viewportAnimationFrameInterval, 1.0 / 60.0)
        XCTAssertEqual(PinZoom.interactivePreviewMaxPixelDimension, 1280)
        XCTAssertEqual(PinZoom.interactivePreviewEndDelay, 0.1)
        XCTAssertEqual(PinZoom.toolbarInset, 8)
        XCTAssertEqual(PinZoom.navigatorScaleThreshold, 1.2)
        XCTAssertEqual(PinZoom.navigatorGap, 8)
        XCTAssertEqual(PinZoom.navigatorIdleHideDelay, 0.8)
        XCTAssertEqual(PinZoom.navigatorActivationDelay, 0.4)
        XCTAssertEqual(PinZoom.navigatorEntryTimeout, 3)
        XCTAssertEqual(PinZoom.toolbarAnimationDuration, 0.16)
    }

    func testScaleClampingAndExpandedViewportThreshold() {
        XCTAssertEqual(PinZoom.clampedScale(0.1), 0.25)
        XCTAssertEqual(PinZoom.clampedScale(2), 2)
        XCTAssertEqual(PinZoom.clampedScale(8), 5)
        XCTAssertFalse(PinZoom.usesExpandedViewport(at: 1.5))
        XCTAssertFalse(PinZoom.usesExpandedViewport(at: 1.504))
        XCTAssertTrue(PinZoom.usesExpandedViewport(at: 1.506))
    }

    func testScaledImageSizeFloorsPixelsAndKeepsMinimumDimension() {
        XCTAssertEqual(
            PinZoom.scaledImageSize(baseImageSize: NSSize(width: 101, height: 51), scale: 0.5),
            NSSize(width: 50, height: 25)
        )
        XCTAssertEqual(
            PinZoom.scaledImageSize(baseImageSize: NSSize(width: 1, height: 1), scale: 0.25),
            NSSize(width: 1, height: 1)
        )
    }

    func testCollapsedWindowSizeFollowsImageAndVisibleScreenLimit() {
        let toolbarMinimum = NSSize(width: 200, height: 80)
        XCTAssertEqual(
            PinZoom.windowSize(
                baseImageSize: NSSize(width: 400, height: 200),
                scale: 0.5,
                screenFrame: nil,
                visibleFrame: nil,
                toolbarVisible: false,
                toolbarMinimumSize: toolbarMinimum
            ),
            NSSize(width: 200, height: 100)
        )
        XCTAssertEqual(
            PinZoom.windowSize(
                baseImageSize: NSSize(width: 2_000, height: 1_000),
                scale: 1,
                screenFrame: NSRect(x: 0, y: 0, width: 900, height: 700),
                visibleFrame: NSRect(x: 0, y: 0, width: 800, height: 600),
                toolbarVisible: false,
                toolbarMinimumSize: toolbarMinimum
            ),
            NSSize(width: 800, height: 400)
        )
        XCTAssertEqual(
            PinZoom.windowSize(
                baseImageSize: NSSize(width: 400, height: 200),
                scale: 1.4,
                screenFrame: nil,
                visibleFrame: nil,
                toolbarVisible: false,
                toolbarMinimumSize: toolbarMinimum
            ),
            NSSize(width: 400, height: 200)
        )
    }

    func testWindowSizeHandlesInvalidImageToolbarMinimumAndExpandedViewport() {
        XCTAssertEqual(
            PinZoom.windowSize(
                baseImageSize: .zero,
                scale: 1,
                screenFrame: nil,
                visibleFrame: nil,
                toolbarVisible: false,
                toolbarMinimumSize: .zero
            ),
            .zero
        )
        XCTAssertEqual(
            PinZoom.windowSize(
                baseImageSize: NSSize(width: 40, height: 20),
                scale: 1,
                screenFrame: NSRect(x: 0, y: 0, width: 500, height: 400),
                visibleFrame: NSRect(x: 0, y: 0, width: 500, height: 400),
                toolbarVisible: true,
                toolbarMinimumSize: NSSize(width: 200, height: 80)
            ),
            NSSize(width: 200, height: 80)
        )
        XCTAssertEqual(
            PinZoom.windowSize(
                baseImageSize: NSSize(width: 400, height: 200),
                scale: 2,
                screenFrame: NSRect(x: 0, y: 0, width: 1_200, height: 800),
                visibleFrame: NSRect(x: 0, y: 20, width: 1_100, height: 700),
                toolbarVisible: true,
                toolbarMinimumSize: NSSize(width: 200, height: 80)
            ),
            NSSize(width: 600, height: 668)
        )
    }

    func testWindowConstraintAndFrameClamping() {
        let visible = NSRect(x: 10, y: 20, width: 500, height: 400)
        XCTAssertEqual(PinZoom.windowConstraintFrame(for: 1, visibleFrame: visible), visible)
        XCTAssertEqual(
            PinZoom.windowConstraintFrame(for: 2, visibleFrame: visible),
            visible.insetBy(dx: 0, dy: 16)
        )
        XCTAssertEqual(
            PinZoom.windowConstraintFrame(
                for: 2,
                visibleFrame: NSRect(x: 0, y: 0, width: 100, height: 20)
            ),
            NSRect(x: 0, y: 9.5, width: 100, height: 1)
        )
        XCTAssertEqual(
            PinZoom.clampedWindowFrame(
                NSRect(x: -50, y: 500, width: 200, height: 100),
                to: visible
            ),
            NSRect(x: 10, y: 320, width: 200, height: 100)
        )
    }

    func testPanClampingForLargeAndSmallImages() {
        XCTAssertEqual(
            PinZoom.clampedPanOffset(
                NSPoint(x: -500, y: 500),
                baseImageSize: NSSize(width: 200, height: 200),
                scale: 2,
                viewportSize: NSSize(width: 300, height: 300),
                allowsEmptyViewportSpace: false
            ),
            NSPoint(x: -100, y: 100)
        )
        XCTAssertEqual(
            PinZoom.clampedPanOffset(
                NSPoint(x: 50, y: -50),
                baseImageSize: NSSize(width: 100, height: 100),
                scale: 1,
                viewportSize: NSSize(width: 200, height: 200),
                allowsEmptyViewportSpace: false
            ),
            .zero
        )
        XCTAssertEqual(
            PinZoom.clampedPanOffset(
                NSPoint(x: 500, y: -500),
                baseImageSize: NSSize(width: 100, height: 100),
                scale: 1,
                viewportSize: NSSize(width: 200, height: 200),
                allowsEmptyViewportSpace: true
            ),
            NSPoint(x: 100, y: -100)
        )
    }

    func testFocusedPanOffsetKeepsAnchorAndClampsUnitPoint() {
        XCTAssertEqual(
            PinZoom.focusedPanOffset(
                on: NSPoint(x: 0.5, y: 0.5),
                scale: 2,
                baseImageSize: NSSize(width: 200, height: 200),
                viewportSize: NSSize(width: 200, height: 200),
                focusPoint: nil,
                allowsEmptyViewportSpace: false
            ),
            NSPoint(x: -100, y: 100)
        )
        XCTAssertEqual(
            PinZoom.focusedPanOffset(
                on: NSPoint(x: 2, y: -1),
                scale: 2,
                baseImageSize: NSSize(width: 200, height: 200),
                viewportSize: NSSize(width: 200, height: 200),
                focusPoint: NSPoint(x: 100, y: 100),
                allowsEmptyViewportSpace: false
            ),
            NSPoint(x: -200, y: 200)
        )
    }

    func testAdjustedFocusPointHandlesMissingAndPresentAnchor() {
        XCTAssertNil(PinZoom.adjustedFocusPoint(nil, by: NSPoint(x: 10, y: 20)))
        XCTAssertEqual(
            PinZoom.adjustedFocusPoint(NSPoint(x: 5, y: 7), by: NSPoint(x: 10, y: -2)),
            NSPoint(x: 15, y: 5)
        )
    }

    func testViewportGeometryPreservesImageAnchorAndAppliesConstraint() {
        let unconstrained = PinZoom.viewportGeometry(
            currentFrame: NSRect(x: 100, y: 100, width: 200, height: 200),
            currentPanOffset: NSPoint(x: -50, y: 50),
            targetSize: NSSize(width: 300, height: 300),
            baseImageSize: NSSize(width: 200, height: 200),
            scale: 2,
            constraintFrame: nil,
            allowsEmptyViewportSpace: false
        )
        XCTAssertEqual(unconstrained.frame, NSRect(x: 100, y: 0, width: 300, height: 300))
        XCTAssertEqual(unconstrained.panOffset, NSPoint(x: -50, y: 50))

        let constrained = PinZoom.viewportGeometry(
            currentFrame: NSRect(x: 100, y: 100, width: 200, height: 200),
            currentPanOffset: NSPoint(x: -50, y: 50),
            targetSize: NSSize(width: 300, height: 300),
            baseImageSize: NSSize(width: 200, height: 200),
            scale: 2,
            constraintFrame: NSRect(x: 0, y: 0, width: 250, height: 250),
            allowsEmptyViewportSpace: false
        )
        XCTAssertEqual(constrained.frame, NSRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertEqual(constrained.panOffset, NSPoint(x: 0, y: 50))
    }
}
