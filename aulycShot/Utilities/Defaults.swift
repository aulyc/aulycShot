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

extension Notification.Name {
    static let languageDidChange = Notification.Name("aulycShot.languageDidChange")
    static let recordingSaveDirectoryDidChange = Notification.Name("aulycShot.recordingSaveDirectoryDidChange")
    static let hotkeyDidChange = Notification.Name("aulycShot.hotkeyDidChange")
}

/// Centralized accessor for every user-facing string. Each property resolves a
/// key from the current language's `Localizable.strings`; the translations
/// themselves live in `Resources/<lang>.lproj/Localizable.strings`.
enum L10n {
    static var lang: AppLanguage { Defaults.language }

    private static func s(_ key: String) -> String { Localizer.string(key) }

    // Settings
    static var settingsTitle: String { s("settingsTitle") }
    static var showMenuBarIcon: String { s("showMenuBarIcon") }
    static var settingEnabled: String { s("settingEnabled") }
    static var settingDisabled: String { s("settingDisabled") }
    static var featurePermissionStatus: String { s("featurePermissionStatus") }
    static var permissionAvailable: String { s("permissionAvailable") }
    static var permissionUnavailable: String { s("permissionUnavailable") }
    static var featurePermissionHelpTooltip: String { s("featurePermissionHelpTooltip") }
    static var featurePermissionHelpTitle: String { s("featurePermissionHelpTitle") }
    static func featurePermissionHelpBody(
        accessibilityStatus: String,
        screenRecordingStatus: String
    ) -> String {
        String(
            format: s("featurePermissionHelpBody"),
            accessibilityStatus,
            screenRecordingStatus
        )
    }
    static var permissionHelpOpenAccessibility: String { s("permissionHelpOpenAccessibility") }
    static var permissionHelpOpenScreenRecording: String { s("permissionHelpOpenScreenRecording") }
    static var permissionHelpDone: String { s("permissionHelpDone") }
    static var launchAtLogin: String { s("launchAtLogin") }
    static var demoMode: String { s("demoMode") }
    static var demoModeHint: String { s("demoModeHint") }
    static var recordingSavePathLabel: String { s("recordingSavePathLabel") }
    static var recordingSaveFormatSettingLabel: String { s("recordingSaveFormatSettingLabel") }
    static var screenshotSavePathLabel: String { s("screenshotSavePathLabel") }
    static var savePathChoose: String { s("savePathChoose") }
    static var savePathReveal: String { s("savePathReveal") }
    static var chooseRecordingSavePathTitle: String { s("chooseRecordingSavePathTitle") }
    static var chooseScreenshotSavePathTitle: String { s("chooseScreenshotSavePathTitle") }
    static var screenshotQualityLabel: String { s("screenshotQualityLabel") }
    static var screenshotQualityOriginal: String { s("screenshotQualityOriginal") }
    static var screenshotQualityOriginalHint: String { s("screenshotQualityOriginalHint") }
    static var screenshotQualityCompressed: String { s("screenshotQualityCompressed") }
    static var screenshotQualityCompressedHint: String { s("screenshotQualityCompressedHint") }
    static var screenshotQualityCompressingSave: String { s("screenshotQualityCompressingSave") }
    static var screenshotQualityCompressingClipboard: String { s("screenshotQualityCompressingClipboard") }
    static var screenshotCompressionFailed: String { s("screenshotCompressionFailed") }
    static var screenshotOutputActionLabel: String { s("screenshotOutputActionLabel") }
    static var screenshotOutputClipboardOnly: String { s("screenshotOutputClipboardOnly") }
    static var screenshotOutputFileOnly: String { s("screenshotOutputFileOnly") }
    static var screenshotOutputClipboardAndFile: String { s("screenshotOutputClipboardAndFile") }
    static var screenshotOutputProcessing: String { s("screenshotOutputProcessing") }
    static func screenshotCopiedAndSaved(to path: String) -> String {
        String(format: s("screenshotCopiedAndSaved"), path)
    }

    // Screenshot shortcut
    static var shortcutHeader: String { s("shortcutHeader") }
    static var shortcutHint: String { s("shortcutHint") }
    static var shortcutDefaultDisplay: String { s("shortcutDefaultDisplay") }
    static var shortcutSet: String { s("shortcutSet") }
    static var shortcutCancel: String { s("shortcutCancel") }
    static var shortcutWaiting: String { s("shortcutWaiting") }
    static var shortcutNeedsModifierTitle: String { s("shortcutNeedsModifierTitle") }
    static var shortcutNeedsModifier: String { s("shortcutNeedsModifier") }

    // Pin-image shortcut
    static var selectedImagePinShortcutHeader: String { s("selectedImagePinShortcutHeader") }
    static var selectedImagePinShortcutDefaultDisplay: String { s("selectedImagePinShortcutDefaultDisplay") }
    static var clipboardImagePinShortcutHeader: String { s("clipboardImagePinShortcutHeader") }
    static var clipboardImagePinShortcutDefaultDisplay: String { s("clipboardImagePinShortcutDefaultDisplay") }
    static var clipboardTextPinShortcutHeader: String { s("clipboardTextPinShortcutHeader") }
    static var clipboardTextPinShortcutDefaultDisplay: String { s("clipboardTextPinShortcutDefaultDisplay") }
    static var selectedImagePinNoImage: String { s("selectedImagePinNoImage") }
    static var clipboardImagePinNoImage: String { s("clipboardImagePinNoImage") }
    static var clipboardTextPinNoText: String { s("clipboardTextPinNoText") }
    static var pinFromFinderHint: String { s("pinFromFinderHint") }
    static var pinFromClipboardHint: String { s("pinFromClipboardHint") }
    static var pinFromClipboardTextHint: String { s("pinFromClipboardTextHint") }
    static var pinToolbarEdit: String { s("pinToolbarEdit") }
    static var pinToolbarEditText: String { s("pinToolbarEditText") }

