import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

enum ScreenRecordingFormat: String, CaseIterable {
    case mp4
    case gif

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .mp4: return L10n.recordingFormatMP4
        case .gif: return L10n.recordingFormatGIF
        }
    }
}

enum RecordingSavePreference: String, CaseIterable {
    case manual
    case gif
    case mp4

    var displayName: String {
        switch self {
        case .manual: return L10n.recordingFormatManual
        case .gif: return L10n.recordingFormatGIF
        case .mp4: return L10n.recordingFormatMP4
        }
    }

    var format: ScreenRecordingFormat? {
        switch self {
        case .manual: return nil
        case .gif: return .gif
        case .mp4: return .mp4
        }
    }
}

struct RecordingSavePromptConfiguration: Equatable {
    let initialFormat: ScreenRecordingFormat
    let allowsFormatSelection: Bool

    init(preference: RecordingSavePreference, lastSelectedFormat: ScreenRecordingFormat) {
        if let fixedFormat = preference.format {
            initialFormat = fixedFormat
            allowsFormatSelection = false
        } else {
            initialFormat = lastSelectedFormat
            allowsFormatSelection = true
        }
    }
}

struct RecordingSavePathSelection: Equatable {
    let defaultDirectory: URL
    private(set) var customDirectory: URL
    var usesDefaultDirectory: Bool

    var selectedDirectory: URL {
        usesDefaultDirectory ? defaultDirectory : customDirectory
    }

    init(
        defaultDirectory: URL,
        customDirectory: URL? = nil,
        usesDefaultDirectory: Bool = true
    ) {
        let normalizedDirectory = defaultDirectory.standardizedFileURL
        self.defaultDirectory = normalizedDirectory
        self.customDirectory = customDirectory?.standardizedFileURL ?? normalizedDirectory
        self.usesDefaultDirectory = usesDefaultDirectory
    }

    mutating func selectCustomDirectory(_ directory: URL) {
        customDirectory = directory.standardizedFileURL
    }
}

typealias RecordingProgressCallback = (_ seconds: Int) -> Void
typealias RecordingCompletionCallback = (_ url: URL?, _ error: Error?) -> Void

struct RecordingLifecycle: Equatable {
    enum TerminationIntent: Equatable {
        case finish
        case cancel
    }

    private enum Phase: Equatable {
        case idle
        case starting(isPaused: Bool)
        case active(isPaused: Bool)
        case terminating(TerminationIntent)
    }

    private var phase: Phase = .idle

    var state: RecordingEngine.State {
        switch phase {
        case .idle:
            return .idle
        case .starting(isPaused: false), .active(isPaused: false):
            return .recording
        case .starting(isPaused: true), .active(isPaused: true):
            return .paused
        case .terminating:
            return .stopping
        }
    }

    var allowsStartupWork: Bool {
        if case .starting = phase { return true }
        return false
    }

    var isPaused: Bool {
        switch phase {
        case .starting(isPaused: true), .active(isPaused: true): return true
        default: return false
        }
    }

    var terminationIntent: TerminationIntent? {
        if case .terminating(let intent) = phase { return intent }
        return nil
    }

    mutating func start() -> Bool {
        guard phase == .idle else { return false }
        phase = .starting(isPaused: false)
        return true
    }

    mutating func markCaptureStarted() -> Bool {
        guard case .starting(let isPaused) = phase else { return false }
        phase = .active(isPaused: isPaused)
        return true
    }

    mutating func pause() -> Bool {
        switch phase {
        case .starting(isPaused: false):
            phase = .starting(isPaused: true)
        case .active(isPaused: false):
            phase = .active(isPaused: true)
        default:
            return false
        }
        return true
    }

    mutating func resume() -> Bool {
        switch phase {
        case .starting(isPaused: true):
            phase = .starting(isPaused: false)
        case .active(isPaused: true):
            phase = .active(isPaused: false)
        default:
            return false
        }
        return true
    }

    mutating func requestStop() -> Bool {
        requestTermination(.finish)
    }

    mutating func requestCancel() -> Bool {
        requestTermination(.cancel)
    }

    mutating func complete() -> Bool {
        guard phase != .idle else { return false }
        phase = .idle
        return true
    }

    private mutating func requestTermination(_ intent: TerminationIntent) -> Bool {
        switch phase {
        case .starting, .active:
            phase = .terminating(intent)
            return true
        case .idle, .terminating:
            return false
        }
    }
}

@MainActor
final class RecordingEngine: NSObject {
    typealias RecordingError = ScreenRecordingError

    enum State: Equatable {
        case idle
        case recording
        case paused
        case stopping
    }

    private let fps: Int
    private let writerCoordinator: RecordingWriterCoordinator

    private var lifecycle = RecordingLifecycle()
    private var sourceRect: CGRect = .zero
    private var stream: SCStream?
    private var streamOutput: RecordingStreamOutput?
    private var captureTask: Task<Void, Never>?
    private var terminationTask: Task<Void, Never>?
    private var progressTimer: Timer?
    private var elapsedSeconds = 0

    var state: State { lifecycle.state }
    var onProgress: RecordingProgressCallback?
    var onCompletion: RecordingCompletionCallback?
    var onPauseChanged: ((Bool) -> Void)?

    init(fps: Int = 30, writerCoordinator: RecordingWriterCoordinator = RecordingWriterCoordinator()) {
        self.fps = fps
        self.writerCoordinator = writerCoordinator
    }

