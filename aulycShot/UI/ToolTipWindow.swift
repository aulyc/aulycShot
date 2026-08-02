import AppKit

/// Single-instance hover tooltip used by the editor toolbar
/// Self-drawn to match the adaptive toolbar / cursor chip aesthetic
@MainActor
final class ToolTipWindow: NSPanel {
    private static var current: ToolTipWindow?
    private static var pendingWorkItem: DispatchWorkItem?
    private static var appDeactivationObserver: NSObjectProtocol?
    private static weak var ownerWindow: NSWindow?
    private static var currentAnchor: NSRect?

    /// `anchor` is the screen-space rect of the hovered control. The tip
    /// pops above it, horizontally centered.
    static func show(
        text: String,
        anchor: NSRect,
        relativeTo owner: NSWindow,
        delay: TimeInterval = 0.35
    ) {
        hide()
        ownerWindow = owner
        currentAnchor = anchor
        appDeactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                hide()
            }
        }
        let work = DispatchWorkItem { [weak owner] in
            guard let owner,
                  ownerWindow === owner,
                  let anchor = currentAnchor,
                  owner.isVisible else { return }
            present(text: text, anchor: anchor, relativeTo: owner)
        }
        pendingWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Keeps an already visible or pending tooltip attached to a control that
    /// moved because its enclosing settings page scrolled.
    static func updateAnchor(_ anchor: NSRect, relativeTo owner: NSWindow) {
        guard ownerWindow === owner else { return }
        currentAnchor = anchor
        guard let tip = current else { return }
        position(tip, at: anchor)
    }

    static func hide() {
        cancelPending()
        if let appDeactivationObserver {
            NotificationCenter.default.removeObserver(appDeactivationObserver)
            self.appDeactivationObserver = nil
        }
        if let tip = current {
            tip.parent?.removeChildWindow(tip)
            tip.orderOut(nil)
        }
        current = nil
        currentAnchor = nil
        ownerWindow = nil
    }

    private static func cancelPending() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }

    private static func present(text: String, anchor: NSRect, relativeTo owner: NSWindow) {
        let tip = ToolTipWindow(text: text)
        current = tip
        tip.level = owner.level
        position(tip, at: anchor)

        owner.addChildWindow(tip, ordered: .above)
        tip.alphaValue = 0
        tip.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            tip.animator().alphaValue = 1.0
        }
    }

    private static func position(_ tip: ToolTipWindow, at anchor: NSRect) {
        let gap: CGFloat = 6
        let x = anchor.midX - tip.frame.width / 2
        let y = anchor.maxY + gap
        tip.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private init(text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ]
        let textSize = text.size(withAttributes: attrs)
        let size = NSSize(
            width: ceil(textSize.width) + 16,
            height: 22
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.transient, .ignoresCycle]

        contentView = ToolTipContentView(frame: NSRect(origin: .zero, size: size), text: text)
    }
}

private final class ToolTipContentView: NSView {
    private let text: String

    init(frame: NSRect, text: String) {
        self.text = text
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        AdaptiveChrome.floatingBackground.setFill()
        path.fill()
        AdaptiveChrome.border.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ]
        let size = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        text.draw(in: textRect, withAttributes: attrs)
    }
}
