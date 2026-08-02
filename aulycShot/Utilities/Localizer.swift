import Foundation

/// Resolves UI strings from the per-language `.lproj` bundles shipped inside
/// `aulycShot.app/Contents/Resources/`.
///
/// The app has an in-app language picker, so we can't lean on
/// `NSLocalizedString` — that keys off the *system* locale. Instead we load the
/// `.lproj` bundle for the user's chosen `AppLanguage` explicitly and look keys
/// up there, which also lets language changes take effect live.
enum Localizer {
    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var value: (lang: AppLanguage, bundle: Bundle)?
    }

    /// Sentinel returned by `localizedString` when a key is absent — distinct
    /// from any real value so we can detect misses and fall back.
    private static let missing = "\u{0}aulycShot.l10n.missing\u{0}"

    /// (language, resolved bundle) — recomputed only when the language changes.
    private static let cache = Cache()

    private static func bundle(for lang: AppLanguage) -> Bundle {
        cache.lock.lock()
        defer { cache.lock.unlock() }
        if let value = cache.value, value.lang == lang { return value.bundle }
        let resolved: Bundle
        if let path = Bundle.main.path(forResource: lang.lprojName, ofType: "lproj"),
           let lproj = Bundle(path: path) {
            resolved = lproj
        } else {
            // Running unbundled (e.g. `swift run`) — no .lproj on disk.
            resolved = .main
        }
        cache.value = (lang, resolved)
        return resolved
    }

    /// The localized string for `key` in the current language. Falls back to
    /// English, then to the raw key, so a missing entry is visible rather than
    /// crashing or blanking the UI.
    static func string(_ key: String) -> String {
        let lang = Defaults.language
        let value = bundle(for: lang).localizedString(forKey: key, value: missing, table: nil)
        if value != missing { return value }
        if lang != .en {
            let english = bundle(for: .en).localizedString(forKey: key, value: missing, table: nil)
            if english != missing { return english }
        }
        return key
    }
}
