import Foundation

struct Defaults {
    private static var defaults: UserDefaults {
        UserDefaults.standard
    }

    static func hotkey(for slot: HotkeySlot) -> HotkeyBinding? {
        prepareHotkeyRead(for: slot)
        let descriptor = slot.descriptor
        guard defaults.object(forKey: descriptor.keyCodeKey) != nil else { return nil }
        return HotkeyBinding(
            keyCode: UInt32(defaults.integer(forKey: descriptor.keyCodeKey)),
            modifiers: UInt32(defaults.integer(forKey: descriptor.modifiersKey))
        )
    }

    static func setHotkey(_ binding: HotkeyBinding, for slot: HotkeySlot) {
        let descriptor = slot.descriptor
        defaults.set(Int(binding.keyCode), forKey: descriptor.keyCodeKey)
        defaults.set(Int(binding.modifiers), forKey: descriptor.modifiersKey)
    }

    static func hasHotkey(for slot: HotkeySlot) -> Bool {
        prepareHotkeyRead(for: slot)
        return defaults.object(forKey: slot.descriptor.keyCodeKey) != nil
    }

    static func clearHotkey(for slot: HotkeySlot) {
        let descriptor = slot.descriptor
        defaults.removeObject(forKey: descriptor.keyCodeKey)
        defaults.removeObject(forKey: descriptor.modifiersKey)
        guard slot == .clipboard else { return }
        defaults.removeObject(forKey: "saveHotkeyKeyCode")
        defaults.removeObject(forKey: "saveHotkeyModifiers")
        defaults.set(true, forKey: "clipboardHotkeyMigrated")
    }

    private static func prepareHotkeyRead(for slot: HotkeySlot) {
        if slot == .clipboard {
            migrateLegacySaveHotkeyIfNeeded()
        }
    }

    static let selectionAspectRatioPresets: [CGFloat] = [
        1.0,
        2.35,
        3.0,
        3.0 / 2.0,
        4.0 / 3.0,
        9.0 / 16.0,
        16.0 / 9.0,
    ]

    static var selectionAspectRatio: Double {
        get {
            let ratio = defaults.double(forKey: "selectionAspectRatio")
            return ratio > 0 && ratio.isFinite ? ratio : 0
        }
        set {
            guard newValue > 0, newValue.isFinite else {
                clearSelectionAspectRatio()
                return
            }
            defaults.set(newValue, forKey: "selectionAspectRatio")
        }
    }

    static var hasSelectionAspectRatio: Bool {
        defaults.object(forKey: "selectionAspectRatio") != nil && selectionAspectRatio > 0
    }

    static func clearSelectionAspectRatio() {
        defaults.removeObject(forKey: "selectionAspectRatio")
    }

    private static func clearLegacyPinHotkey() {
        defaults.removeObject(forKey: "pinHotkeyKeyCode")
        defaults.removeObject(forKey: "pinHotkeyModifiers")
    }

    static func resetShortcutHotkeysToDefaults() {
        for slot in HotkeySlot.allCases {
            clearHotkey(for: slot)
        }
        clearLegacyPinHotkey()
    }

    static var imageMergeTemplate: ImageMergeTemplate {
        get {
            let rawValue = defaults.integer(forKey: "imageMergeTemplate")
            return ImageMergeTemplate(rawValue: rawValue) ?? .horizontal
        }
        set {
            defaults.set(newValue.rawValue, forKey: "imageMergeTemplate")
        }
    }

    static var imageMergeSpacingPreset: ImageMergeSpacingPreset {
        get {
            let rawValue: CGFloat
            if defaults.object(forKey: "imageMergeSpacing") == nil {
                rawValue = ImageMergeSpacingPreset.medium.value
            } else {
                rawValue = CGFloat(defaults.double(forKey: "imageMergeSpacing"))
            }
            let preset = ImageMergeSpacingPreset.nearest(to: rawValue)
            defaults.set(Double(preset.value), forKey: "imageMergeSpacing")
            return preset
        }
        set {
            defaults.set(Double(newValue.value), forKey: "imageMergeSpacing")
        }
    }

    static var imageMergeMarginPreset: ImageMergeMarginPreset {
        get {
            let rawValue: CGFloat
            if defaults.object(forKey: "imageMergeMargin") == nil {
                rawValue = ImageMergeMarginPreset.medium.value
            } else {
                rawValue = CGFloat(defaults.double(forKey: "imageMergeMargin"))
            }
            let preset = ImageMergeMarginPreset.nearest(to: rawValue)
            defaults.set(Double(preset.value), forKey: "imageMergeMargin")
            return preset
        }
        set {
            defaults.set(Double(newValue.value), forKey: "imageMergeMargin")
        }
    }

