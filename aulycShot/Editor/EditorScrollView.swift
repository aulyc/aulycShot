import AppKit

final class EditorScrollView: NSScrollView {
    weak var editorCanvasView: EditCanvasView?
    /// When `true`, every viewport click is captured by drawing tools or fixed
    /// image content. When `false` the scroll view
    /// only forwards clicks that the canvas itself claimed, so empty
    /// viewport clicks fall through to the SelectionView underneath where
    /// its resize handles live.
    var isInteractionEnabled = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        if isInteractionEnabled {
            return result
        }
        guard let canvas = editorCanvasView, let hit = result else { return nil }
        if hit === canvas || hit.isDescendant(of: canvas) {
            return hit
        }
        return nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func scrollToTop() {
        guard let documentView else { return }
        let topOffset = max(0, documentView.frame.height - contentView.bounds.height)
        contentView.scroll(to: NSPoint(x: 0, y: topOffset))
        reflectScrolledClipView(contentView)
    }
}

/// A row (horizontal) or column (vertical) of editor buttons built from a
/// `[ToolbarItemID]`. Both the primary toolbar and the side toolbar are
/// instances of this class — only `orientation` and the item list differ.