    func startRecording(rect: NSRect, screen: NSScreen, excludeWindowNumbers: [CGWindowID] = []) {
        guard lifecycle.start() else { return }
        guard rect.width > 0, rect.height > 0 else {
            complete(url: nil, error: RecordingError.invalidSelection)
            return
        }

        sourceRect = CGRect(
            x: rect.minX - screen.frame.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        elapsedSeconds = 0

        captureTask = Task { [weak self] in
            await self?.beginCapture(screen: screen, excludeWindowNumbers: excludeWindowNumbers)
        }
    }

    func pauseRecording() {
        guard lifecycle.pause() else { return }
        stopProgressTimer()
        writerCoordinator.pause()
        onPauseChanged?(true)
    }

    func resumeRecording() {
        guard lifecycle.resume() else { return }
        writerCoordinator.resume()
        if stream != nil {
            startProgressTimer()
        }
        onPauseChanged?(false)
    }

    func stopRecording() {
        guard lifecycle.requestStop() else { return }
        stopProgressTimer()
        captureTask?.cancel()
        scheduleTermination()
    }

    func cancelRecording() {
        guard lifecycle.requestCancel() else { return }
        stopProgressTimer()
        captureTask?.cancel()
        writerCoordinator.enqueueCancellation()
        scheduleTermination()
    }

    private func beginCapture(screen: NSScreen, excludeWindowNumbers: [CGWindowID]) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard lifecycle.allowsStartupWork, !Task.isCancelled else { return }

            let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            guard let display = content.displays.first(where: { $0.displayID == screenID }) ?? content.displays.first else {
                await failStartup(RecordingError.noDisplay)
                return
            }

            let excludedWindows = excludeWindowNumbers.compactMap { windowID in
                content.windows.first(where: { $0.windowID == windowID })
            }
            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
            let scale = max(screen.backingScaleFactor, 1)
            let (pixelWidth, pixelHeight) = VideoEncodingSettings.evenDimensions(
                width: sourceRect.width * scale,
                height: sourceRect.height * scale
            )
            let config = makeStreamConfiguration(width: pixelWidth, height: pixelHeight)
            let outputURL = Self.makeOutputURL()

            try await writerCoordinator.prepare(
                outputURL: outputURL,
                width: pixelWidth,
                height: pixelHeight,
                fps: fps
            )
            guard lifecycle.allowsStartupWork, !Task.isCancelled else { return }
            if lifecycle.isPaused {
                writerCoordinator.pause()
            }

            let writerCoordinator = writerCoordinator
            let output = RecordingStreamOutput(
                onFrame: { pixelBuffer, presentationTime in
                    writerCoordinator.appendFromCaptureQueue(
                        pixelBuffer: pixelBuffer,
                        presentationTime: presentationTime
                    )
                },
                onStopped: { [weak self] in
                    Task { @MainActor in
                        self?.stopRecording()
                    }
                }
            )
            streamOutput = output

            let stream = SCStream(filter: filter, configuration: config, delegate: output)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: writerCoordinator.queue)
            self.stream = stream
            try await stream.startCapture()

            guard lifecycle.markCaptureStarted(), !Task.isCancelled else { return }
            onProgress?(0)
            if !lifecycle.isPaused {
                startProgressTimer()
            }
        } catch {
            if lifecycle.terminationIntent == nil {
                await failStartup(error)
            }
        }
    }

    private func makeStreamConfiguration(width: Int, height: Int) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.showsCursor = true
        config.capturesAudio = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.scalesToFit = false
        if #available(macOS 14.0, *) {
            config.colorSpaceName = CGColorSpace.sRGB
        }
        return config
    }

    private func scheduleTermination() {
        guard terminationTask == nil else { return }
        let startupTask = captureTask
        terminationTask = Task { [weak self] in
            _ = await startupTask?.result
            await self?.finishTermination()
        }
    }

    private func finishTermination() async {
        guard let intent = lifecycle.terminationIntent else { return }
        if let stream {
            try? await stream.stopCapture()
            self.stream = nil
        }
        streamOutput = nil

        switch intent {
        case .cancel:
            await writerCoordinator.cancel()
            complete(url: nil, error: nil)
        case .finish:
            switch await writerCoordinator.finish() {
            case .success(let url):
                complete(url: url, error: nil)
            case .failure(let error):
                complete(url: nil, error: error)
            }
        }
    }

    private func failStartup(_ error: Error) async {
        if let stream {
            try? await stream.stopCapture()
            self.stream = nil
        }
        streamOutput = nil
        await writerCoordinator.cancel()
        complete(url: nil, error: error)
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(progressTimerFired(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func progressTimerFired(_ timer: Timer) {
        elapsedSeconds += 1
        onProgress?(elapsedSeconds)
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func complete(url: URL?, error: Error?) {
        guard lifecycle.complete() else { return }
        stopProgressTimer()
        captureTask = nil
        terminationTask = nil
        stream = nil
        streamOutput = nil
        onCompletion?(url, error)
    }

    private static func makeOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = formatter.string(from: Date())
        let token = ProcessInfo.processInfo.globallyUniqueString
            .replacingOccurrences(of: "/", with: "-")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("aulycShot-recording-\(date)-\(token).mp4")
    }
}

/// ScreenCaptureKit owns this delegate after stream startup. Its callbacks are
/// immutable so the framework can invoke them from its delivery queues without
/// racing a later callback replacement.
private final class RecordingStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let onFrame: @Sendable (CVPixelBuffer, CMTime) -> Void
    private let onStopped: @Sendable () -> Void

    init(
        onFrame: @escaping @Sendable (CVPixelBuffer, CMTime) -> Void,
        onStopped: @escaping @Sendable () -> Void
    ) {
        self.onFrame = onFrame
        self.onStopped = onStopped
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pixelBuffer = sampleBuffer.imageBuffer else { return }
        onFrame(pixelBuffer, CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStopped()
    }
}
