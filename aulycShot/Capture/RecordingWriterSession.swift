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

enum RecordingWriterFinishOutcome: @unchecked Sendable {
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
    private(set) var totalPausedDuration: TimeInterval = 0
    private var pauseStartTime: TimeInterval?
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
              backend.isReadyForMoreMediaData
        else {
            return false
        }

        let adjustedTime = adjustedPresentationTime(presentationTime)
        if !sessionStarted {
            backend.startSession(at: adjustedTime)
            sessionStarted = true
        }

        let appended = backend.append(pixelBuffer, at: adjustedTime)
        if appended {
            hasWrittenFrame = true
        }
        return appended
    }

    func pause(at time: TimeInterval) {
        assertOnQueue()
        guard state == .recording else { return }
        pauseStartTime = time
        state = .paused
    }

    func resume(at time: TimeInterval) {
        assertOnQueue()
        guard state == .paused else { return }
        if let pauseStartTime {
            totalPausedDuration += max(0, time - pauseStartTime)
        }
        pauseStartTime = nil
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
        pauseStartTime = nil
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
        pauseStartTime = nil
        cleanupOutput()
    }

    private func adjustedPresentationTime(_ time: CMTime) -> CMTime {
        guard totalPausedDuration > 0 else { return time }
        return CMTimeSubtract(
            time,
            CMTimeMakeWithSeconds(totalPausedDuration, preferredTimescale: time.timescale)
        )
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
