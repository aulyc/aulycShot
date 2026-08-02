import AppKit

// MARK: - Pin Navigator

final class PinNavigatorView: NSView {
    static let maxWidth: CGFloat = 240
    static let maxHeight: CGFloat = 160
    static let minWidth: CGFloat = 96

    var image: NSImage? {
        didSet { needsDisplay = true }
    }
    var viewportRect: NSRect = .zero {
        didSet { needsDisplay = true }
    }
    var onFocusChanged: ((NSPoint) -> Void)?
    var onPointerActivity: ((NSPoint) -> Bool)?
    var onPointerExited: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        setAccessibilityLabel("Pinned image navigator")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        guard bounds.width > 0, bounds.height > 0 else { return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseEntered(with event: NSEvent) {
        updateFocus(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateFocus(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        updateFocus(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateFocus(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        onPointerExited?()
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        nextResponder?.magnify(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        let outerRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 5, yRadius: 5)

        NSColor(white: 0.02, alpha: 0.42).setFill()
        outerPath.fill()

        if let image {
            let imageRect = thumbnailImageRect()
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: imageRect, xRadius: 3, yRadius: 3).addClip()

            let context = NSGraphicsContext.current
            let oldInterpolation = context?.imageInterpolation
            context?.imageInterpolation = .high
            image.draw(in: imageRect)
            if let oldInterpolation {
                context?.imageInterpolation = oldInterpolation
            }
            NSGraphicsContext.restoreGraphicsState()

            drawViewport(in: imageRect)
        }

        NSColor.systemGreen.withAlphaComponent(0.95).setStroke()
        outerPath.lineWidth = 3
        outerPath.stroke()
    }

    private func drawViewport(in imageRect: NSRect) {
        guard viewportRect.width > 0, viewportRect.height > 0 else { return }

        let rect = NSRect(
            x: imageRect.minX + viewportRect.minX * imageRect.width,
            y: imageRect.minY + viewportRect.minY * imageRect.height,
            width: max(8, viewportRect.width * imageRect.width),
            height: max(8, viewportRect.height * imageRect.height)
        ).intersection(imageRect)
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return }

        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 2, yRadius: 2)
        NSColor.systemGreen.withAlphaComponent(0.18).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.88).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    func unitPoint(forPointInSuperview point: NSPoint) -> NSPoint? {
        guard let superview else { return nil }
        return unitPoint(forLocalPoint: convert(point, from: superview))
    }

    private func updateFocus(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        var shouldFocus = true
        if let superview {
            shouldFocus = onPointerActivity?(convert(localPoint, to: superview)) ?? true
        }
        guard shouldFocus else { return }
        guard let unitPoint = unitPoint(forLocalPoint: localPoint) else { return }
        onFocusChanged?(unitPoint)
    }

    private func unitPoint(forLocalPoint point: NSPoint) -> NSPoint? {
        guard !bounds.isEmpty else { return nil }
        guard bounds.contains(point) else { return nil }

        let imageRect = thumbnailImageRect()
        guard imageRect.width > 0, imageRect.height > 0 else { return nil }

        let clamped = NSPoint(
            x: min(max(point.x, imageRect.minX), imageRect.maxX),
            y: min(max(point.y, imageRect.minY), imageRect.maxY)
        )
        return NSPoint(
            x: (clamped.x - imageRect.minX) / imageRect.width,
            y: (clamped.y - imageRect.minY) / imageRect.height
        )
    }

    private func thumbnailImageRect() -> NSRect {
        let content = bounds.insetBy(dx: 5, dy: 5)
        guard content.width > 0, content.height > 0 else { return .zero }
        guard let image, image.size.width > 0, image.size.height > 0 else { return content }

        let imageAspect = image.size.width / image.size.height
        let contentAspect = content.width / content.height
        if imageAspect >= contentAspect {
            let height = content.width / imageAspect
            return NSRect(
                x: content.minX,
                y: content.midY - height / 2,
                width: content.width,
                height: height
            )
        } else {
            let width = content.height * imageAspect
            return NSRect(
                x: content.midX - width / 2,
                y: content.minY,
                width: width,
                height: content.height
            )
        }
    }
}
