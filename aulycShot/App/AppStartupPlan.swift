struct AppStartupPlan: Equatable {
    let shouldCreateStatusBar: Bool
    let shouldInitializeApp: Bool
    let shouldShowStartupDialog: Bool

    static func make(
        launchAtLoginEnabled: Bool,
        allRequiredPermissionsGranted: Bool,
        hasPendingOpenImages: Bool
    ) -> AppStartupPlan {
        let shouldInitialize = hasPendingOpenImages
            || (launchAtLoginEnabled && allRequiredPermissionsGranted)

        return AppStartupPlan(
            shouldCreateStatusBar: true,
            shouldInitializeApp: shouldInitialize,
            shouldShowStartupDialog: !shouldInitialize
        )
    }
}