    // Image-edit shortcuts
    static var selectedImageEditShortcutHeader: String { s("selectedImageEditShortcutHeader") }
    static var selectedImageEditShortcutHint: String { s("selectedImageEditShortcutHint") }
    static var selectedImageEditShortcutDefaultDisplay: String { s("selectedImageEditShortcutDefaultDisplay") }
    static var clipboardImageEditShortcutHeader: String { s("clipboardImageEditShortcutHeader") }
    static var clipboardImageEditShortcutHint: String { s("clipboardImageEditShortcutHint") }
    static var clipboardImageEditShortcutDefaultDisplay: String { s("clipboardImageEditShortcutDefaultDisplay") }
    static var recordShortcutHeader: String { s("recordShortcutHeader") }
    static var recordShortcutDefaultDisplay: String { s("recordShortcutDefaultDisplay") }
    static var imageMergeShortcutHeader: String { s("imageMergeShortcutHeader") }
    static var imageMergeShortcutDefaultDisplay: String { s("imageMergeShortcutDefaultDisplay") }

    // Screenshot execution shortcut (editor confirm)
    static var clipboardShortcutHeader: String { s("clipboardShortcutHeader") }
    static var clipboardShortcutHint: String { s("clipboardShortcutHint") }
    static var clipboardShortcutDefaultDisplay: String { s("clipboardShortcutDefaultDisplay") }

    // Shortcut conflict
    static var shortcutConflictTitle: String { s("shortcutConflictTitle") }
    static var shortcutConflictScreenshot: String { s("shortcutConflictScreenshot") }
    static var shortcutConflictSelectedImagePin: String { s("shortcutConflictSelectedImagePin") }
    static var shortcutConflictClipboardImagePin: String { s("shortcutConflictClipboardImagePin") }
    static var shortcutConflictClipboardTextPin: String { s("shortcutConflictClipboardTextPin") }
    static var shortcutConflictClipboard: String { s("shortcutConflictClipboard") }
    static var shortcutConflictSelectedImageEdit: String { s("shortcutConflictSelectedImageEdit") }
    static var shortcutConflictClipboardImageEdit: String { s("shortcutConflictClipboardImageEdit") }
    static var shortcutConflictRecord: String { s("shortcutConflictRecord") }
    static var shortcutConflictImageMerge: String { s("shortcutConflictImageMerge") }

    // Menu bar
    static var takeScreenshot: String { s("takeScreenshot") }
    static var record: String { s("record") }
    static var mergeImages: String { s("mergeImages") }
    static var settings: String { s("settings") }
    static var quitApp: String { s("quitApp") }
    // Cursor chip
    static var dragToScreenshot: String { s("dragToScreenshot") }
    static var dragToScreenshotAspectFree: String { s("dragToScreenshotAspectFree") }
    static func dragToScreenshotAspect(_ ratio: String) -> String {
        String(format: s("dragToScreenshotAspect"), ratio)
    }
    static var dragToRecord: String { s("dragToRecord") }
    static var dragToRecordAspectFree: String { s("dragToRecordAspectFree") }
    static func dragToRecordAspect(_ ratio: String) -> String {
        String(format: s("dragToRecordAspect"), ratio)
    }

    // Toast
    static var copiedToClipboard: String { s("copiedToClipboard") }
    static var mergedLongScreenshot: String { s("mergedLongScreenshot") }
    static var autoScrollPermissionNeeded: String { s("autoScrollPermissionNeeded") }
    static var cropLongScreenshotHint: String { s("cropLongScreenshotHint") }
    static var scrollCaptureHint: String { s("scrollCaptureHint") }
    static var scrollCaptureManualHint: String { s("scrollCaptureManualHint") }
    static var finderEditExitHint: String { s("finderEditExitHint") }
    static var clipboardEditExitHint: String { s("clipboardEditExitHint") }
    static var pinEditExitHint: String { s("pinEditExitHint") }
    static var editSuspendedToast: String { s("editSuspendedToast") }
    static var editSuspendedResumeToast: String { s("editSuspendedResumeToast") }
    static var openImageNoImage: String { s("openImageNoImage") }
    static var selectedImageEditNoImage: String { s("selectedImageEditNoImage") }
    static var clipboardImageEditNoImage: String { s("clipboardImageEditNoImage") }
    static var mergeEditExitHint: String { s("mergeEditExitHint") }
    static var imageMergeNeedTwoImages: String { s("imageMergeNeedTwoImages") }
    static var imageMergeSomeImagesSkipped: String { s("imageMergeSomeImagesSkipped") }
    static var imageMergeNoClipboardImage: String { s("imageMergeNoClipboardImage") }
    static var imageMergeFailed: String { s("imageMergeFailed") }
    static var imageMergeSaved: String { s("imageMergeSaved") }
    static func recordingSaved(to path: String) -> String {
        String(format: s("recordingSaved"), path)
    }
    static var recordingCancelled: String { s("recordingCancelled") }
    static var recordingExportingGIF: String { s("recordingExportingGIF") }
    static var saveRecording: String { s("saveRecording") }
    static var saveRecordingPrompt: String { s("saveRecordingPrompt") }
    static var recordingFormatLabel: String { s("recordingFormatLabel") }
    static var recordingFormatManual: String { s("recordingFormatManual") }
    static var recordingFormatMP4: String { s("recordingFormatMP4") }
    static var recordingFormatGIF: String { s("recordingFormatGIF") }
    static var recordingFormatChoiceTitle: String { s("recordingFormatChoiceTitle") }
    static var recordingFormatChoiceMessage: String { s("recordingFormatChoiceMessage") }
    static func screenshotSaved(to path: String) -> String {
        String(format: s("screenshotSaved"), path)
    }
    static var recordingStop: String { s("recordingStop") }
    static var recordingPause: String { s("recordingPause") }
    static var recordingResume: String { s("recordingResume") }
    static func recordingFailed(_ message: String) -> String {
        String(format: s("recordingFailed"), message)
    }
    static func screenshotSaveFailed(_ message: String) -> String {
        String(format: s("screenshotSaveFailed"), message)
    }
    static var qrCodeCopied: String { s("qrCodeCopied") }
    static var qrCodeNotFound: String { s("qrCodeNotFound") }

