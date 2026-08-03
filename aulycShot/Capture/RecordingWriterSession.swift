import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

enum ScreenRecordingError: LocalizedError, Equatable {
    case invalidSelection
    case noDisplay
    case noFrames
    case writerSetupFailed

    var errorDescription: String? {
        switch self {
        case .invalidSelection: return "The selected recording area is empty"
        case .noDisplay: return "Could not find the selected display"
        case .noFrames: return "No video frames were recorded"
        case .writerSetupFailed: return "Could not prepare the recording writer"
        }
    }
}

enum RecordingWriterFinishOutcome: Sendable {
    case success(URL)
    case failure(Error)
}

/// Queue-confined AVAssetWriter state. Every mutating method asserts that it is
/// running on the queue supplied at initialization.
final class RecordingWriterSession: @unchecked Sendable {
    typealias BackendFactory = (_ outputURL: URL, _ width: Int, _ height: Int, _ fps: Int) throws -> RecordingWriterBackend

    enum State: Equatable {
        case unprepared
        case recording
        case paused
        case finishing
        case finished
        case cancelled
        case failed
    }

    private let queue: DispatchQueue
    private let backendFactory: BackendFactory
    private let fileManager: FileManager

    private(set) var state: State = .unprepared
    private(set) var sessionStarted = false
    private(set) var hasWrittenFrame = false
    private(set) var outputURL: URL?
    private var nominalFrameDuration: CMTime = .invalid
    private var presentationOffset: CMTime = .zero
    private var lastWrittenPresentationTime: CMTime?
    private var resumePending = false
    private var backend: RecordingWriterBackend?

    init(
        queue: DispatchQueue,
        fileManager: FileManager = .default,
        backendFactory: @escaping BackendFactory = { url, width, height, fps in
            try AVAssetRecordingWriterBackend(outputURL: url, width: width, height: height, fps: fps)
        }
    ) {
        self.queue = queue
        self.fileManager = fileManager
        self.backendFactory = backendFactory
    }

    func prepare(outputURL: URL, width: Int, height: Int, fps: Int) throws {
        assertOnQueue()
        guard state == .unprepared else {
            throw ScreenRecordingError.writerSetupFailed
        }

        self.outputURL = outputURL
        do {
            backend = try backendFactory(outputURL, width, height, fps)
            nominalFrameDuration = CMTime(value: 1, timescale: CMTimeScale(max(fps, 1)))
            state = .recording
        } catch {
            state = .failed
            cleanupOutput()
            throw error
        }
    }

    @discardableResult
    func append(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> Bool {
        assertOnQueue()
        guard state == .recording,
              let backend,
              backend.isReadyForMoreMediaData,
              let adjustment = timelineAdjustment(for: presentationTime)
        else {
            return false
        }

        if !sessionStarted {
            backend.startSession(at: adjustment.outputTime)
            sessionStarted = true
        }

        let appended = backend.append(pixelBuffer, at: adjustment.outputTime)
        if appended {
            presentationOffset = adjustment.offset
            lastWrittenPresentationTime = adjustment.outputTime
            resumePending = false
            hasWrittenFrame = true
        }
        return appended
    }

    func pause() {
        assertOnQueue()
        guard state == .recording else { return }
        state = .paused
    }

    func resume() {
        assertOnQueue()
        guard state == .paused else { return }
        resumePending = true
        state = .recording
    }

    @discardableResult
    func finish(completion: @escaping @Sendable (RecordingWriterFinishOutcome) -> Void) -> Bool {
        assertOnQueue()
        guard state == .recording || state == .paused,
              let backend,
              outputURL != nil
        else {
            return false
        }

        state = .finishing
        backend.markAsFinished()
        backend.finish { [weak self] in
            guard let self else { return }
            self.queue.async {
                completion(self.completeFinish())
            }
        }
        return true
    }

    func cancel() {
        assertOnQueue()
        guard state != .cancelled, state != .finished, state != .failed else { return }
        state = .cancelled
        backend?.cancel()
        backend = nil
        resumePending = false
        cleanupOutput()
    }

    private struct TimelineAdjustment {
        let outputTime: CMTime
        let offset: CMTime
    }

    /// Builds the output timeline exclusively from the stream's frame PTS.
    /// On resume, the first successfully written frame follows the previous
    /// output by one nominal frame, so no second clock needs to be aligned.
    private func timelineAdjustment(for sourceTime: CMTime) -> TimelineAdjustment? {
        guard sourceTime.isNumeric else { return nil }

        if resumePending, let lastWrittenPresentationTime {
            let targetTime = CMTimeAdd(lastWrittenPresentationTime, nominalFrameDuration)
            guard targetTime.isNumeric else { return nil }
            return TimelineAdjustment(
                outputTime: targetTime,
                offset: CMTimeSubtract(sourceTime, targetTime)
            )
        }

        let outputTime = CMTimeSubtract(sourceTime, presentationOffset)
        guard outputTime.isNumeric else { return nil }
        if let lastWrittenPresentationTime,
           CMTimeCompare(outputTime, lastWrittenPresentationTime) <= 0 {
            return nil
        }
        return TimelineAdjustment(outputTime: outputTime, offset: presentationOffset)
    }

    private func completeFinish() -> RecordingWriterFinishOutcome {
        assertOnQueue()
        guard state == .finishing, let outputURL else {
            return .failure(ScreenRecordingError.writerSetupFailed)
        }

        let writerError = backend?.error
        backend = nil
        if let writerError {
            state = .failed
            cleanupOutput()
            return .failure(writerError)
        }
        guard hasWrittenFrame else {
            state = .failed
            cleanupOutput()
            return .failure(ScreenRecordingError.noFrames)
        }

        state = .finished
        self.outputURL = nil
        return .success(outputURL)
    }

    private func cleanupOutput() {
        let url = outputURL
        outputURL = nil
        if let url {
            try? fileManager.removeItem(at: url)
        }
    }

    private func assertOnQueue() {
        dispatchPrecondition(condition: .onQueue(queue))
    }
}
