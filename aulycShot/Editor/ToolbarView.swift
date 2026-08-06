import AppKit

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        target = self
        action = #selector(run)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}

class ToolbarView: NSView {
    enum Orientation { case horizontal, vertical }

    /// Button run geometry. `preferredSize` derives the capsule size from
    /// these so the dark background always wraps the buttons exactly.
    static let buttonSize: CGFloat = 32
    static let buttonSpacing: CGFloat = 6
    /// Inset along the main axis at both ends of the run.
    static let endPadding: CGFloat = 15
    /// Inset on the cross axis — keeps a 44pt-thick capsule around 32pt buttons.
    static let crossPadding: CGFloat = 6

    let orientation: Orientation
    private let items: [ToolbarItemID]

    /// Size that fits the current items in the current orientation.
    var preferredSize: NSSize {
        let n = items.count
        let run = CGFloat(n) * Self.buttonSize
            + CGFloat(max(0, n - 1)) * Self.buttonSpacing
            + Self.endPadding * 2
        let thickness = Self.buttonSize + Self.crossPadding * 2
        switch orientation {
        case .horizontal: return NSSize(width: max(run, thickness), height: thickness)
        case .vertical:   return NSSize(width: thickness, height: max(run, thickness))
        }
    }

    var onToolSelected: ((EditTool) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onInsertImage: (() -> Void)?
    var onQRCode: (() -> Void)?
    var onSave: (() -> Void)?
    var onPin: (() -> Void)?
    var onRecord: (() -> Void)?
    var onClose: (() -> Void)?
    var onConfirm: (() -> Void)?

    /// Every button keyed by its id — drives selection state, enable/disable,
    /// and frame lookups.
    private var buttons: [ToolbarItemID: NSView] = [:]
    /// Last tool the controller selected. Tracked so a second click on the
    /// already-selected tool button toggles back to "no tool" (adjust mode).
    private var currentTool: EditTool = .none

    init(items: [ToolbarItemID], orientation: Orientation) {
        self.items = items
        self.orientation = orientation
        super.init(frame: NSRect(origin: .zero, size: .zero))
        setFrameSize(preferredSize)
        setupButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func updateSelection(tool: EditTool) {
        currentTool = tool
        for (id, view) in buttons {
            guard id.kind == .toggleTool, let btn = view as? ToolButton else { continue }
            btn.isSelected = (id.editTool == tool)
        }
    }

    /// Sets the active highlight on a stateful button. No-op if this toolbar
    /// doesn't hold the item.
    func setActive(_ active: Bool, for id: ToolbarItemID) {
        (buttons[id] as? ToolButton)?.isSelected = active
    }

    /// Enables/disables a button and dims it when disabled.
    func setEnabled(_ enabled: Bool, for id: ToolbarItemID) {
        guard let btn = buttons[id] as? ToolButton else { return }
        btn.isEnabled = enabled
        btn.alphaValue = enabled ? 1.0 : 0.35
    }

    /// Frame of an item's button in this toolbar's coordinate space.
    func frame(for id: ToolbarItemID) -> NSRect? { buttons[id]?.frame }

    // Convenience wrappers so callers don't repeat the id literals.
    func setUndoEnabled(_ enabled: Bool) { setEnabled(enabled, for: .undo) }
    func setRedoEnabled(_ enabled: Bool) { setEnabled(enabled, for: .redo) }
    func setRecordingEnabled(_ enabled: Bool) {
        setEnabled(enabled, for: .record)
    }

    private func setupButtons() {
        let size = Self.buttonSize
        let step = size + Self.buttonSpacing
        for (index, id) in items.enumerated() {
            let along = Self.endPadding + CGFloat(index) * step
            let frame: NSRect
            switch orientation {
            case .horizontal:
                frame = NSRect(x: along, y: Self.crossPadding, width: size, height: size)
            case .vertical:
                // AppKit y grows upward, so the first item sits at the top.
                let y = bounds.height - Self.endPadding - size - CGFloat(index) * step
                frame = NSRect(x: Self.crossPadding, y: y, width: size, height: size)
            }
            let view = makeButton(for: id, index: index, frame: frame)
            buttons[id] = view
            addSubview(view)
        }
    }

    private func makeButton(for id: ToolbarItemID, index: Int, frame: NSRect) -> NSView {
        let btn = ToolButton(
            frame: frame,
            image: id.toolbarIconImage(pointSize: 14),
            normalColor: id.normalColor,
            selectedColor: id.selectedColor
        )
        btn.hoverTip = id.tooltip
        btn.identifier = NSUserInterfaceItemIdentifier("editor-toolbar-\(id.rawValue)")
        btn.setAccessibilityLabel(id.tooltip)
        btn.setAccessibilityIdentifier("editor-toolbar-\(id.rawValue)")
        btn.target = self
        btn.action = #selector(buttonTapped(_:))
        btn.tag = index
        return btn
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }

    @objc private func buttonTapped(_ sender: ToolButton) {
        guard sender.tag >= 0, sender.tag < items.count else { return }
        let id = items[sender.tag]
        switch id {
        case .rectangle, .ellipse, .arrow, .line, .pen, .marker, .mosaic, .eraser, .magnifier, .numbered, .text:
            guard let tool = id.editTool else { return }
            // Click an already-selected tool to deselect it and enter adjust
            // mode (no tool, but existing marks remain draggable).
            onToolSelected?(tool == currentTool ? .none : tool)
        case .insertImage:   onInsertImage?()
        case .undo:          onUndo?()
        case .redo:          onRedo?()
        case .qrCode:        onQRCode?()
        case .save:          onSave?()
        case .pin:           onPin?()
        case .record:        onRecord?()
        case .close:         onClose?()
        case .confirm:       onConfirm?()
        }
    }
}