    // Toolbar tooltips
    static var tipRectangle: String { s("tipRectangle") }
    static var tipEllipse: String { s("tipEllipse") }
    static var tipArrow: String { s("tipArrow") }
    static var tipLine: String { s("tipLine") }
    static var tipPen: String { s("tipPen") }
    static var tipMarker: String { s("tipMarker") }
    static var tipMosaic: String { s("tipMosaic") }
    static var mosaicGranularity: String { s("mosaicGranularity") }
    static var tipEraser: String { s("tipEraser") }
    static var tipMagnifier: String { s("tipMagnifier") }
    static var tipNumbered: String { s("tipNumbered") }
    static var tipText: String { s("tipText") }
    static var tipQRCode: String { s("tipQRCode") }
    static var tipInsertImage: String { s("tipInsertImage") }
    static var tipUndo: String { s("tipUndo") }
    static var tipRedo: String { s("tipRedo") }
    static var tipScrollCapture: String { s("tipScrollCapture") }
    static var tipSave: String { s("tipSave") }
    static var tipPin: String { s("tipPin") }
    static var tipRecord: String { s("tipRecord") }
    static var tipCancel: String { s("tipCancel") }
    static var tipConfirm: String { s("tipConfirm") }
    static var tipScrollCropConfirm: String { s("tipScrollCropConfirm") }
    static var copyQRCodeContent: String { s("copyQRCodeContent") }

    // Text tool
    static var textStrokeEffect: String { s("textStrokeEffect") }
    static var textCalloutEffect: String { s("textCalloutEffect") }

    // Shape tool
    static var shapeFillEffect: String { s("shapeFillEffect") }
    static var shapeFillNone: String { s("shapeFillNone") }
    static var shapeFillOpaque: String { s("shapeFillOpaque") }
    static var shapeFillTranslucent: String { s("shapeFillTranslucent") }
    static var shapeStyleStandard: String { s("shapeStyleStandard") }
    static var shapeStyleRounded: String { s("shapeStyleRounded") }
    static var shapeStyleHandDrawn: String { s("shapeStyleHandDrawn") }

    // Insert tools
    static var insertImageFromClipboard: String { s("insertImageFromClipboard") }
    static var insertImageFromFile: String { s("insertImageFromFile") }
    static var insertImageChooseFile: String { s("insertImageChooseFile") }
    static var insertImageNoClipboardImage: String { s("insertImageNoClipboardImage") }
    static var scrollCaptureAutoScroll: String { s("scrollCaptureAutoScroll") }
    static var scrollCaptureManualScroll: String { s("scrollCaptureManualScroll") }

    // Language
    static var languageHeader: String { s("languageHeader") }

    // Settings sidebar tabs
    static var settingsTabGeneral: String { s("settingsTabGeneral") }
    static var settingsTabShortcuts: String { s("settingsTabShortcuts") }
    static var settingsTabAbout: String { s("settingsTabAbout") }
    static var settingsTabToolbar: String { s("settingsTabToolbar") }
    static var settingsTabGeneralDescription: String { s("settingsTabGeneralDescription") }
    static var settingsTabShortcutsDescription: String { s("settingsTabShortcutsDescription") }
    static var settingsTabToolbarDescription: String { s("settingsTabToolbarDescription") }
    static var settingsTabAboutDescription: String { s("settingsTabAboutDescription") }

    // Toolbar settings
    static var toolbarSettingsPrimaryTitle: String { s("toolbarSettingsPrimaryTitle") }
    static var toolbarSettingsPrimaryHint: String { s("toolbarSettingsPrimaryHint") }
    static var toolbarSettingsSideTitle: String { s("toolbarSettingsSideTitle") }
    static var toolbarSettingsSideHint: String { s("toolbarSettingsSideHint") }
    static var toolbarSettingsHiddenTitle: String { s("toolbarSettingsHiddenTitle") }
    static var toolbarSettingsHiddenHint: String { s("toolbarSettingsHiddenHint") }
    static var toolbarSettingsFootnote: String { s("toolbarSettingsFootnote") }
    static var toolbarSettingsReset: String { s("toolbarSettingsReset") }
    static var toolbarSettingsCancel: String { s("toolbarSettingsCancel") }
    static var toolbarSettingsApply: String { s("toolbarSettingsApply") }

    // About pane
    static var aboutLicense: String { s("aboutLicense") }
    static func aboutVersion(_ version: String, build: String) -> String {
        String(format: s("aboutVersion"), version, build)
    }
    static var aboutTitle: String { s("aboutTitle") }
    static var aboutVersionTitle: String { s("aboutVersionTitle") }
    static func aboutVersionValue(_ version: String, build: String) -> String {
        String(format: s("aboutVersionValue"), version, build)
    }
    static var aboutCompatibilityTitle: String { s("aboutCompatibilityTitle") }
    static var aboutCompatibilityValue: String { s("aboutCompatibilityValue") }
    static var aboutSystemRequirementTitle: String { s("aboutSystemRequirementTitle") }
    static var aboutSystemRequirementValue: String { s("aboutSystemRequirementValue") }
    static var aboutIntroductionTitle: String { s("aboutIntroductionTitle") }
    static var aboutIntroductionFirst: String { s("aboutIntroductionFirst") }
    static var aboutIntroductionSecond: String { s("aboutIntroductionSecond") }
    static var aboutIntroductionThird: String { s("aboutIntroductionThird") }
    static var aboutWebsiteTitle: String { s("aboutWebsiteTitle") }
    static var aboutWebsiteURL: String { s("aboutWebsiteURL") }
    static var aboutRelatedLinksTitle: String { s("aboutRelatedLinksTitle") }
    static var aboutAcknowledgementsTitle: String { s("aboutAcknowledgementsTitle") }
    static var aboutAcknowledgementFirst: String { s("aboutAcknowledgementFirst") }
    static var aboutAcknowledgementSecond: String { s("aboutAcknowledgementSecond") }
    static var aboutAcknowledgementThird: String { s("aboutAcknowledgementThird") }
    static var aboutAcknowledgementFourth: String { s("aboutAcknowledgementFourth") }
    static var aboutAcknowledgementFifth: String { s("aboutAcknowledgementFifth") }
    static var aboutAcknowledgementSixth: String { s("aboutAcknowledgementSixth") }
    static var aboutCopyright: String { s("aboutCopyright") }
    static var aboutSourceCode: String { s("aboutSourceCode") }
    static var aboutStarOnGitHub: String { s("aboutStarOnGitHub") }
    static var aboutFeatureRequest: String { s("aboutFeatureRequest") }
    static var aboutBugReport: String { s("aboutBugReport") }
    static var aboutUpdateTitle: String { s("aboutUpdateTitle") }

