import AppKit

@MainActor
enum PinLauncher {
    private static let stackOffset = NSSize(width: 28, height: -28)
    private static let maxDistinctStackOffsets = 8

    /// Pins images currently selected in Finder. This shortcut is intentionally
    /// source-specific: it does not fall back to the clipboard.
    @discardableResult
    static func pinSelectedImagesIfAvailable() -> Bool {
        let finderImages = FinderSelection.currentImageFileURLs().compactMap(loadImage)
        guard !finderImages.isEmpty else {
            ToastWindow.show(message: L10n.selectedImagePinNoImage)
            return false
        }

        pin(images: finderImages, source: .finder)
        ToastWindow.show(message: L10n.pinFromFinderHint)
        return true
    }

    /// Pins the image currently on the clipboard. This shortcut is
    /// source-specific: it does not check the Finder selection.
    @discardableResult
    static func pinClipboardImageIfAvailable() -> Bool {
        guard let image = ClipboardImageSource.currentImage() else {
            ToastWindow.show(message: L10n.clipboardImagePinNoImage)
            return false
        }

        pin(image: image, source: .clipboard)
        ToastWindow.show(message: L10n.pinFromClipboardHint)
        return true
    }

    /// Pins plain text currently on the clipboard as an editable text view.
    @discardableResult
    static func pinClipboardTextIfAvailable() -> Bool {
        guard let text = ClipboardTextSource.currentText() else {
            ToastWindow.show(message: L10n.clipboardTextPinNoText)
            return false
        }

        pin(text: text, source: .clipboardText)
        ToastWindow.show(message: L10n.pinFromClipboardTextHint)
        return true
    }

    /// Creates a floating pinned window for `image`. When `origin` is nil the
    /// window is centered on the screen under the cursor. Oversized images are
    /// scaled down to fit the screen.
    static func pin(image: NSImage, at origin: NSPoint? = nil, source: PinSource? = nil) {
        let screen = activeScreen()
        let size = fittedSize(for: image.size, on: screen)
        let frameOrigin = origin ?? centeredOrigin(for: size, on: screen)

        makeWindow(image: image, size: size, origin: frameOrigin, source: source)
    }

    /// Creates a floating editable text pin backed by a regular AppKit text view.
    static func pin(text: String, at origin: NSPoint? = nil, source: PinSource? = nil) {
        TextPinDebugLog.resetForProcessIfNeeded()
        let previewText = TextPinLayout.previewText(text)
        guard !previewText.isEmpty else { return }
        let screen = activeScreen()
        let size = TextPinLayout.size(
            for: previewText,
            maxWidth: TextPinLayout.maxWidth(on: screen)
        )
        let fittedSize = fittedSize(for: size, on: screen)
        let frameOrigin = origin ?? centeredOrigin(for: fittedSize, on: screen)
        var metadata = TextPinDebugLog.textMetadata(previewText)
        metadata["rawTextMetadata"] = TextPinDebugLog.textMetadata(text)
        metadata["screenFrame"] = TextPinDebugLog.rect(screen.frame)
        metadata["screenVisibleFrame"] = TextPinDebugLog.rect(screen.visibleFrame)
        metadata["maxWidth"] = TextPinDebugLog.number(TextPinLayout.maxWidth(on: screen))
        metadata["measuredSize"] = TextPinDebugLog.size(size)
        metadata["fittedSize"] = TextPinDebugLog.size(fittedSize)
        metadata["origin"] = TextPinDebugLog.point(frameOrigin)
        metadata["source"] = debugSourceName(source)
        TextPinDebugLog.log("pin-text-start", metadata: metadata)

        makeTextWindow(text: previewText, size: fittedSize, origin: frameOrigin, source: source)
    }

    private static func pin(images: [NSImage], source: PinSource) {
        let screen = activeScreen()
        let pins = images.compactMap { image -> (image: NSImage, size: NSSize)? in
            let size = fittedSize(for: image.size, on: screen)
            guard size.width > 0, size.height > 0 else { return nil }
            return (image, size)
        }
        guard let first = pins.first else { return }

        let baseOrigin = centeredOrigin(for: first.size, on: screen)
        for (index, pin) in pins.enumerated() {
            let origin = stackedOrigin(baseOrigin: baseOrigin, index: index, size: pin.size, on: screen)
            makeWindow(image: pin.image, size: pin.size, origin: origin, source: source)
        }
    }

