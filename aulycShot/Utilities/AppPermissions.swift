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
        CGPreflightScreenCaptureAccess()
    }
}
