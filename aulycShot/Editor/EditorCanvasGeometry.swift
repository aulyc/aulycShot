import AppKit

/// Pure geometry used by EditCanvasView for drawing constraints, selection
/// chrome, and annotation resizing.
enum EditorCanvasGeometry {
    enum ResizeAnchor: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

        var movesMinX: Bool { self == .topLeft || self == .left || self == .bottomLeft }
        var movesMaxX: Bool { self == .topRight || self == .right || self == .bottomRight }
        var movesMinY: Bool { self == .bottomLeft || self == .bottom || self == .bottomRight }
        var movesMaxY: Bool { self == .topLeft || self == .top || self == .topRight }

        func point(in rect: NSRect) -> NSPoint {
            let x: CGFloat = movesMinX ? rect.minX : (movesMaxX ? rect.maxX : rect.midX)
            let y: CGFloat = movesMinY ? rect.minY : (movesMaxY ? rect.maxY : rect.midY)
            return NSPoint(x: x, y: y)
        }
    }

    enum ResizeConstraint {
        case none
        case preserveAspectRatio
        case square
    }

    static func rectFromTwoPoints(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    static func constrainedShapeEnd(
        from start: NSPoint,
        to end: NSPoint,
        tool: EditTool,
        modifiers: NSEvent.ModifierFlags
    ) -> NSPoint {
        guard modifiers
            .intersection(.deviceIndependentFlagsMask)
            .contains(.shift)
        else { return end }

        switch tool {
        case .line, .arrow:
            return axisLockedEnd(from: start, to: end)
        case .rectangle, .ellipse:
            return squareLockedEnd(from: start, to: end)
        default:
            return end
        }
    }

    static func constrainsShapeWithShift(_ tool: EditTool) -> Bool {
        switch tool {
        case .line, .arrow, .rectangle, .ellipse:
            return true
        default:
            return false
        }
    }

    static func axisLockedEnd(from start: NSPoint, to end: NSPoint) -> NSPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if abs(dx) >= abs(dy) {
            return NSPoint(x: end.x, y: start.y)
        }
        return NSPoint(x: start.x, y: end.y)
    }

    static func squareLockedEnd(from start: NSPoint, to end: NSPoint) -> NSPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let side = max(abs(dx), abs(dy))
        guard side > 0 else { return end }

        let xSign: CGFloat = dx < 0 ? -1 : 1
        let ySign: CGFloat = dy < 0 ? -1 : 1
        return NSPoint(
            x: start.x + side * xSign,
            y: start.y + side * ySign
        )
    }

    static func selectionBox(boundingRect: NSRect, padding: CGFloat) -> NSRect {
        boundingRect.insetBy(dx: -padding, dy: -padding)
    }

    static func rotated(
        _ point: NSPoint,
        around rect: NSRect,
        rotation: CGFloat
    ) -> NSPoint {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        let cosR = cos(rotation)
        let sinR = sin(rotation)
        return NSPoint(
            x: rect.midX + dx * cosR - dy * sinR,
            y: rect.midY + dx * sinR + dy * cosR
        )
    }

    static func resizeHandlePoint(
        _ anchor: ResizeAnchor,
        boundingRect: NSRect,
        rotation: CGFloat
    ) -> NSPoint {
        rotated(anchor.point(in: boundingRect), around: boundingRect, rotation: rotation)
    }

    static func clamped(_ point: NSPoint, to bounds: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    static func resizedRect(
        from original: NSRect,
        anchor: ResizeAnchor,
        currentMouse: NSPoint,
        minimumSize: CGFloat,
        constraint: ResizeConstraint = .none
    ) -> NSRect {
        if constraint != .none {
            return resizedRotatedRect(
                from: original,
                rotation: 0,
                anchor: anchor,
                currentMouse: currentMouse,
                minimumSize: minimumSize,
                constraint: constraint
            )
        }

        var minX = original.minX
        var maxX = original.maxX
        var minY = original.minY
        var maxY = original.maxY

        if anchor.movesMinX { minX = currentMouse.x }
        if anchor.movesMaxX { maxX = currentMouse.x }
        if anchor.movesMinY { minY = currentMouse.y }
        if anchor.movesMaxY { maxY = currentMouse.y }

        let width = abs(maxX - minX)
        let height = abs(maxY - minY)
        guard width >= minimumSize, height >= minimumSize else {
            return original
        }

        return NSRect(
            x: min(minX, maxX),
            y: min(minY, maxY),
            width: width,
            height: height
        )
    }

    static func resizedRotatedRect(
        from original: NSRect,
        rotation: CGFloat,
        anchor: ResizeAnchor,
        currentMouse: NSPoint,
        minimumSize: CGFloat,
        constraint: ResizeConstraint = .none
    ) -> NSRect {
        let originalHalfWidth = original.width / 2
        let originalHalfHeight = original.height / 2
        let originalCenter = NSPoint(x: original.midX, y: original.midY)
        guard original.width > 0, original.height > 0 else { return original }

        let xSign: CGFloat? = anchor.movesMinX ? -1 : (anchor.movesMaxX ? 1 : nil)
        let ySign: CGFloat? = anchor.movesMinY ? -1 : (anchor.movesMaxY ? 1 : nil)

        let fixedLocal = NSPoint(
            x: xSign.map { -$0 * originalHalfWidth } ?? 0,
            y: ySign.map { -$0 * originalHalfHeight } ?? 0
        )
        let fixedWorld = point(originalCenter, adding: rotatedVector(fixedLocal, by: rotation))
        let deltaLocal = unrotatedVector(delta(from: fixedWorld, to: currentMouse), by: rotation)

        // Keep dimensions signed until the center is placed so handles can
        // cross over the fixed edge; the returned NSRect stays normalized.
        let proposedWidth = xSign.map { $0 * deltaLocal.x } ?? original.width
        let proposedHeight = ySign.map { $0 * deltaLocal.y } ?? original.height
        var signedWidth = proposedWidth
        var signedHeight = proposedHeight

        func direction(for value: CGFloat) -> CGFloat {
            value < 0 ? -1 : 1
        }

        if constraint == .preserveAspectRatio, xSign != nil || ySign != nil {
            let scale: CGFloat
            switch (xSign, ySign) {
            case (.some, .some):
                let denominator = original.width * original.width + original.height * original.height
                scale = denominator > 0
                    ? (original.width * abs(proposedWidth) + original.height * abs(proposedHeight)) / denominator
                    : 1
            case (.some, .none):
                scale = abs(proposedWidth) / original.width
            case (.none, .some):
                scale = abs(proposedHeight) / original.height
            case (.none, .none):
                scale = 1
            }
            guard scale.isFinite else { return original }
            signedWidth = (xSign == nil ? 1 : direction(for: proposedWidth)) * original.width * scale
            signedHeight = (ySign == nil ? 1 : direction(for: proposedHeight)) * original.height * scale
        } else if constraint == .square, xSign != nil || ySign != nil {
            let side: CGFloat
            switch (xSign, ySign) {
            case (.some, .some):
                side = max(abs(proposedWidth), abs(proposedHeight))
            case (.some, .none):
                side = abs(proposedWidth)
            case (.none, .some):
                side = abs(proposedHeight)
            case (.none, .none):
                side = min(original.width, original.height)
            }
            guard side.isFinite else { return original }
            signedWidth = (xSign == nil ? 1 : direction(for: proposedWidth)) * side
            signedHeight = (ySign == nil ? 1 : direction(for: proposedHeight)) * side
        }

        let halfWidth = abs(signedWidth) / 2
        let halfHeight = abs(signedHeight) / 2
        let centerLocal = NSPoint(
            x: xSign.map { $0 * signedWidth / 2 } ?? 0,
            y: ySign.map { $0 * signedHeight / 2 } ?? 0
        )
        let center = point(fixedWorld, adding: rotatedVector(centerLocal, by: rotation))
        return NSRect(
            x: center.x - halfWidth,
            y: center.y - halfHeight,
            width: halfWidth * 2,
            height: halfHeight * 2
        )
    }

    static func constrainedEndpoint(
        _ currentMouse: NSPoint,
        fixedPoint: NSPoint,
        shiftPressed: Bool
    ) -> NSPoint {
        guard shiftPressed else { return currentMouse }
        return axisLockedEnd(from: fixedPoint, to: currentMouse)
    }

    private static func rotatedVector(_ vector: NSPoint, by rotation: CGFloat) -> NSPoint {
        let cosR = cos(rotation)
        let sinR = sin(rotation)
        return NSPoint(
            x: vector.x * cosR - vector.y * sinR,
            y: vector.x * sinR + vector.y * cosR
        )
    }

    private static func unrotatedVector(_ vector: NSPoint, by rotation: CGFloat) -> NSPoint {
        rotatedVector(vector, by: -rotation)
    }

    private static func point(_ point: NSPoint, adding vector: NSPoint) -> NSPoint {
        NSPoint(x: point.x + vector.x, y: point.y + vector.y)
    }

    private static func delta(from start: NSPoint, to end: NSPoint) -> NSPoint {
        NSPoint(x: end.x - start.x, y: end.y - start.y)
    }
}
