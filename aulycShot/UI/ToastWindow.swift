import AppKit

struct ToastPresentation: Equatable {
    let visibleDuration: TimeInterval
    let fadeInDuration: TimeInterval
    let fadeOutDuration: TimeInterval

    static func standard(duration: TimeInterval) -> ToastPresentation {
        ToastPresentation(
            visibleDuration: duration,
            fadeInDuration: 0.2,
            fadeOutDuration: 0.3
        )
    }

    static let screenshotSuccess = ToastPresentation(
        visibleDuration: 1,
        fadeInDuration: 0,
        fadeOutDuration: 0
    )
}

@MainActor
class ToastWindow: NSPanel {
    private static var current: ToastWindow?

    nonisolated static var captureExcludedWindowNumbers: [CGWindowID] {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                captureExcludedWindowNumbersOnMain()
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                captureExcludedWindowNumbersOnMain()
            }
        }
    }

    /// Shows a transient toast. When `topAnchor` is set (a point in screen
    /// coordinates), the toast hangs just below that point with its horizontal
    /// center aligned to it — used to pin the hint to the top-center of a
    /// selection. When `centerAnchor` is set, the toast is centered on that
    /// point — used to place the hint in the middle of a selection. Otherwise
    /// the toast is centered on `screen`.
    static func show(
        message: String = L10n.copiedToClipboard,
        on screen: NSScreen? = nil,
        topAnchor: NSPoint? = nil,
        centerAnchor: NSPoint? = nil,
        duration: TimeInterval = 1.5
    ) {
        present(
            message: message,
            on: screen,
            topAnchor: topAnchor,
            centerAnchor: centerAnchor,
            presentation: .standard(duration: duration)
        )
    }

    /// Shows screenshot copy/save success immediately for exactly one second.
    static func showScreenshotSuccess(
        message: String = L10n.copiedToClipboard,
        on screen: NSScreen? = nil
    ) {
        present(
            message: message,
            on: screen,
            topAnchor: nil,
            centerAnchor: nil,
            presentation: .screenshotSuccess
        )
    }

    private static func present(
        message: String,
        on screen: NSScreen?,
        topAnchor: NSPoint?,
        centerAnchor: NSPoint?,
        presentation: ToastPresentation
    ) {
        current?.orderOut(nil)

        let toast = ToastWindow(message: message)
        current = toast

        if let anchor = topAnchor {
            let x = anchor.x - toast.frame.width / 2
            let y = anchor.y - toast.frame.height - 12
            toast.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let anchor = centerAnchor {
            let x = anchor.x - toast.frame.width / 2
            let y = anchor.y - toast.frame.height / 2
            toast.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = screen ?? NSScreen.main {
            let x = screen.frame.midX - toast.frame.width / 2
            let y = screen.frame.midY - toast.frame.height / 2
            toast.setFrameOrigin(NSPoint(x: x, y: y))
        }

        toast.alphaValue = presentation.fadeInDuration > 0 ? 0 : 1
        toast.orderFrontRegardless()

        if presentation.fadeInDuration > 0 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = presentation.fadeInDuration
                toast.animator().alphaValue = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + presentation.visibleDuration) {
            if presentation.fadeOutDuration > 0 {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = presentation.fadeOutDuration
                    toast.animator().alphaValue = 0.0
                }, completionHandler: {
                    MainActor.assumeIsolated {
                        toast.orderOut(nil)
                        if current === toast { current = nil }
                    }
                })
            } else {
                toast.orderOut(nil)
                if current === toast { current = nil }
            }
        }
    }

    /// Immediately hides any visible toast. Safe to call when none is showing.
    static func dismiss() {
        _ = dismissForCaptureIfNeeded()
    }

    @discardableResult
    nonisolated static func dismissForCaptureIfNeeded() -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                dismissForCaptureIfNeededOnMain()
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                dismissForCaptureIfNeededOnMain()
            }
        }
    }

    private static func captureExcludedWindowNumbersOnMain() -> [CGWindowID] {
        guard let window = current, window.isVisible else { return [] }
        let windowNumber = window.windowNumber
        guard windowNumber > 0 else { return [] }
        return [CGWindowID(windowNumber)]
    }

    private static func dismissForCaptureIfNeededOnMain() -> Bool {
        guard let window = current, window.isVisible else {
            current = nil
            return false
        }
        window.orderOut(nil)
        current = nil
        return true
    }

    private init(message: String) {
        // Measure text to size the chip
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ]
        let textSize = message.size(withAttributes: attrs)
        let size = NSSize(width: textSize.width + 24, height: 32)

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver + 3
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let toastView = ToastContentView(frame: NSRect(origin: .zero, size: size), message: message)
        contentView = toastView
    }
}

private class ToastContentView: NSView {
    private let message: String

    init(frame: NSRect, message: String) {
        self.message = message
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        AdaptiveChrome.floatingBackground.setFill()
        path.fill()

        AdaptiveChrome.border.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ]
        let size = message.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        message.draw(in: textRect, withAttributes: attrs)
    }
}
