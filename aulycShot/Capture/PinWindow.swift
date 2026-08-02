import AppKit

/// Where a pinned image was loaded from — drives the X-key "close and clear
/// source" behavior so a stale Finder selection or clipboard image won't keep
/// re-pinning on the next hotkey press.
enum PinSource {
    case finder
    case clipboard
    case clipboardText
}

/// A borderless, always-on-top window that holds a pinned image. Unlike a plain
/// borderless `NSWindow` it can become key, so it receives keystrokes: Esc
/// closes it, X closes it and clears the source it came from.
final class PinWindow: NSWindow {
    /// Set when the pin came from a hotkey press. nil for editor-created pins,
    /// which have no external source to clear.
    var pinSource: PinSource?

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        (contentView as? TextPinContentView)?.commitTextEditingIfNeeded()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 7: // X — close and clear the originating source.
            dismissClearingSource()
        case 53: // Esc — close only.
            dismiss()
        default:
            super.keyDown(with: event)
        }
    }

    /// Tears the window down and drops it from the manager so it deallocates.
    func dismiss() {
        orderOut(nil)
        contentView = nil
        PinWindowManager.shared.remove(self)
    }

    func dismissClearingSource() {
        clearSource()
        dismiss()
    }

    private func clearSource() {
        switch pinSource {
        case .finder:
            FinderSelection.clearSelection()
        case .clipboard, .clipboardText:
            ClipboardImageSource.clear()
        case nil:
            break
        }
    }
}

/// Builds pinned-image windows. Used by the editor's pin button and by the
/// source-specific global pin hotkeys.