    private static func makeWindow(image: NSImage, size: NSSize, origin: NSPoint, source: PinSource?) {
        let window = PinWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.pinSource = source

        let contentView = PinContentView(frame: NSRect(origin: .zero, size: size))
        contentView.image = image
        contentView.pinWindow = window
        window.contentView = contentView

        PinWindowManager.shared.add(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(contentView)
    }

    private static func makeTextWindow(
        text: String,
        size: NSSize,
        origin: NSPoint,
        source: PinSource?
    ) {
        let window = PinWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.pinSource = source
        TextPinDebugLog.log("make-text-window-configured", metadata: [
            "windowFrame": TextPinDebugLog.rect(window.frame),
            "contentSize": TextPinDebugLog.size(size),
            "origin": TextPinDebugLog.point(origin),
            "source": debugSourceName(source),
        ])

        let contentView = TextPinContentView(
            text: text,
            frame: NSRect(origin: .zero, size: size)
        )
        contentView.pinWindow = window
        window.contentView = contentView

        PinWindowManager.shared.add(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(contentView)
        TextPinDebugLog.log("make-text-window-ready", metadata: [
            "windowFrame": TextPinDebugLog.rect(window.frame),
            "contentFrame": TextPinDebugLog.rect(contentView.frame),
            "firstResponder": String(describing: window.firstResponder),
        ])
    }

    // MARK: - Helpers

    private static func activeScreen() -> NSScreen {
        let cursor = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(cursor) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private static func loadImage(from url: URL) -> NSImage? {
        guard let data = try? Data(contentsOf: url),
              let image = NSImage.imagePreservingPixelDimensions(from: data),
              image.size.width > 0, image.size.height > 0
        else { return nil }
        return image
    }

    /// Scales `size` down to fit within the active screen (with a margin),
    /// keeping the aspect ratio. Returns it unchanged when it already fits.
    private static func fittedSize(for size: NSSize, on screen: NSScreen) -> NSSize {
        guard size.width > 0, size.height > 0 else { return size }
        let frame = screen.visibleFrame
        let maxWidth = max(200, frame.width - 80)
        let maxHeight = max(200, frame.height - 80)
        let ratio = min(1.0, min(maxWidth / size.width, maxHeight / size.height))
        if ratio >= 1.0 { return size }
        return NSSize(width: floor(size.width * ratio), height: floor(size.height * ratio))
    }

    private static func centeredOrigin(for size: NSSize, on screen: NSScreen) -> NSPoint {
        let frame = screen.visibleFrame
        return NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
    }

    private static func stackedOrigin(
        baseOrigin: NSPoint,
        index: Int,
        size: NSSize,
        on screen: NSScreen
    ) -> NSPoint {
        let distinctIndex = index % maxDistinctStackOffsets
        let wrapIndex = index / maxDistinctStackOffsets
        let proposed = NSPoint(
            x: baseOrigin.x + CGFloat(distinctIndex) * stackOffset.width + CGFloat(wrapIndex) * 10,
            y: baseOrigin.y + CGFloat(distinctIndex) * stackOffset.height - CGFloat(wrapIndex) * 10
        )
        return clampedOrigin(proposed, size: size, on: screen)
    }

    private static func clampedOrigin(_ origin: NSPoint, size: NSSize, on screen: NSScreen) -> NSPoint {
        let frame = screen.visibleFrame
        let maxX = max(frame.minX, frame.maxX - size.width)
        let maxY = max(frame.minY, frame.maxY - size.height)
        return NSPoint(
            x: min(max(origin.x, frame.minX), maxX),
            y: min(max(origin.y, frame.minY), maxY)
        )
    }

    private static func debugSourceName(_ source: PinSource?) -> String {
        switch source {
        case .finder:
            return "finder"
        case .clipboard:
            return "clipboard"
        case .clipboardText:
            return "clipboardText"
        case nil:
            return "nil"
        }
    }
}
