import CoreMedia
import CoreVideo
import Foundation

/// The only owner of RecordingWriterSession. Capture callbacks already arrive
/// on `queue`; lifecycle operations are enqueued onto the same serial domain.
final class RecordingWriterCoordinator: @unchecked Sendable {
    let queue: DispatchQueue

    private let backendFactory: RecordingWriterSession.BackendFactory
    private var session: RecordingWriterSession?

    init(
        queue: DispatchQueue = DispatchQueue(label: "aulycShot.recording.writer"),
        backendFactory: @escaping RecordingWriterSession.BackendFactory = { url, width, height, fps in
            try AVAssetRecordingWriterBackend(outputURL: url, width: width, height: height, fps: fps)
        }
    ) {
        self.queue = queue
        self.backendFactory = backendFactory
    }

    func prepare(outputURL: URL, width: Int, height: Int, fps: Int) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                assertOnQueue()
                let newSession = RecordingWriterSession(queue: queue, backendFactory: backendFactory)
                do {
                    try newSession.prepare(outputURL: outputURL, width: width, height: height, fps: fps)
                    session = newSession
                    continuation.resume()
                } catch {
                    session = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func appendFromCaptureQueue(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        assertOnQueue()
        session?.append(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
    }

    func pause() {
        queue.async { [self] in
            assertOnQueue()
            session?.pause()
        }
    }

    func resume() {
        queue.async { [self] in
            assertOnQueue()
            session?.resume()
        }
    }

    func enqueueCancellation() {
        queue.async { [self] in
            assertOnQueue()
            session?.cancel()
            session = nil
        }
    }

    func cancel() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                assertOnQueue()
                session?.cancel()
                session = nil
                continuation.resume()
            }
        }
    }

    func finish() async -> RecordingWriterFinishOutcome {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                assertOnQueue()
                guard let session else {
                    continuation.resume(returning: .failure(ScreenRecordingError.noFrames))
                    return
                }
                let completionQueue = queue
                let didBegin = session.finish { [weak self] outcome in
                    dispatchPrecondition(condition: .onQueue(completionQueue))
                    self?.session = nil
                    continuation.resume(returning: outcome)
                }
                if !didBegin {
                    self.session = nil
                    continuation.resume(returning: .failure(ScreenRecordingError.writerSetupFailed))
                }
            }
        }
    }

    private func assertOnQueue() {
        dispatchPrecondition(condition: .onQueue(queue))
    }
}
