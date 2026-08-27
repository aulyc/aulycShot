import AppKit

/// Owns the post-recording output flow after the capture session has already
/// normalized engine completion. Keeping prompts, format conversion and
/// temporary-file cleanup here prevents AppDelegate from becoming the second
/// owner of recording lifecycle details.
@MainActor
final class RecordingOutputCoordinator {
    func handle(_ completion: RecordingSessionController.Completion) {
        switch completion {
        case .cancelled(let temporaryURL):
            if let temporaryURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            ToastWindow.show(message: L10n.recordingCancelled)
        case .failed(let error):
            ToastWindow.show(
                message: L10n.recordingFailed(error.localizedDescription),
                duration: 3.5
            )
        case .completed(let temporaryURL):
            promptToSaveRecording(temporaryURL: temporaryURL)
        }
    }

    private func promptToSaveRecording(temporaryURL: URL) {
        let configuration = RecordingSavePromptConfiguration(
            preference: Defaults.recordingSavePreference,
            lastSelectedFormat: Defaults.recordingSaveFormat
        )
        let savePanel = RecordingSavePanel(
            initialFormat: configuration.initialFormat,
            allowsFormatSelection: configuration.allowsFormatSelection,
            defaultDirectory: Defaults.recordingSaveDirectory,
            lastCustomDirectory: Defaults.lastCustomRecordingSaveDirectory
        )
        guard savePanel.presentModally() == .OK else {
            try? FileManager.default.removeItem(at: temporaryURL)
            return
        }

        let selectedFormat = savePanel.selectedFormat
        if configuration.allowsFormatSelection {
            Defaults.recordingSaveFormat = selectedFormat
        }
        if !savePanel.usesDefaultDirectory {
            Defaults.lastCustomRecordingSaveDirectory = savePanel.customDirectory
        }
        saveRecording(
            temporaryURL: temporaryURL,
            to: savePanel.selectedDirectory,
            format: selectedFormat,
            fileName: savePanel.selectedFileName
        )
    }

    private func saveRecording(
        temporaryURL: URL,
        to directory: URL,
        format: ScreenRecordingFormat,
        fileName: String
    ) {
        do {
            let destination = try SaveDestination.uniqueFile(
                in: directory,
                fileName: fileName
            )
            saveRecording(
                temporaryURL: temporaryURL,
                destination: destination,
                format: format
            )
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            showFailure(error)
        }
    }

    private func saveRecording(
        temporaryURL: URL,
        destination: URL,
        format: ScreenRecordingFormat
    ) {
        switch format {
        case .mp4:
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                showSavedRecording(destination)
            } catch {
                showFailure(error)
            }
        case .gif:
            ToastWindow.show(message: L10n.recordingExportingGIF, duration: 600)
            RecordingExporter.exportGIF(from: temporaryURL, to: destination) { [weak self] result in
                ToastWindow.dismiss()
                switch result {
                case .success:
                    try? FileManager.default.removeItem(at: temporaryURL)
                    self?.showSavedRecording(destination)
                case .failure(let error):
                    self?.showFailure(error)
                    NSWorkspace.shared.activateFileViewerSelecting([temporaryURL])
                }
            }
        }
    }

    private func showSavedRecording(_ destination: URL) {
        let directoryPath = SaveDestination.displayPath(
            destination.deletingLastPathComponent()
        )
        ToastWindow.show(message: L10n.recordingSaved(to: directoryPath))
    }

    private func showFailure(_ error: Error) {
        ToastWindow.show(
            message: L10n.recordingFailed(error.localizedDescription),
            duration: 3.5
        )
    }
}
