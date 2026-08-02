import AppKit

// MARK: - Scroll Preview Window

final class ScrollPreviewWindow: NSPanel {
    private let imageView = NSImageView()
    private let maxPreviewWidth: CGFloat = 120
    private let maxPreviewHeight: CGFloat = 400
    private let contentInset: CGFloat = 4

    init() {
        let initialRect = NSRect(
            x: 0,
            y: 0,
            width: maxPreviewWidth + contentInset * 2,
            height: maxPreviewHeight + contentInset * 2
        )
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver + 3
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let containerRect = NSRect(origin: .zero, size: initialRect.size)
        let container = AdaptiveChromeSurfaceView(
            style: .floating,
            cornerRadius: 8,
            borderWidth: 0.5
        )
        container.frame = containerRect
        container.autoresizingMask = [.width, .height]

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignTop
        imageView.frame = containerRect.insetBy(dx: contentInset, dy: contentInset)
        imageView.autoresizingMask = [.width, .height]
        container.addSubview(imageView)

        contentView = container
    }

    func updatePreview(_ image: NSImage, anchorRect: NSRect) {
        imageView.image = image
        let windowW = maxPreviewWidth + contentInset * 2
        let windowH = maxPreviewHeight + contentInset * 2

        // Position to the right of selection, or left if no room
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var x = anchorRect.maxX + 12
        if x + windowW > screenFrame.maxX {
            x = anchorRect.minX - windowW - 12
        }
        // Vertically align to top of selection
        let y = anchorRect.maxY - windowH

        setFrame(NSRect(x: x, y: y, width: windowW, height: windowH), display: true)

        if !isVisible {
            orderFrontRegardless()
        }
    }

    func dismiss() {
        orderOut(nil)
        imageView.image = nil
        contentView = nil
    }
}
