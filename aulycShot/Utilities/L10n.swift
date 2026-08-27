import Foundation

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
    static var automaticUpdateChecks: String { s("automaticUpdateChecks") }
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
    static var selectedImageEditShortcutDefaultDisplay: String { s("selectedImageEditShortcutDefaultDisplay") }
    static var clipboardImageEditShortcutHeader: String { s("clipboardImageEditShortcutHeader") }
    static var clipboardImageEditShortcutDefaultDisplay: String { s("clipboardImageEditShortcutDefaultDisplay") }
    static var recordShortcutHeader: String { s("recordShortcutHeader") }
    static var recordShortcutDefaultDisplay: String { s("recordShortcutDefaultDisplay") }
    static var imageMergeShortcutHeader: String { s("imageMergeShortcutHeader") }
    static var imageMergeShortcutDefaultDisplay: String { s("imageMergeShortcutDefaultDisplay") }

    // Screenshot execution shortcut (editor confirm)
    static var clipboardShortcutHeader: String { s("clipboardShortcutHeader") }
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
    static var saveRecordingPrompt: String { s("saveRecordingPrompt") }
    static var recordingFormatLabel: String { s("recordingFormatLabel") }
    static var recordingFormatManual: String { s("recordingFormatManual") }
    static var recordingFormatMP4: String { s("recordingFormatMP4") }
    static var recordingFormatGIF: String { s("recordingFormatGIF") }
    static var recordingFormatChoiceTitle: String { s("recordingFormatChoiceTitle") }
    static var recordingFileNameLabel: String { s("recordingFileNameLabel") }
    static var recordingFileNamePlaceholder: String { s("recordingFileNamePlaceholder") }
    static var recordingUseDefaultSavePath: String { s("recordingUseDefaultSavePath") }
    static var recordingSaveLocationLabel: String { s("recordingSaveLocationLabel") }
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
    static var tipSave: String { s("tipSave") }
    static var tipPin: String { s("tipPin") }
    static var tipRecord: String { s("tipRecord") }
    static var tipCancel: String { s("tipCancel") }
    static var tipConfirm: String { s("tipConfirm") }
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
    static var toolbarSettingsSideTitle: String { s("toolbarSettingsSideTitle") }
    static var toolbarSettingsHiddenTitle: String { s("toolbarSettingsHiddenTitle") }
    static var toolbarSettingsReset: String { s("toolbarSettingsReset") }

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
    static var updateChecking: String { s("updateChecking") }
    static var updateUpToDateStatus: String { s("updateUpToDateStatus") }
    static func updateNewVersionStatus(_ v: String) -> String {
        String(format: s("updateNewVersionStatus"), v)
    }
    static var updateFailedStatus: String { s("updateFailedStatus") }
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
    static var imageMergeAddFiles: String { s("imageMergeAddFiles") }
    static var imageMergeAddFromClipboard: String { s("imageMergeAddFromClipboard") }
    static var imageMergeImageList: String { s("imageMergeImageList") }
    static var imageMergeTemplate: String { s("imageMergeTemplate") }
    static var imageMergeTemplateHorizontal: String { s("imageMergeTemplateHorizontal") }
    static var imageMergeTemplateVertical: String { s("imageMergeTemplateVertical") }
    static var imageMergeTemplateGrid: String { s("imageMergeTemplateGrid") }
    static var imageMergeTemplateLongStitch: String { s("imageMergeTemplateLongStitch") }
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
    static var imageMergeCopy: String { s("imageMergeCopy") }
    static var imageMergeSave: String { s("imageMergeSave") }
    static var imageMergeContinueEditing: String { s("imageMergeContinueEditing") }
    static var imageMergeClose: String { s("imageMergeClose") }
    static var imageMergeEmptyTitle: String { s("imageMergeEmptyTitle") }
    static var imageMergeEmptyBody: String { s("imageMergeEmptyBody") }
    static var imageMergeClipboardSourceName: String { s("imageMergeClipboardSourceName") }
}
