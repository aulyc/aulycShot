import Foundation

/// A language the app's UI can be displayed in. Raw values double as the
/// `appLanguage` UserDefaults value.
enum AppLanguage: String, CaseIterable {
    case zh
    case en

    /// Folder name (without extension) of the matching `.lproj` bundle inside
    /// `aulycShot.app/Contents/Resources/`.
    var lprojName: String {
        switch self {
        case .zh: return "zh-Hans"
        case .en: return "en"
        }
    }

    /// Native language name shown in the in-app language picker.
    var displayName: String {
        switch self {
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }

    /// Best-effort match of the system's preferred languages to a supported
    /// app language — used on first launch before the user picks explicitly.
    static var systemDefault: AppLanguage {
        for code in Locale.preferredLanguages {
            let lower = code.lowercased()
            if lower.hasPrefix("zh") { return .zh }
            if lower.hasPrefix("en") { return .en }
        }
        return .en
    }
}
