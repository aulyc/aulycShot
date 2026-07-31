struct AppStartupPlan: Equatable {
    let shouldCreateStatusBar: Bool
    let shouldInitializeApp: Bool
    let shouldShowStartupDialog: Bool

    /// Process launches stay in the menu bar. Settings are shown only after an
    /// explicit user action or when a feature needs to explain missing access.
    static let silent = AppStartupPlan(
        shouldCreateStatusBar: true,
        shouldInitializeApp: true,
        shouldShowStartupDialog: false
    )
}
