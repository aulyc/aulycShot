import AppKit

// MARK: - Crop Presentation Geometry

enum ScrollCropPresentationGeometry {
    static let controlSize = NSSize(width: 56, height: 44)

    static func cropFrame(selectionRect: NSRect, hostBounds: NSRect) -> NSRect? {
        let clipped = selectionRect.standardized.intersection(hostBounds.standardized)
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return nil }
        return clipped
    }

    static func controlOrigin(
        anchorRect: NSRect,
        visibleFrame: NSRect,
        controlSize: NSSize = controlSize,
        gap: CGFloat = 12,
        margin: CGFloat = 12
    ) -> NSPoint {
        let minX = visibleFrame.minX + margin
        let maxX = max(minX, visibleFrame.maxX - margin - controlSize.width)
        let centeredX = anchorRect.midX - controlSize.width / 2
        let x = min(max(centeredX, minX), maxX)

        let minY = visibleFrame.minY + margin
        let maxY = max(minY, visibleFrame.maxY - margin - controlSize.height)
        let belowY = anchorRect.minY - gap - controlSize.height
        let aboveY = anchorRect.maxY + gap
        let y: CGFloat
        if belowY >= minY {
            y = min(belowY, maxY)
        } else if aboveY <= maxY {
            y = max(aboveY, minY)
        } else {
            // A nearly full-screen selection leaves no outside edge available.
            // Keep the control close to its lower edge while remaining visible.
            y = min(max(anchorRect.minY + gap, minY), maxY)
        }

        return NSPoint(x: x, y: y)
    }
}

// MARK: - Crop Mode Control Window

/// Floating confirm button shown during crop mode. Stays on screen
/// regardless of how far the user scrolls the long screenshot.
final class ScrollCropControlWindow: NSPanel {
    private static let windowSize = ScrollCropPresentationGeometry.controlSize

    init(onConfirm: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver + 4
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = ScrollCropControlView(
            frame: NSRect(origin: .zero, size: Self.windowSize),
            onConfirm: onConfirm
        )
    }

    func position(near anchorRect: NSRect, within screen: NSScreen) {
        setFrameOrigin(ScrollCropPresentationGeometry.controlOrigin(
            anchorRect: anchorRect,
            visibleFrame: screen.visibleFrame,
            controlSize: frame.size
        ))
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
    }
}

private final class ScrollCropControlView: NSView {
    private let onConfirm: () -> Void

    init(frame: NSRect, onConfirm: @escaping () -> Void) {
        self.onConfirm = onConfirm
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        let button = ToolButton(
            frame: bounds.insetBy(dx: 6, dy: 6),
            symbolName: "checkmark",
            normalColor: accentGreen,
            selectedColor: accentGreen
        )
        button.hoverTip = L10n.tipScrollCropConfirm
        button.target = self
        button.action = #selector(confirmTapped)
        addSubview(button)
    }

    @objc private func confirmTapped() {
        onConfirm()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}
