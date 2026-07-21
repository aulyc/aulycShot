struct AppStartupPlan: Equatable {
    let shouldCreateStatusBar: Bool
    let shouldInitializeApp: Bool
    let shouldShowStartupDialog: Bool

    static func make(
        launchAtLoginEnabled: Bool,
        allRequiredPermissionsGranted: Bool,
        hasPendingOpenImages: Bool
    ) -> AppStartupPlan {
        let shouldSkipStartupDialog = hasPendingOpenImages
            || (launchAtLoginEnabled && allRequiredPermissionsGranted)

        return AppStartupPlan(
            shouldCreateStatusBar: true,
            shouldInitializeApp: true,
            shouldShowStartupDialog: !shouldSkipStartupDialog
        )
    }
}