    static var imageMergeCornerPreset: ImageMergeCornerPreset {
        get {
            let rawValue: CGFloat
            if defaults.object(forKey: "imageMergeCornerRadius") == nil {
                rawValue = ImageMergeCornerPreset.square.value
            } else {
                rawValue = CGFloat(defaults.double(forKey: "imageMergeCornerRadius"))
            }
            let preset = ImageMergeCornerPreset.nearest(to: rawValue)
            defaults.set(Double(preset.value), forKey: "imageMergeCornerRadius")
            return preset
        }
        set {
            defaults.set(Double(newValue.value), forKey: "imageMergeCornerRadius")
        }
    }

    static var imageMergeSpacing: Double {
        get { Double(imageMergeSpacingPreset.value) }
        set { imageMergeSpacingPreset = .nearest(to: CGFloat(newValue)) }
    }

    static var imageMergeMargin: Double {
        get { Double(imageMergeMarginPreset.value) }
        set { imageMergeMarginPreset = .nearest(to: CGFloat(newValue)) }
    }

    static var imageMergeCornerRadius: Double {
        get { Double(imageMergeCornerPreset.value) }
        set { imageMergeCornerPreset = .nearest(to: CGFloat(newValue)) }
    }

    static var imageMergeBackgroundIsSolid: Bool {
        get { defaults.bool(forKey: "imageMergeBackgroundIsSolid") }
        set { defaults.set(newValue, forKey: "imageMergeBackgroundIsSolid") }
    }

    static var imageMergeBackgroundColorHex: String {
        get {
            normalizedHexColor(defaults.string(forKey: "imageMergeBackgroundColorHex")) ?? "#FFFFFF"
        }
        set {
            defaults.set(normalizedHexColor(newValue) ?? "#FFFFFF", forKey: "imageMergeBackgroundColorHex")
        }
    }

    static var recordingSaveFormat: ScreenRecordingFormat {
        get {
            guard let raw = defaults.string(forKey: "recordingSaveFormat"),
                  let format = ScreenRecordingFormat(rawValue: raw)
            else {
                return .mp4
            }
            return format
        }
        set {
            defaults.set(newValue.rawValue, forKey: "recordingSaveFormat")
        }
    }

    static var recordingSavePreference: RecordingSavePreference {
        get {
            guard let raw = defaults.string(forKey: "recordingSavePreference"),
                  let preference = RecordingSavePreference(rawValue: raw)
            else {
                return .manual
            }
            return preference
        }
        set {
            defaults.set(newValue.rawValue, forKey: "recordingSavePreference")
        }
    }

    static var defaultRecordingSaveDirectory: URL {
        defaultDocumentsDirectory.appendingPathComponent("record", isDirectory: true)
    }

    static var defaultScreenshotSaveDirectory: URL {
        defaultDocumentsDirectory.appendingPathComponent("screenshots", isDirectory: true)
    }

    static var recordingSaveDirectory: URL {
        get {
            normalizedDirectoryURL(
                defaults.string(forKey: "recordingSaveDirectory"),
                fallback: defaultRecordingSaveDirectory
            )
        }
        set {
            let normalized = newValue.standardizedFileURL
            let oldValue = recordingSaveDirectory
            defaults.set(normalized.path, forKey: "recordingSaveDirectory")
            if oldValue != normalized {
                NotificationCenter.default.post(name: .recordingSaveDirectoryDidChange, object: nil)
            }
        }
    }

