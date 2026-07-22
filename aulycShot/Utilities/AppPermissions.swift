import AppKit

struct PermissionFeatureAvailability: Equatable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool

    var isAvailable: Bool {
        accessibilityGranted && screenRecordingGranted
    }

    static func make(
        accessibilityGranted: Bool,
        screenRecordingGranted: Bool
    ) -> PermissionFeatureAvailability {
        PermissionFeatureAvailability(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
    }
}

enum AppPermissions {
    static var featureAvailability: PermissionFeatureAvailability {
        PermissionFeatureAvailability.make(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
    }

    static var allRequiredGranted: Bool {
        featureAvailability.isAvailable
    }

    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static var screenRecordingGranted: Bool {
        if #available(macOS 15.0, *) {
            return CGPreflightScreenCaptureAccess()
        } else {
            guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
                return false
            }
            let myPID = ProcessInfo.processInfo.processIdentifier
            let foreignWindow = windowList.first { info in
                guard let pid = info[kCGWindowOwnerPID as String] as? Int32 else { return false }
                return pid != myPID
            }
            guard let windowID = foreignWindow?[kCGWindowNumber as String] as? CGWindowID else {
                return true
            }
            let image = CGWindowListCreateImage(
                CGRect(x: 0, y: 0, width: 1, height: 1),
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming]
            )
            return image != nil
        }
    }
}
