struct AppActivityAvailability: Equatable {
    enum ScreenshotEntryDecision: Equatable {
        case beginCapture
        case stopRecording
        case ignore
    }

    enum RecordingEntryDecision: Equatable {
        case beginSelection
        case ignore
    }

    let overlayActive: Bool
    let recordingActive: Bool

    var canBeginActivity: Bool {
        !overlayActive && !recordingActive
    }

    var hasConflictingActivities: Bool {
        overlayActive && recordingActive
    }

    var screenshotEntryDecision: ScreenshotEntryDecision {
        if recordingActive {
            return .stopRecording
        }
        return canBeginActivity ? .beginCapture : .ignore
    }

    var recordingEntryDecision: RecordingEntryDecision {
        canBeginActivity ? .beginSelection : .ignore
    }
}

enum AppActivityEntryRouter {
    @discardableResult
    static func routeScreenshot(
        availability: AppActivityAvailability,
        beginCapture: () -> Void,
        stopRecording: () -> Void
    ) -> AppActivityAvailability.ScreenshotEntryDecision {
        let decision = availability.screenshotEntryDecision
        switch decision {
        case .beginCapture:
            beginCapture()
        case .stopRecording:
            stopRecording()
        case .ignore:
            break
        }
        return decision
    }

    @discardableResult
    static func routeRecordingSelection(
        availability: AppActivityAvailability,
        beginSelection: () -> Void
    ) -> AppActivityAvailability.RecordingEntryDecision {
        let decision = availability.recordingEntryDecision
        if decision == .beginSelection {
            beginSelection()
        }
        return decision
    }

    @discardableResult
    static func routeRecordingHandoff(
        availability: AppActivityAvailability,
        beginRecording: () -> Void
    ) -> Bool {
        guard availability.canBeginActivity else { return false }
        beginRecording()
        return true
    }
}
