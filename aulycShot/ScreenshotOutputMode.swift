import Foundation

enum ScreenshotOutputMode: String, CaseIterable {
    case clipboardOnly
    case fileOnly
    case clipboardAndFile

    static let defaultValue: ScreenshotOutputMode = .clipboardOnly

    var copiesToClipboard: Bool {
        self != .fileOnly
    }

    var savesToDirectory: Bool {
        self != .clipboardOnly
    }

    var localizedTitle: String {
        switch self {
        case .clipboardOnly: return L10n.screenshotOutputClipboardOnly
        case .fileOnly: return L10n.screenshotOutputFileOnly
        case .clipboardAndFile: return L10n.screenshotOutputClipboardAndFile
        }
    }
}

struct ScreenshotSavePathControlState: Equatable {
    let directory: URL
    let isEnabled: Bool

    init(directory: URL, outputMode: ScreenshotOutputMode) {
        self.directory = directory
        isEnabled = outputMode.savesToDirectory
    }
}
