import Foundation

enum ScreenshotImageQuality: String, CaseIterable {
    case original
    case compressed

    static let defaultValue: ScreenshotImageQuality = .original

    static func resolveSharedPreference(
        sharedRawValue: String?,
        legacySaveRawValue: String?,
        legacyClipboardRawValue: String?
    ) -> ScreenshotImageQuality {
        if let sharedRawValue {
            return normalized(rawValue: sharedRawValue)
        }

        let legacySave = normalized(rawValue: legacySaveRawValue)
        let legacyClipboard = normalized(rawValue: legacyClipboardRawValue)
        return legacySave == .compressed && legacyClipboard == .compressed
            ? .compressed
            : .original
    }

    private static func normalized(rawValue: String?) -> ScreenshotImageQuality {
        guard let rawValue else { return defaultValue }
        if rawValue == "balanced" || rawValue == "compact" {
            return .compressed
        }
        return ScreenshotImageQuality(rawValue: rawValue) ?? defaultValue
    }

    var localizedTitle: String {
        switch self {
        case .original: return L10n.screenshotQualityOriginal
        case .compressed: return L10n.screenshotQualityCompressed
        }
    }

    var localizedHint: String {
        switch self {
        case .original: return L10n.screenshotQualityOriginalHint
        case .compressed: return L10n.screenshotQualityCompressedHint
        }
    }

    var fileExtension: String {
        switch self {
        case .original: return "png"
        case .compressed: return "compressed.png"
        }
    }

    var contentType: String {
        "image/png"
    }

    var usesLossyCompression: Bool {
        self == .compressed
    }
}
