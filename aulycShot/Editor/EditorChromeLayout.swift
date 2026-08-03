import AppKit

/// Pure geometry for positioning the editor's floating toolbars around the
/// current selection. Keeping this independent from the controller makes the
/// screen-edge and overlap rules directly testable.
struct EditorChromeLayout {
    private static let margin: CGFloat = 8

    let selectionRect: NSRect

    func toolbarRect(in bounds: NSRect, size: NSSize) -> NSRect {
        let x = clampedX(
            selectionRect.midX - size.width / 2,
            width: size.width,
            in: bounds,
            margin: Self.margin
        )
        var y = selectionRect.minY - size.height - Self.margin
        if y < Self.margin {
            y = min(selectionRect.maxY + Self.margin, bounds.maxY - size.height - Self.margin)
        }
        y = max(Self.margin, min(bounds.maxY - size.height - Self.margin, y))

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Prefers the right of the selection, flips to the left when needed,
    /// and moves outside the primary toolbar's band when the frames overlap.
    func sideToolbarRect(
        in bounds: NSRect,
        size: NSSize,
        avoiding primaryFrame: NSRect? = nil
    ) -> NSRect {
        var x = selectionRect.maxX + Self.margin
        if x + size.width > bounds.maxX - Self.margin {
            x = selectionRect.minX - size.width - Self.margin
        }
        x = max(Self.margin, min(bounds.maxX - size.width - Self.margin, x))

        var y = selectionRect.midY - size.height / 2
        y = max(Self.margin, min(bounds.maxY - size.height - Self.margin, y))

        var rect = NSRect(x: x, y: y, width: size.width, height: size.height)
        if let primaryFrame, rect.intersects(primaryFrame) {
            let above = primaryFrame.maxY + Self.margin
            if above + size.height <= bounds.maxY - Self.margin {
                rect.origin.y = above
            } else {
                rect.origin.y = max(Self.margin, primaryFrame.minY - Self.margin - size.height)
            }
        }

        return rect
    }

    func subToolbarRect(
        width: CGFloat,
        height: CGFloat,
        toolbarFrame: NSRect,
        in bounds: NSRect
    ) -> NSRect {
        let x = clampedX(
            toolbarFrame.midX - width / 2,
            width: width,
            in: bounds,
            margin: Self.margin
        )
        var y = toolbarFrame.minY - height - 4
        if y < Self.margin {
            y = min(toolbarFrame.maxY + 4, bounds.maxY - height - Self.margin)
        }
        y = max(Self.margin, min(bounds.maxY - height - Self.margin, y))

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func clampedX(
        _ proposedX: CGFloat,
        width: CGFloat,
        in bounds: NSRect,
        margin: CGFloat
    ) -> CGFloat {
        max(margin, min(bounds.maxX - width - margin, proposedX))
    }
}
