#if os(macOS)
import Foundation

@available(macOS 13.0, *)
enum PermissionFlowLocalizer {
    private static let resourceBundleName = "aulycShot_PermissionFlow.bundle"
    private static let resourceBundle = resolveResourceBundle(
        mainResourceURL: Bundle.main.resourceURL,
        moduleFallback: { Bundle.module }
    )

    /// Resolves a localized string from the best matching `.lproj` bundle for
    /// the injected locale. This keeps all custom locale selection in one
    /// place, while still letting the rest of the UI use plain localization
    /// keys and format strings.
    static func string(
        _ key: String,
        defaultValue: String,
        localeIdentifier: String?
    ) -> String {
        localizedBundle(for: localeIdentifier)?
            .localizedString(forKey: key, value: defaultValue, table: nil)
            ?? resourceBundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    static func resolveResourceBundle(
        mainResourceURL: URL?,
        moduleFallback: () -> Bundle
    ) -> Bundle {
        if let mainResourceURL,
           let packagedBundle = Bundle(
               url: mainResourceURL.appendingPathComponent(resourceBundleName, isDirectory: true)
           ) {
            return packagedBundle
        }

        return moduleFallback()
    }

    private static func localizedBundle(for localeIdentifier: String?) -> Bundle? {
        guard let localeIdentifier, localeIdentifier.isEmpty == false else {
            return nil
        }

        let preferences = localizationPreferences(for: localeIdentifier)
        guard let localization = Bundle.preferredLocalizations(
            from: resourceBundle.localizations,
            forPreferences: preferences
        ).first,
        let path = resourceBundle.path(forResource: localization, ofType: "lproj") else {
            return nil
        }

        return Bundle(path: path)
    }

    private static func localizationPreferences(for localeIdentifier: String) -> [String] {
        let normalizedIdentifier = localeIdentifier.replacingOccurrences(of: "_", with: "-")
        let locale = Locale(identifier: normalizedIdentifier)

        var preferences = [normalizedIdentifier]
        if let identifier = locale.language.languageCode?.identifier {
            if let script = locale.language.script?.identifier {
                preferences.append("\(identifier)-\(script)")
            }
            preferences.append(identifier)
        }

        return Array(NSOrderedSet(array: preferences)) as? [String] ?? preferences
    }
}
#endif
