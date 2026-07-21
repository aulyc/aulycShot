import AppKit

enum AppAvailabilityState: Equatable {
    case unavailable
    case partiallyAvailable
    case normallyAvailable

    static func make(
        accessibilityGranted: Bool,
        screenRecordingGranted: Bool
    ) -> AppAvailabilityState {
        switch (accessibilityGranted, screenRecordingGranted) {
        case (false, false):
            return .unavailable
        case (true, true):
            return .normallyAvailable
        default:
            return .partiallyAvailable
        }
    }
}

enum AppPermissions {
    static var availabilityState: AppAvailabilityState {
        AppAvailabilityState.make(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
    }

    static var allRequiredGranted: Bool {
        accessibilityGranted && screenRecordingGranted
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