    // Error log — About pane
    static var aboutErrorLog: String { s("aboutErrorLog") }
    static var aboutErrorLogNoCrash: String { s("aboutErrorLogNoCrash") }
    static func aboutErrorLogLastCrash(_ date: String) -> String {
        String(format: s("aboutErrorLogLastCrash"), date)
    }
    static var aboutErrorLogCopy: String { s("aboutErrorLogCopy") }
    static var aboutErrorLogCopied: String { s("aboutErrorLogCopied") }
    static var aboutErrorLogReveal: String { s("aboutErrorLogReveal") }
    static var aboutErrorLogRefresh: String { s("aboutErrorLogRefresh") }
    static var aboutErrorLogClear: String { s("aboutErrorLogClear") }
    static var aboutErrorLogEmptyBody: String { s("aboutErrorLogEmptyBody") }

    // Updates — About pane
    static var checkForUpdates: String { s("checkForUpdates") }
    static var updateChecking: String { s("updateChecking") }
    static var updateUpToDateStatus: String { s("updateUpToDateStatus") }
    static func updateNewVersionStatus(_ v: String) -> String {
        String(format: s("updateNewVersionStatus"), v)
    }
    static var updateFailedStatus: String { s("updateFailedStatus") }
    static var updateDownloadButton: String { s("updateDownloadButton") }
    static var updateRetryButton: String { s("updateRetryButton") }
    static var updateInstallNowButton: String { s("updateInstallNowButton") }
    static func updateDownloadingStatus(_ percent: Int) -> String {
        String(format: s("updateDownloadingStatus"), percent)
    }
    static var updateInstallingStatus: String { s("updateInstallingStatus") }
    static var updateInstallFailedStatus: String { s("updateInstallFailedStatus") }

    // Updates — menu bar
    static var checkForUpdatesMenu: String { s("checkForUpdatesMenu") }
    static var checkingForUpdatesMenu: String { s("checkingForUpdatesMenu") }
    static func updateAvailableMenu(_ v: String) -> String {
        String(format: s("updateAvailableMenu"), v)
    }
    static func updateDownloadingMenu(_ percent: Int) -> String {
        String(format: s("updateDownloadingMenu"), percent)
    }
    static var updateInstallingMenu: String { s("updateInstallingMenu") }
    static var updateInstallFailedMenu: String { s("updateInstallFailedMenu") }

    // Updates — progress HUD
    static var updateCheckingHUD: String { s("updateCheckingHUD") }
    static func updateDownloadingHUD(_ percent: Int) -> String {
        String(format: s("updateDownloadingHUD"), percent)
    }
    static var updateVerifyingHUD: String { s("updateVerifyingHUD") }
    static var updateUnzippingHUD: String { s("updateUnzippingHUD") }
    static var updateInstallingHUD: String { s("updateInstallingHUD") }

    // Updates — manual check result alert
    static func updateAvailableTitle(_ v: String) -> String {
        String(format: s("updateAvailableTitle"), v)
    }
    static var updateAvailableBody: String { s("updateAvailableBody") }
    static var updateUpToDateTitle: String { s("updateUpToDateTitle") }
    static func updateUpToDateBody(_ v: String) -> String {
        String(format: s("updateUpToDateBody"), v)
    }
    static var updateFailedTitle: String { s("updateFailedTitle") }
    static var updateFailedBody: String { s("updateFailedBody") }
    static var updateInstallFailedTitle: String { s("updateInstallFailedTitle") }
    static var updateInstallFailedBody: String { s("updateInstallFailedBody") }
    static var updateOpenPageButton: String { s("updateOpenPageButton") }
    static var updateSkipButton: String { s("updateSkipButton") }
    static var updateLaterButton: String { s("updateLaterButton") }
    static var updateOKButton: String { s("updateOKButton") }

    // Image Merge workbench
    static var imageMergeWindowTitle: String { s("imageMergeWindowTitle") }
    static var imageMergeSources: String { s("imageMergeSources") }
    static var imageMergeAddFiles: String { s("imageMergeAddFiles") }
    static var imageMergeAddFromClipboard: String { s("imageMergeAddFromClipboard") }
    static var imageMergeImageList: String { s("imageMergeImageList") }
    static var imageMergeTemplate: String { s("imageMergeTemplate") }
    static var imageMergeTemplateHorizontal: String { s("imageMergeTemplateHorizontal") }
    static var imageMergeTemplateVertical: String { s("imageMergeTemplateVertical") }
    static var imageMergeTemplateGrid: String { s("imageMergeTemplateGrid") }
    static var imageMergeTemplateLongStitch: String { s("imageMergeTemplateLongStitch") }
    static var imageMergeLayout: String { s("imageMergeLayout") }
    static var imageMergeSpacing: String { s("imageMergeSpacing") }
    static var imageMergeMargin: String { s("imageMergeMargin") }
    static var imageMergeCornerRadius: String { s("imageMergeCornerRadius") }
    static var imageMergePresetNone: String { s("imageMergePresetNone") }
    static var imageMergePresetSmall: String { s("imageMergePresetSmall") }
    static var imageMergePresetMedium: String { s("imageMergePresetMedium") }
    static var imageMergePresetLarge: String { s("imageMergePresetLarge") }
    static var imageMergeCornerSquare: String { s("imageMergeCornerSquare") }
    static var imageMergeCornerRounded: String { s("imageMergeCornerRounded") }
    static var imageMergeBackground: String { s("imageMergeBackground") }
    static var imageMergeTransparent: String { s("imageMergeTransparent") }
    static var imageMergeSolid: String { s("imageMergeSolid") }
    static var imageMergeParameters: String { s("imageMergeParameters") }
    static var imageMergeOutput: String { s("imageMergeOutput") }
    static var imageMergeCopy: String { s("imageMergeCopy") }
    static var imageMergeSave: String { s("imageMergeSave") }
    static var imageMergeContinueEditing: String { s("imageMergeContinueEditing") }
    static var imageMergeClose: String { s("imageMergeClose") }
    static var imageMergeEmptyTitle: String { s("imageMergeEmptyTitle") }
    static var imageMergeEmptyBody: String { s("imageMergeEmptyBody") }
    static var imageMergeClipboardSourceName: String { s("imageMergeClipboardSourceName") }
}

