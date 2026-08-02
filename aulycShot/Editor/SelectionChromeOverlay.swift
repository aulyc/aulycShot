import AppKit

// MARK: - Selection Chrome Overlay

/// Sits above the editor's `canvasScrollView` so the selection remains
/// adjustable while the canvas owns its interior. Handle hits resize, border
/// hits move the whole selection, and every other hit falls through.
final class SelectionChromeOverlay: NSView {
    weak var selectionView: SelectionView?
    var onMoveStart: (() -> Void)?

    private(set) var selectionRectInView: NSRect = .zero

    private let handleHitSize: CGFloat = 12
    private let borderHitSize: CGFloat = 7

    private enum DragAction {
        case none
        case move
        case resize(SelectionView.HandlePosition)
    }

    private var dragAction: DragAction = .none
    private var dragStartPoint: NSPoint = .zero
    private var dragOriginalRect: NSRect = .zero

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func update(rect: NSRect) {
        selectionRectInView = rect
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let selectionView, selectionView.selectionInteractionEnabled else { return nil }
        // `point` is in the superview's coordinate space.
        let local = convert(point, from: superview)
        let handle = SelectionView.hitTestHandle(
            point: local,
            rect: selectionRectInView,
            hitSize: handleHitSize
        )
        return handle != nil || Self.isBorderHit(
            point: local,
            rect: selectionRectInView,
            hitSize: borderHitSize
        ) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let selectionView, selectionView.selectionInteractionEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        dragOriginalRect = selectionView.currentSelectionRect ?? selectionRectInView
        if let handle = SelectionView.hitTestHandle(
            point: point,
            rect: selectionRectInView,
            hitSize: handleHitSize
        ) {
            dragAction = .resize(handle)
            SelectionView.setCursorForHandle(handle)
        } else if Self.isBorderHit(
            point: point,
            rect: selectionRectInView,
            hitSize: borderHitSize
        ) {
            dragAction = .move
            dragStartPoint = point
            onMoveStart?()
            NSCursor.closedHand.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let selectionView else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch dragAction {
        case .none:
            return
        case .move:
            selectionView.moveByExternalDrag(
                deltaFromOriginal: CGSize(
                    width: point.x - dragStartPoint.x,
                    height: point.y - dragStartPoint.y
                ),
                originalRect: dragOriginalRect
            )
        case let .resize(handle):
            selectionView.resizeByExternalDrag(
                handle: handle,
                originalRect: dragOriginalRect,
                currentPoint: point
            )
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let selectionView else {
            dragAction = .none
            return
        }
        let completedAction = dragAction
        switch completedAction {
        case .none:
            break
        case .move:
            selectionView.finalizeExternalDrag()
        case .resize:
            selectionView.finalizeExternalResize()
        }
        dragAction = .none

        switch completedAction {
        case let .resize(handle):
            SelectionView.setCursorForHandle(handle)
        case .move:
            NSCursor.openHand.set()
        case .none:
            break
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let selectionView, selectionView.selectionInteractionEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let handle = SelectionView.hitTestHandle(
            point: point,
            rect: selectionRectInView,
            hitSize: handleHitSize
        ) {
            SelectionView.setCursorForHandle(handle)
        } else if Self.isBorderHit(
            point: point,
            rect: selectionRectInView,
            hitSize: borderHitSize
        ) {
            NSCursor.openHand.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if case .none = dragAction {
            NSCursor.arrow.set()
        }
    }

    static func isBorderHit(point: NSPoint, rect: NSRect, hitSize: CGFloat) -> Bool {
        EditorCursorRoutingPolicy.isSelectionBorderHit(
            point: point,
            rect: rect,
            hitSize: hitSize
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

}