    static var lastCustomRecordingSaveDirectory: URL? {
        get {
            guard let path = defaults.string(forKey: "lastCustomRecordingSaveDirectory"),
                  !path.isEmpty
            else {
                return nil
            }
            return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: "lastCustomRecordingSaveDirectory")
                return
            }
            defaults.set(newValue.standardizedFileURL.path, forKey: "lastCustomRecordingSaveDirectory")
        }
    }

    static var screenshotSaveDirectory: URL {
        get {
            normalizedDirectoryURL(
                defaults.string(forKey: "screenshotSaveDirectory"),
                fallback: defaultScreenshotSaveDirectory
            )
        }
        set {
            defaults.set(newValue.standardizedFileURL.path, forKey: "screenshotSaveDirectory")
        }
    }

    static var screenshotQuality: ScreenshotImageQuality {
        get {
            let quality = ScreenshotImageQuality.resolveSharedPreference(
                sharedRawValue: defaults.string(forKey: "screenshotQuality"),
                legacySaveRawValue: defaults.string(forKey: "screenshotSaveQuality"),
                legacyClipboardRawValue: defaults.string(forKey: "screenshotClipboardQuality")
            )
            defaults.set(quality.rawValue, forKey: "screenshotQuality")
            defaults.removeObject(forKey: "screenshotSaveQuality")
            defaults.removeObject(forKey: "screenshotClipboardQuality")
            return quality
        }
        set {
            defaults.set(newValue.rawValue, forKey: "screenshotQuality")
            defaults.removeObject(forKey: "screenshotSaveQuality")
            defaults.removeObject(forKey: "screenshotClipboardQuality")
        }
    }

    static var screenshotOutputMode: ScreenshotOutputMode {
        get {
            guard let raw = defaults.string(forKey: "screenshotOutputMode") else {
                return ScreenshotOutputMode.defaultValue
            }
            return ScreenshotOutputMode(rawValue: raw) ?? ScreenshotOutputMode.defaultValue
        }
        set {
            defaults.set(newValue.rawValue, forKey: "screenshotOutputMode")
        }
    }

    private static var defaultDocumentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
    }

    private static func normalizedDirectoryURL(_ value: String?, fallback: URL) -> URL {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback.standardizedFileURL }
        let expanded = (trimmed as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    }

    private static func migrateLegacySaveHotkeyIfNeeded() {
        // aulycShot ≤ 1.x stored this same hotkey under "saveHotkey*". Migrate
        // once on first read so existing users don't lose their binding.
        let migratedKey = "clipboardHotkeyMigrated"
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)
        guard defaults.object(forKey: "saveHotkeyKeyCode") != nil,
              defaults.object(forKey: "clipboardHotkeyKeyCode") == nil
        else { return }
        defaults.set(defaults.integer(forKey: "saveHotkeyKeyCode"), forKey: "clipboardHotkeyKeyCode")
        defaults.set(defaults.integer(forKey: "saveHotkeyModifiers"), forKey: "clipboardHotkeyModifiers")
        defaults.removeObject(forKey: "saveHotkeyKeyCode")
        defaults.removeObject(forKey: "saveHotkeyModifiers")
    }

    static var penColor: Int {
        get {
            let val = defaults.integer(forKey: "penColor")
            return val == 0 ? 0xFF0000 : val
        }
        set {
            defaults.set(newValue, forKey: "penColor")
        }
    }

    static var penWidth: Double {
        get {
            let val = defaults.double(forKey: "penWidth")
            return val > 0 ? val : 3.0
        }
        set {
            defaults.set(newValue, forKey: "penWidth")
        }
    }

    static let editorLineWidthMin: Double = 1
    static let editorLineWidthMax: Double = 16
    static let markerLineWidthMax: Double = 10

    static var lastEditorColorHex: String? {
        get {
            normalizedHexColor(defaults.string(forKey: "lastEditorColorHex"))
        }
        set {
            if let normalized = normalizedHexColor(newValue) {
                defaults.set(normalized, forKey: "lastEditorColorHex")
            } else {
                defaults.removeObject(forKey: "lastEditorColorHex")
            }
        }
    }

    static var lastEditorLineWidth: Double {
        get {
            if defaults.object(forKey: "lastEditorLineWidth") == nil {
                return 4.0
            }
            return clampedEditorLineWidth(defaults.double(forKey: "lastEditorLineWidth"))
        }
        set {
            defaults.set(clampedEditorLineWidth(newValue), forKey: "lastEditorLineWidth")
        }
    }

    static var lastMarkerColorHex: String? {
        get {
            normalizedHexColor(defaults.string(forKey: "lastMarkerColorHex"))
        }
        set {
            if let normalized = normalizedHexColor(newValue) {
                defaults.set(normalized, forKey: "lastMarkerColorHex")
            } else {
                defaults.removeObject(forKey: "lastMarkerColorHex")
            }
        }
    }

    static var lastMarkerLineWidth: Double {
        get {
            if defaults.object(forKey: "lastMarkerLineWidth") == nil {
                return 5.0
            }
            return clampedMarkerLineWidth(defaults.double(forKey: "lastMarkerLineWidth"))
        }
        set {
            defaults.set(clampedMarkerLineWidth(newValue), forKey: "lastMarkerLineWidth")
        }
    }

    static var mosaicBlockSize: Double {
        get {
            let val = defaults.double(forKey: "mosaicBlockSize")
            guard val > 0 else { return 12.0 }
            return min(max(val, mosaicBlockSizeMin), mosaicBlockSizeMax)
        }
        set {
            defaults.set(min(max(newValue, mosaicBlockSizeMin), mosaicBlockSizeMax), forKey: "mosaicBlockSize")
        }
    }

    static let mosaicBlockSizeMin: Double = 4
    static let mosaicBlockSizeMax: Double = 48

    static let textFontSizeMin: Double = 10
    static let textFontSizeMax: Double = 100

    static var lastTextFontSize: Double {
        get {
            if defaults.object(forKey: "lastTextFontSize") == nil {
                return 20
            }
            let val = defaults.double(forKey: "lastTextFontSize")
            return min(max(val, textFontSizeMin), textFontSizeMax)
        }
        set {
            defaults.set(min(max(newValue, textFontSizeMin), textFontSizeMax), forKey: "lastTextFontSize")
        }
    }

    /// Whether the text tool's outline checkbox was last left on.
    static var lastTextStroke: Bool {
        get { defaults.bool(forKey: "lastTextStroke") }
        set { defaults.set(newValue, forKey: "lastTextStroke") }
    }

    /// Whether the text tool's callout checkbox was last left on.
    static var lastTextCallout: Bool {
        get { defaults.bool(forKey: "lastTextCallout") }
        set { defaults.set(newValue, forKey: "lastTextCallout") }
    }

    /// Last rectangle/ellipse fill mode. Migrates the previous checkbox
    /// preference by treating its "on" state as the old opaque fill.
    static var lastShapeFillMode: ShapeFillMode {
        get {
            guard let raw = defaults.string(forKey: "lastShapeFillMode"),
                  let mode = ShapeFillMode(rawValue: raw) else {
                return defaults.bool(forKey: "lastShapeFill") ? .opaque : .none
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: "lastShapeFillMode")
            defaults.set(newValue.isFilled, forKey: "lastShapeFill")
        }
    }

    static var lastShapeStrokeStyle: ShapeStrokeStyle {
        get {
            guard let raw = defaults.string(forKey: "lastShapeStrokeStyle"),
                  let style = ShapeStrokeStyle(rawValue: raw) else {
                return .standard
            }
            return style
        }
        set {
            defaults.set(newValue.rawValue, forKey: "lastShapeStrokeStyle")
        }
    }

    /// Whether the rectangle/ellipse tool's legacy fill checkbox was last left on.
    static var lastShapeFill: Bool {
        get { lastShapeFillMode.isFilled }
        set { lastShapeFillMode = newValue ? .opaque : .none }
    }

    static var lastArrowStyle: ArrowStyle {
        get {
            guard let raw = defaults.string(forKey: "lastArrowStyle"),
                  let style = ArrowStyle(rawValue: raw) else {
                return .tapered
            }
            return style
        }
        set {
            defaults.set(newValue.rawValue, forKey: "lastArrowStyle")
        }
    }

    private static func normalizedHexColor(_ hex: String?) -> String? {
        guard var trimmed = hex?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
            return nil
        }
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, UInt32(trimmed, radix: 16) != nil else { return nil }
        return "#\(trimmed)"
    }

    private static func clampedEditorLineWidth(_ width: Double) -> Double {
        min(max(width, editorLineWidthMin), editorLineWidthMax)
    }

    private static func clampedMarkerLineWidth(_ width: Double) -> Double {
        min(max(width, editorLineWidthMin), markerLineWidthMax)
    }

    static var demoMode: Bool {
        get { defaults.bool(forKey: "demoMode") }
        set { defaults.set(newValue, forKey: "demoMode") }
    }

    static var showMenuBar: Bool {
        get {
            if defaults.object(forKey: "showMenuBar") == nil {
                return true
            }
            return defaults.bool(forKey: "showMenuBar")
        }
        set {
            defaults.set(newValue, forKey: "showMenuBar")
        }
    }

    static var automaticUpdateChecksEnabled: Bool {
        get {
            if defaults.object(forKey: "automaticUpdateChecksEnabled") == nil {
                return true
            }
            return defaults.bool(forKey: "automaticUpdateChecksEnabled")
        }
        set {
            defaults.set(newValue, forKey: "automaticUpdateChecksEnabled")
        }
    }

    static var language: AppLanguage {
        get {
            // Explicit user choice wins; otherwise follow the system locale on
            // first launch so a fresh install opens in a familiar language.
            if let raw = defaults.string(forKey: "appLanguage"),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return AppLanguage.systemDefault
        }
        set {
            let old = language
            defaults.set(newValue.rawValue, forKey: "appLanguage")
            if newValue != old {
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }
    }
}
