import AppKit

// MARK: - Editable Text Field

/// Borderless transparent NSTextField that auto-grows to fit its content
/// and reports commit/cancel via closures. Used by the text annotation
/// tool while the user is typing.
final class EditableTextField: NSTextField, NSTextFieldDelegate {
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onChange: (() -> Void)?

    /// Outline flag for the text being edited. Carried through the edit
    /// session and read back when the annotation is committed. The live field
    /// shows plain text; the outline is rendered on the committed
    /// `TextAnnotation`, which adds it without shifting the glyphs.
    var hasStroke: Bool = false
    var annotationColor: NSColor = EditorStyleDefaults.primaryColor {
        didSet {
            updateAppearanceForCurrentMode()
            onChange?()
        }
    }
    var hasCallout: Bool = false {
        didSet {
            updateAppearanceForCurrentMode()
            onChange?()
        }
    }
    var calloutTip: NSPoint? {
        didSet { onChange?() }
    }
    /// Rotation carried by an existing text annotation while it is being edited.
    /// The live editor stays horizontal, but the committed annotation keeps the
    /// original angle instead of snapping back to zero.
    var rotation: CGFloat = 0

    var annotationOrigin: NSPoint {
        guard hasCallout else { return frame.origin }
        return NSPoint(
            x: frame.minX + TextAnnotation.calloutHorizontalPadding,
            y: frame.minY + TextAnnotation.calloutVerticalPadding
        )
    }

    private var didFinish = false
    private var wasCanceled = false
    private static let insertNewlineIgnoringFieldEditorSelector = #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
    private static let insertLineBreakSelector = #selector(NSResponder.insertLineBreak(_:))

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        isBordered = false
        isBezeled = false
        drawsBackground = false
        backgroundColor = .clear
        focusRingType = .none
        delegate = self
        cell?.usesSingleLineMode = false
        cell?.wraps = false
        cell?.isScrollable = false
        maximumNumberOfLines = 0
        target = self
        action = #selector(commitFromAction)
        stringValue = ""
        placeholderString = ""

        // Visible editing border so the user can tell where the field is on
        // screen (the rest of the field is fully transparent over the
        // canvas content).
        wantsLayer = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.85).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 2
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
    }

    private func updateAppearanceForCurrentMode() {
        if hasCallout {
            textColor = TextAnnotation.contrastingTextColor(for: annotationColor)
            layer?.backgroundColor = annotationColor.cgColor
            layer?.cornerRadius = TextAnnotation.calloutCornerRadius
        } else {
            textColor = annotationColor
            layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
            layer?.cornerRadius = 2
        }
    }

    @objc private func commitFromAction() {
        commit()
    }

    func commit() {
        guard !didFinish else { return }
        didFinish = true
        onCommit?(stringValue)
    }

    func cancel() {
        guard !didFinish else { return }
        didFinish = true
        onCancel?()
    }

    func controlTextDidChange(_ obj: Notification) {
        sizeToFitText()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !didFinish else { return }
        if wasCanceled {
            cancel()
        } else {
            commit()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            wasCanceled = true
            window?.makeFirstResponder(nil)
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
            if modifiers.contains(.shift) {
                insertLineBreak(in: textView)
            } else {
                window?.makeFirstResponder(nil)
            }
            return true
        }
        if commandSelector == Self.insertNewlineIgnoringFieldEditorSelector
            || commandSelector == Self.insertLineBreakSelector {
            insertLineBreak(in: textView)
            return true
        }
        return false
    }

    private func insertLineBreak(in textView: NSTextView) {
        textView.insertText("\n", replacementRange: textView.selectedRange())
        stringValue = textView.string
        sizeToFitText()
    }

    /// The app has no main menu, so standard editing key equivalents
    /// (⌘A/⌘C/⌘V/⌘X/⌘Z/⇧⌘Z) never reach the field editor. Route them
    /// here while we hold focus.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === currentEditor() else {
            return super.performKeyEquivalent(with: event)
        }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd: NSEvent.ModifierFlags = .command
        let cmdShift: NSEvent.ModifierFlags = [.command, .shift]
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        if mods == cmd {
            switch chars {
            case "a": currentEditor()?.selectAll(nil); return true
            case "c": currentEditor()?.copy(nil); return true
            case "v": currentEditor()?.paste(nil); return true
            case "x": currentEditor()?.cut(nil); return true
            case "z":
                if let undoMgr = currentEditor()?.undoManager, undoMgr.canUndo {
                    undoMgr.undo(); return true
                }
            default: break
            }
        } else if mods == cmdShift, chars == "z" {
            if let undoMgr = currentEditor()?.undoManager, undoMgr.canRedo {
                undoMgr.redo(); return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Recompute width/height from the current string + font, keeping the
    /// top edge anchored so text grows downward only when font size changes.
    func sizeToFitText() {
        guard let font = font else { return }
        let contentSize = TextAnnotation.editorSize(for: stringValue, font: font)
        let size = hasCallout
            ? NSSize(
                width: contentSize.width + TextAnnotation.calloutHorizontalPadding * 2,
                height: contentSize.height + TextAnnotation.calloutVerticalPadding * 2
            )
            : contentSize

        let prevTop = frame.maxY
        var f = frame
        f.size = size
        f.origin.y = prevTop - size.height
        frame = f
        onChange?()
    }
}
