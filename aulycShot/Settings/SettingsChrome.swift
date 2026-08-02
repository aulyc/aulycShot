import AppKit

enum SettingsPalette {
    static let accent = NSColor(calibratedRed: 0.34, green: 0.78, blue: 0.84, alpha: 1.0)
    static let sidebarBackground = NSColor(calibratedWhite: 0.155, alpha: 1.0)
    static let contentBackground = NSColor(calibratedWhite: 0.115, alpha: 1.0)
    static let primaryText = NSColor.white.withAlphaComponent(0.94)
    static let secondaryText = NSColor.white.withAlphaComponent(0.62)
    static let tertiaryText = NSColor.white.withAlphaComponent(0.38)
    static let separator = NSColor.white.withAlphaComponent(0.10)
}

// MARK: - Flipped view (top-aligned scroll content)

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Sidebar / detail panels

final class SidebarPanel: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = SettingsPalette.sidebarBackground.cgColor
        layer?.borderColor = SettingsPalette.separator.cgColor
        layer?.borderWidth = 1
    }
}

final class DetailPanel: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = SettingsPalette.contentBackground.cgColor
    }
}
