import AppKit

final class ScrollCaptureHintWindow: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private let horizontalPadding: CGFloat = 14
    private let verticalPadding: CGFloat = 8
    /// Gap between the selection's top edge and the hint pill.
    private let topInset: CGFloat = 12

    init(text: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
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

        let container = AdaptiveChromeSurfaceView(style: .floating, cornerRadius: 8)

        label.stringValue = text
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        container.addSubview(label)
        contentView = container
    }

    /// Size to the text and place top-center inside `selectionRect`
    /// (AppKit screen coordinates).
    func present(in selectionRect: NSRect) {
        label.sizeToFit()
        let textSize = label.frame.size
        let width = textSize.width + horizontalPadding * 2
        let height = textSize.height + verticalPadding * 2

        contentView?.frame = NSRect(x: 0, y: 0, width: width, height: height)
        label.setFrameOrigin(NSPoint(x: horizontalPadding, y: verticalPadding))

        let origin = NSPoint(
            x: selectionRect.midX - width / 2,
            y: selectionRect.maxY - topInset - height
        )
        setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
    }
}

final class ScrollCaptureControlWindow: NSPanel {
    init(buttonFrame: NSRect, onTap: @escaping () -> Void) {
        let padding: CGFloat = 6
        let windowRect = NSRect(
            x: buttonFrame.minX - padding,
            y: buttonFrame.minY - padding,
            width: buttonFrame.width + padding * 2,
            height: buttonFrame.height + padding * 2
        )

        super.init(
            contentRect: windowRect,
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

        contentView = ScrollCaptureControlView(
            frame: NSRect(origin: .zero, size: windowRect.size),
            onTap: onTap
        )
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
    }
}

private final class ScrollCaptureControlView: NSView {
    private let onTap: () -> Void

    init(frame: NSRect, onTap: @escaping () -> Void) {
        self.onTap = onTap
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
            symbolName: "arrow.up.and.down.text.horizontal",
            normalColor: .labelColor,
            selectedColor: accentGreen
        )
        button.isSelected = true
        button.target = self
        button.action = #selector(buttonTapped)
        addSubview(button)
    }

    @objc private func buttonTapped() {
        onTap()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}
