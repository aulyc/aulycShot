import AppKit

// MARK: - Main Toolbar View

let accentGreen = NSColor(red: 0, green: 212.0/255.0, blue: 106.0/255.0, alpha: 1.0)

enum EditorOptionChrome {
    static let selectionColor = CaptureSelectionChrome.accentColor
    static let sliderTrackHeight: CGFloat = 2
    static let lineWidthValueBadgeDiameter: CGFloat = 22
    static let shapeFillSelectionBorderWidth: CGFloat = 2
    static let shapeFillSelectionDrawsBackground = false

    static func usesCircularWidthValueBadge(minValue: Double, maxValue: Double) -> Bool {
        minValue >= Defaults.editorLineWidthMin
            && maxValue <= Defaults.editorLineWidthMax
            && maxValue > minValue
    }
}