struct Defaults {
    private static var defaults: UserDefaults {
        UserDefaults.standard
    }

    // Custom screenshot hotkey. When the key is absent, no hotkey is configured.
    // keyCode 0 is a valid value — it is the `A` key
    // (kVK_ANSI_A) — so presence must be checked via `hasCustomScreenshotHotkey`,
    // never by comparing the key code to 0.
    // Modifiers are stored using Carbon flags (cmdKey | shiftKey | optionKey | controlKey).

    static var screenshotHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "screenshotHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "screenshotHotkeyKeyCode") }
    }

    static var screenshotHotkeyModifiers: Int {
        get { defaults.integer(forKey: "screenshotHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "screenshotHotkeyModifiers") }
    }

    static var hasCustomScreenshotHotkey: Bool {
        defaults.object(forKey: "screenshotHotkeyKeyCode") != nil
    }

    static func clearScreenshotHotkey() {
        defaults.removeObject(forKey: "screenshotHotkeyKeyCode")
        defaults.removeObject(forKey: "screenshotHotkeyModifiers")
    }

    static let selectionAspectRatioPresets: [CGFloat] = [
        1.0,
        2.35,
        3.0,
        3.0 / 2.0,
        4.0 / 3.0,
        9.0 / 16.0,
        16.0 / 9.0,
    ]

    static var selectionAspectRatio: Double {
        get {
            let ratio = defaults.double(forKey: "selectionAspectRatio")
            return ratio > 0 && ratio.isFinite ? ratio : 0
        }
        set {
            guard newValue > 0, newValue.isFinite else {
                clearSelectionAspectRatio()
                return
            }
            defaults.set(newValue, forKey: "selectionAspectRatio")
        }
    }

    static var hasSelectionAspectRatio: Bool {
        defaults.object(forKey: "selectionAspectRatio") != nil && selectionAspectRatio > 0
    }

    static func clearSelectionAspectRatio() {
        defaults.removeObject(forKey: "selectionAspectRatio")
    }

    private static func clearLegacyPinHotkey() {
        defaults.removeObject(forKey: "pinHotkeyKeyCode")
        defaults.removeObject(forKey: "pinHotkeyModifiers")
    }

    // Custom pin-image hotkeys. They are global Carbon hotkeys with no
    // defaults: users opt in from Settings. The selected-image shortcut reads
    // images selected in Finder; the clipboard-image shortcut reads only the
    // clipboard image.

    static var selectedImagePinHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "selectedImagePinHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "selectedImagePinHotkeyKeyCode") }
    }

    static var selectedImagePinHotkeyModifiers: Int {
        get { defaults.integer(forKey: "selectedImagePinHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "selectedImagePinHotkeyModifiers") }
    }

    static var hasCustomSelectedImagePinHotkey: Bool {
        defaults.object(forKey: "selectedImagePinHotkeyKeyCode") != nil
    }

    static func clearSelectedImagePinHotkey() {
        defaults.removeObject(forKey: "selectedImagePinHotkeyKeyCode")
        defaults.removeObject(forKey: "selectedImagePinHotkeyModifiers")
    }

    static var clipboardImagePinHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "clipboardImagePinHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "clipboardImagePinHotkeyKeyCode") }
    }

    static var clipboardImagePinHotkeyModifiers: Int {
        get { defaults.integer(forKey: "clipboardImagePinHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "clipboardImagePinHotkeyModifiers") }
    }

    static var hasCustomClipboardImagePinHotkey: Bool {
        defaults.object(forKey: "clipboardImagePinHotkeyKeyCode") != nil
    }

    static func clearClipboardImagePinHotkey() {
        defaults.removeObject(forKey: "clipboardImagePinHotkeyKeyCode")
        defaults.removeObject(forKey: "clipboardImagePinHotkeyModifiers")
    }

    static var clipboardTextPinHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "clipboardTextPinHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "clipboardTextPinHotkeyKeyCode") }
    }

    static var clipboardTextPinHotkeyModifiers: Int {
        get { defaults.integer(forKey: "clipboardTextPinHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "clipboardTextPinHotkeyModifiers") }
    }

    static var hasCustomClipboardTextPinHotkey: Bool {
        defaults.object(forKey: "clipboardTextPinHotkeyKeyCode") != nil
    }

    static func clearClipboardTextPinHotkey() {
        defaults.removeObject(forKey: "clipboardTextPinHotkeyKeyCode")
        defaults.removeObject(forKey: "clipboardTextPinHotkeyModifiers")
    }

    static func resetShortcutHotkeysToDefaults() {
        clearScreenshotHotkey()
        clearLegacyPinHotkey()
        clearSelectedImagePinHotkey()
        clearClipboardImagePinHotkey()
        clearClipboardTextPinHotkey()
        clearSelectedImageEditHotkey()
        clearClipboardImageEditHotkey()
        clearRecordHotkey()
        clearImageMergeHotkey()
        clearClipboardHotkey()
    }

    // Custom image-edit hotkeys. They are global Carbon hotkeys with no
    // defaults: users opt in from Settings. The selected-image shortcut reads
    // one image selected in Finder; the clipboard-image shortcut reads only
    // the clipboard image.

    static var selectedImageEditHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "selectedImageEditHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "selectedImageEditHotkeyKeyCode") }
    }

    static var selectedImageEditHotkeyModifiers: Int {
        get { defaults.integer(forKey: "selectedImageEditHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "selectedImageEditHotkeyModifiers") }
    }

    static var hasCustomSelectedImageEditHotkey: Bool {
        defaults.object(forKey: "selectedImageEditHotkeyKeyCode") != nil
    }

    static func clearSelectedImageEditHotkey() {
        defaults.removeObject(forKey: "selectedImageEditHotkeyKeyCode")
        defaults.removeObject(forKey: "selectedImageEditHotkeyModifiers")
    }

    static var clipboardImageEditHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "clipboardImageEditHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "clipboardImageEditHotkeyKeyCode") }
    }

    static var clipboardImageEditHotkeyModifiers: Int {
        get { defaults.integer(forKey: "clipboardImageEditHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "clipboardImageEditHotkeyModifiers") }
    }

    static var hasCustomClipboardImageEditHotkey: Bool {
        defaults.object(forKey: "clipboardImageEditHotkeyKeyCode") != nil
    }

    static func clearClipboardImageEditHotkey() {
        defaults.removeObject(forKey: "clipboardImageEditHotkeyKeyCode")
        defaults.removeObject(forKey: "clipboardImageEditHotkeyModifiers")
    }

    static var recordHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "recordHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "recordHotkeyKeyCode") }
    }

    static var recordHotkeyModifiers: Int {
        get { defaults.integer(forKey: "recordHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "recordHotkeyModifiers") }
    }

    static var hasCustomRecordHotkey: Bool {
        defaults.object(forKey: "recordHotkeyKeyCode") != nil
    }

    static func clearRecordHotkey() {
        defaults.removeObject(forKey: "recordHotkeyKeyCode")
        defaults.removeObject(forKey: "recordHotkeyModifiers")
    }

    static var imageMergeHotkeyKeyCode: Int {
        get { defaults.integer(forKey: "imageMergeHotkeyKeyCode") }
        set { defaults.set(newValue, forKey: "imageMergeHotkeyKeyCode") }
    }

    static var imageMergeHotkeyModifiers: Int {
        get { defaults.integer(forKey: "imageMergeHotkeyModifiers") }
        set { defaults.set(newValue, forKey: "imageMergeHotkeyModifiers") }
    }

    static var hasCustomImageMergeHotkey: Bool {
        defaults.object(forKey: "imageMergeHotkeyKeyCode") != nil
    }

    static func clearImageMergeHotkey() {
        defaults.removeObject(forKey: "imageMergeHotkeyKeyCode")
        defaults.removeObject(forKey: "imageMergeHotkeyModifiers")
    }

    static var imageMergeTemplate: ImageMergeTemplate {
        get {
            let rawValue = defaults.integer(forKey: "imageMergeTemplate")
            return ImageMergeTemplate(rawValue: rawValue) ?? .horizontal
        }
        set {
            defaults.set(newValue.rawValue, forKey: "imageMergeTemplate")
        }
    }

    static var imageMergeSpacingPreset: ImageMergeSpacingPreset {
        get {
            let rawValue: CGFloat
            if defaults.object(forKey: "imageMergeSpacing") == nil {
                rawValue = ImageMergeSpacingPreset.medium.value
            } else {
                rawValue = CGFloat(defaults.double(forKey: "imageMergeSpacing"))
            }
            let preset = ImageMergeSpacingPreset.nearest(to: rawValue)
            defaults.set(Double(preset.value), forKey: "imageMergeSpacing")
            return preset
        }
        set {
            defaults.set(Double(newValue.value), forKey: "imageMergeSpacing")
        }
    }

    static var imageMergeMarginPreset: ImageMergeMarginPreset {
        get {
            let rawValue: CGFloat
            if defaults.object(forKey: "imageMergeMargin") == nil {
                rawValue = ImageMergeMarginPreset.medium.value
            } else {
                rawValue = CGFloat(defaults.double(forKey: "imageMergeMargin"))
            }
            let preset = ImageMergeMarginPreset.nearest(to: rawValue)
            defaults.set(Double(preset.value), forKey: "imageMergeMargin")
            return preset
        }
        set {
            defaults.set(Double(newValue.value), forKey: "imageMergeMargin")
        }
    }

    static var imageMergeCornerPreset: ImageMergeCornerPreset {
        get {
            let rawValue: CGFloat
            if defaults.object(forKey: "imageMergeCornerRadius") == nil {
                rawValue = ImageMergeCornerPreset.square.value
            } else {
                rawValue = CGFloat(defaults.double(forKey: "imageMergeCornerRadius"))
            }
            let preset = ImageMergeCornerPreset.nearest(to: rawValue)
            defaults.set(Double(preset.value), forKey: "imageMergeCornerRadius")
            return preset
        }
        set {
            defaults.set(Double(newValue.value), forKey: "imageMergeCornerRadius")
        }
    }

    static var imageMergeSpacing: Double {
        get { Double(imageMergeSpacingPreset.value) }
        set { imageMergeSpacingPreset = .nearest(to: CGFloat(newValue)) }
    }

    static var imageMergeMargin: Double {
        get { Double(imageMergeMarginPreset.value) }
        set { imageMergeMarginPreset = .nearest(to: CGFloat(newValue)) }
    }

    static var imageMergeCornerRadius: Double {
        get { Double(imageMergeCornerPreset.value) }
        set { imageMergeCornerPreset = .nearest(to: CGFloat(newValue)) }
    }

    static var imageMergeBackgroundIsSolid: Bool {
        get { defaults.bool(forKey: "imageMergeBackgroundIsSolid") }
        set { defaults.set(newValue, forKey: "imageMergeBackgroundIsSolid") }
    }

    static var imageMergeBackgroundColorHex: String {
        get {
            normalizedHexColor(defaults.string(forKey: "imageMergeBackgroundColorHex")) ?? "#FFFFFF"
        }
        set {
            defaults.set(normalizedHexColor(newValue) ?? "#FFFFFF", forKey: "imageMergeBackgroundColorHex")
        }
    }

    static var recordingSaveFormat: ScreenRecordingFormat {
        get {
            guard let raw = defaults.string(forKey: "recordingSaveFormat"),
                  let format = ScreenRecordingFormat(rawValue: raw)
            else {
                return .mp4
            }
            return format
        }
        set {
            defaults.set(newValue.rawValue, forKey: "recordingSaveFormat")
        }
    }

    static var recordingSavePreference: RecordingSavePreference {
        get {
            guard let raw = defaults.string(forKey: "recordingSavePreference"),
                  let preference = RecordingSavePreference(rawValue: raw)
            else {
                return .manual
            }
            return preference
        }
        set {
            defaults.set(newValue.rawValue, forKey: "recordingSavePreference")
        }
    }

    static var defaultRecordingSaveDirectory: URL {
        defaultDocumentsDirectory.appendingPathComponent("record", isDirectory: true)
    }

    static var defaultScreenshotSaveDirectory: URL {
        defaultDocumentsDirectory.appendingPathComponent("screenshots", isDirectory: true)
    }

    static var recordingSaveDirectory: URL {
        get {
            normalizedDirectoryURL(
                defaults.string(forKey: "recordingSaveDirectory"),
                fallback: defaultRecordingSaveDirectory
            )
        }
        set {
            let normalized = newValue.standardizedFileURL
            let oldValue = recordingSaveDirectory
            defaults.set(normalized.path, forKey: "recordingSaveDirectory")
            if oldValue != normalized {
                NotificationCenter.default.post(name: .recordingSaveDirectoryDidChange, object: nil)
            }
        }
    }

    static var screenshotSaveDirectory: URL {
        get {
            normalizedDirectoryURL(
                defaults.string(forKey: "screenshotSaveDirectory"),
                fallback: defaultScreenshotSaveDirectory
            )
        }
        set {
            defaults.set(newValue.standardizedFileURL.path, forKey: "screenshotSaveDirectory")
        }
    }

    static var screenshotQuality: ScreenshotImageQuality {
        get {
            let quality = ScreenshotImageQuality.resolveSharedPreference(
                sharedRawValue: defaults.string(forKey: "screenshotQuality"),
                legacySaveRawValue: defaults.string(forKey: "screenshotSaveQuality"),
                legacyClipboardRawValue: defaults.string(forKey: "screenshotClipboardQuality")
            )
            defaults.set(quality.rawValue, forKey: "screenshotQuality")
            defaults.removeObject(forKey: "screenshotSaveQuality")
            defaults.removeObject(forKey: "screenshotClipboardQuality")
            return quality
        }
        set {
            defaults.set(newValue.rawValue, forKey: "screenshotQuality")
            defaults.removeObject(forKey: "screenshotSaveQuality")
            defaults.removeObject(forKey: "screenshotClipboardQuality")
        }
    }

    static var screenshotOutputMode: ScreenshotOutputMode {
        get {
            guard let raw = defaults.string(forKey: "screenshotOutputMode") else {
                return ScreenshotOutputMode.defaultValue
            }
            return ScreenshotOutputMode(rawValue: raw) ?? ScreenshotOutputMode.defaultValue
        }
        set {
            defaults.set(newValue.rawValue, forKey: "screenshotOutputMode")
        }
    }

    private static var defaultDocumentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
    }

    private static func normalizedDirectoryURL(_ value: String?, fallback: URL) -> URL {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback.standardizedFileURL }
        let expanded = (trimmed as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    }

    // Custom screenshot-execution hotkey used inside the editor overlay to
    // confirm the screenshot. When absent, no execution hotkey is configured.
    // Unlike the screenshot and pin hotkeys this is matched locally against
    // keyDown events instead of registered as a Carbon global hotkey, so it
    // may be bare (no modifiers). Presence must be checked via
    // `hasCustomClipboardHotkey` since key code 0 (`A`) is a valid value.

    private static func migrateLegacySaveHotkeyIfNeeded() {
        // aulycShot ≤ 1.x stored this same hotkey under "saveHotkey*". Migrate
        // once on first read so existing users don't lose their binding.
        let migratedKey = "clipboardHotkeyMigrated"
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)
        guard defaults.object(forKey: "saveHotkeyKeyCode") != nil,
              defaults.object(forKey: "clipboardHotkeyKeyCode") == nil
        else { return }
        defaults.set(defaults.integer(forKey: "saveHotkeyKeyCode"), forKey: "clipboardHotkeyKeyCode")
        defaults.set(defaults.integer(forKey: "saveHotkeyModifiers"), forKey: "clipboardHotkeyModifiers")
        defaults.removeObject(forKey: "saveHotkeyKeyCode")
        defaults.removeObject(forKey: "saveHotkeyModifiers")
    }

    static var clipboardHotkeyKeyCode: Int {
        get {
            migrateLegacySaveHotkeyIfNeeded()
            return defaults.integer(forKey: "clipboardHotkeyKeyCode")
        }
        set { defaults.set(newValue, forKey: "clipboardHotkeyKeyCode") }
    }

    static var clipboardHotkeyModifiers: Int {
        get {
            migrateLegacySaveHotkeyIfNeeded()
            return defaults.integer(forKey: "clipboardHotkeyModifiers")
        }
        set { defaults.set(newValue, forKey: "clipboardHotkeyModifiers") }
    }

    static var hasCustomClipboardHotkey: Bool {
        migrateLegacySaveHotkeyIfNeeded()
        return defaults.object(forKey: "clipboardHotkeyKeyCode") != nil
    }

    static func clearClipboardHotkey() {
        defaults.removeObject(forKey: "clipboardHotkeyKeyCode")
        defaults.removeObject(forKey: "clipboardHotkeyModifiers")
        defaults.removeObject(forKey: "saveHotkeyKeyCode")
        defaults.removeObject(forKey: "saveHotkeyModifiers")
        defaults.set(true, forKey: "clipboardHotkeyMigrated")
    }

    static var penColor: Int {
        get {
            let val = defaults.integer(forKey: "penColor")
            return val == 0 ? 0xFF0000 : val
        }
        set {
            defaults.set(newValue, forKey: "penColor")
        }
    }

    static var penWidth: Double {
        get {
            let val = defaults.double(forKey: "penWidth")
            return val > 0 ? val : 3.0
        }
        set {
            defaults.set(newValue, forKey: "penWidth")
        }
    }

    static let editorLineWidthMin: Double = 1
    static let editorLineWidthMax: Double = 16
    static let markerLineWidthMax: Double = 10

    static var lastEditorColorHex: String? {
        get {
            normalizedHexColor(defaults.string(forKey: "lastEditorColorHex"))
        }
        set {
            if let normalized = normalizedHexColor(newValue) {
                defaults.set(normalized, forKey: "lastEditorColorHex")
            } else {
                defaults.removeObject(forKey: "lastEditorColorHex")
            }
        }
    }

    static var lastEditorLineWidth: Double {
        get {
            if defaults.object(forKey: "lastEditorLineWidth") == nil {
                return 4.0
            }
            return clampedEditorLineWidth(defaults.double(forKey: "lastEditorLineWidth"))
        }
        set {
            defaults.set(clampedEditorLineWidth(newValue), forKey: "lastEditorLineWidth")
        }
    }

    static var lastMarkerColorHex: String? {
        get {
            normalizedHexColor(defaults.string(forKey: "lastMarkerColorHex"))
        }
        set {
            if let normalized = normalizedHexColor(newValue) {
                defaults.set(normalized, forKey: "lastMarkerColorHex")
            } else {
                defaults.removeObject(forKey: "lastMarkerColorHex")
            }
        }
    }

    static var lastMarkerLineWidth: Double {
        get {
            if defaults.object(forKey: "lastMarkerLineWidth") == nil {
                return 5.0
            }
            return clampedMarkerLineWidth(defaults.double(forKey: "lastMarkerLineWidth"))
        }
        set {
            defaults.set(clampedMarkerLineWidth(newValue), forKey: "lastMarkerLineWidth")
        }
    }

    static var mosaicBlockSize: Double {
        get {
            let val = defaults.double(forKey: "mosaicBlockSize")
            guard val > 0 else { return 12.0 }
            return min(max(val, mosaicBlockSizeMin), mosaicBlockSizeMax)
        }
        set {
            defaults.set(min(max(newValue, mosaicBlockSizeMin), mosaicBlockSizeMax), forKey: "mosaicBlockSize")
        }
    }

    static let mosaicBlockSizeMin: Double = 4
    static let mosaicBlockSizeMax: Double = 48

    static let textFontSizeMin: Double = 10
    static let textFontSizeMax: Double = 100

    static var lastTextFontSize: Double {
        get {
            if defaults.object(forKey: "lastTextFontSize") == nil {
                return 20
            }
            let val = defaults.double(forKey: "lastTextFontSize")
            return min(max(val, textFontSizeMin), textFontSizeMax)
        }
        set {
            defaults.set(min(max(newValue, textFontSizeMin), textFontSizeMax), forKey: "lastTextFontSize")
        }
    }

    /// Whether the text tool's outline checkbox was last left on.
    static var lastTextStroke: Bool {
        get { defaults.bool(forKey: "lastTextStroke") }
        set { defaults.set(newValue, forKey: "lastTextStroke") }
    }

    /// Whether the text tool's callout checkbox was last left on.
    static var lastTextCallout: Bool {
        get { defaults.bool(forKey: "lastTextCallout") }
        set { defaults.set(newValue, forKey: "lastTextCallout") }
    }

    /// Last rectangle/ellipse fill mode. Migrates the previous checkbox
    /// preference by treating its "on" state as the old opaque fill.
    static var lastShapeFillMode: ShapeFillMode {
        get {
            guard let raw = defaults.string(forKey: "lastShapeFillMode"),
                  let mode = ShapeFillMode(rawValue: raw) else {
                return defaults.bool(forKey: "lastShapeFill") ? .opaque : .none
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: "lastShapeFillMode")
            defaults.set(newValue.isFilled, forKey: "lastShapeFill")
        }
    }

    static var lastShapeStrokeStyle: ShapeStrokeStyle {
        get {
            guard let raw = defaults.string(forKey: "lastShapeStrokeStyle"),
                  let style = ShapeStrokeStyle(rawValue: raw) else {
                return .standard
            }
            return style
        }
        set {
            defaults.set(newValue.rawValue, forKey: "lastShapeStrokeStyle")
        }
    }

    /// Whether the rectangle/ellipse tool's legacy fill checkbox was last left on.
    static var lastShapeFill: Bool {
        get { lastShapeFillMode.isFilled }
        set { lastShapeFillMode = newValue ? .opaque : .none }
    }

    static var lastArrowStyle: ArrowStyle {
        get {
            guard let raw = defaults.string(forKey: "lastArrowStyle"),
                  let style = ArrowStyle(rawValue: raw) else {
                return .tapered
            }
            return style
        }
        set {
            defaults.set(newValue.rawValue, forKey: "lastArrowStyle")
        }
    }

    private static func normalizedHexColor(_ hex: String?) -> String? {
        guard var trimmed = hex?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
            return nil
        }
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, UInt32(trimmed, radix: 16) != nil else { return nil }
        return "#\(trimmed)"
    }

    private static func clampedEditorLineWidth(_ width: Double) -> Double {
        min(max(width, editorLineWidthMin), editorLineWidthMax)
    }

    private static func clampedMarkerLineWidth(_ width: Double) -> Double {
        min(max(width, editorLineWidthMin), markerLineWidthMax)
    }

    static var demoMode: Bool {
        get { defaults.bool(forKey: "demoMode") }
        set { defaults.set(newValue, forKey: "demoMode") }
    }

    static var showMenuBar: Bool {
        get {
            if defaults.object(forKey: "showMenuBar") == nil {
                return true
            }
            return defaults.bool(forKey: "showMenuBar")
        }
        set {
            defaults.set(newValue, forKey: "showMenuBar")
        }
    }

    static var language: AppLanguage {
        get {
            // Explicit user choice wins; otherwise follow the system locale on
            // first launch so a fresh install opens in a familiar language.
            if let raw = defaults.string(forKey: "appLanguage"),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return AppLanguage.systemDefault
        }
        set {
            let old = language
            defaults.set(newValue.rawValue, forKey: "appLanguage")
            if newValue != old {
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }
    }
}
