#if os(macOS)
import AppKit

@available(macOS 13.0, *)
@MainActor
final class SettingsNavigator {
    private let bundleIdentifier = "com.apple.systempreferences"
    private let applicationURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")

    /// Opens a settings deeplink in one workspace request so launching System
    /// Settings and routing to the requested pane cannot race each other.
    @discardableResult
    func openSettings(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            return NSWorkspace.shared.open(url)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { application, _ in
            application?.activate(options: [.activateIgnoringOtherApps])
        }
        return true
    }

    /// Re-activates the running System Settings process if it already exists.
    func activateSettings() {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?
            .activate(options: [.activateIgnoringOtherApps])
    }
}
#elseif os(iOS)
import UIKit

@available(iOS 16.0, *)
@MainActor
final class SettingsNavigator {
    /// Opens the destination URL through UIKit. iOS support is intentionally
    /// limited to URLs that the platform publicly allows.
    @discardableResult
    func openSettings(at url: URL) -> Bool {
        guard UIApplication.shared.canOpenURL(url) else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
#endif
