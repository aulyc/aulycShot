import CoreMedia
import CoreVideo
import XCTest
@testable import aulycShot

final class RecordingWriterSessionTests: XCTestCase {
    private enum TestError: Error, Equatable {
        case initialization
        case finish
    }

    private final class FakeBackend: RecordingWriterBackend, @unchecked Sendable {
        var isReadyForMoreMediaData = true
        var error: Error?
        var appendResult = true
        var automaticallyFinishes = true
        private(set) var sessionStartTimes: [CMTime] = []
        private(set) var appendedTimes: [CMTime] = []
        private(set) var markAsFinishedCount = 0
        private(set) var finishCount = 0
        private(set) var cancelCount = 0
        private var finishCompletion: (@Sendable () -> Void)?

        func startSession(at presentationTime: CMTime) {
            sessionStartTimes.append(presentationTime)
        }

        func append(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) -> Bool {
            appendedTimes.append(presentationTime)
            return appendResult
        }

        func markAsFinished() {
            markAsFinishedCount += 1
        }

        func finish(completion: @escaping @Sendable () -> Void) {
            finishCount += 1
            if automaticallyFinishes {
                completion()
            } else {
                finishCompletion = completion
            }
        }

        func completeFinish() {
            let completion = finishCompletion
            finishCompletion = nil
            completion?()
        }

        func cancel() {
            cancelCount += 1
        }
    }

    func testScreenRecordingErrorsExposeStableDescriptions() {
        XCTAssertEqual(ScreenRecordingError.invalidSelection.errorDescription, "The selected recording area is empty")
        XCTAssertEqual(ScreenRecordingError.noDisplay.errorDescription, "Could not find the selected display")
        XCTAssertEqual(ScreenRecordingError.noFrames.errorDescription, "No video frames were recorded")
        XCTAssertEqual(ScreenRecordingError.writerSetupFailed.errorDescription, "Could not prepare the recording writer")
    }

    func testNormalStopFinishesWrittenOutput() async throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try! fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: CMTime(seconds: 10, preferredTimescale: 600)))
        }
        let outcome = await finish(fixture)

        guard case .success(let outputURL) = outcome else {
            return XCTFail("Expected successful writer completion")
        }
        XCTAssertEqual(outputURL, fixture.url)
        XCTAssertEqual(fixture.backend.sessionStartTimes.count, 1)
        XCTAssertEqual(fixture.backend.appendedTimes.count, 1)
        XCTAssertEqual(fixture.backend.markAsFinishedCount, 1)
        XCTAssertEqual(fixture.backend.finishCount, 1)
        XCTAssertEqual(fixture.session.state, .finished)
    }

    func testPauseResumeAdjustsPresentationTimeOnce() async throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: CMTime(seconds: 10, preferredTimescale: 600)))
            fixture.session.pause(at: 100)
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: CMTime(seconds: 12, preferredTimescale: 600)))
            fixture.session.resume(at: 102.5)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: CMTime(seconds: 15, preferredTimescale: 600)))
        }
        _ = await finish(fixture)

        XCTAssertEqual(fixture.session.totalPausedDuration, 2.5, accuracy: 0.0001)
        XCTAssertEqual(fixture.backend.appendedTimes.map(CMTimeGetSeconds), [10, 12.5])
        XCTAssertEqual(fixture.backend.sessionStartTimes.map(CMTimeGetSeconds), [10])
    }

    func testCancelRemovesTemporaryOutputAndRejectsNewFrames() throws {
        let fixture = try makeFixture(createOutputFile: true)

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            fixture.session.cancel()
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .zero))
            fixture.session.cancel()
        }

        XCTAssertEqual(fixture.session.state, .cancelled)
        XCTAssertEqual(fixture.backend.cancelCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.url.path))
    }

    func testNoFramesFailsAndRemovesTemporaryOutput() async throws {
        let fixture = try makeFixture(createOutputFile: true)

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
        }
        let outcome = await finish(fixture)

        assertFailure(outcome, equals: ScreenRecordingError.noFrames)
        XCTAssertEqual(fixture.session.state, .failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.url.path))
    }

    func testInitializationFailureCleansOutputAndKeepsFailedState() throws {
        let queue = DispatchQueue(label: "RecordingWriterSessionTests.initialization")
        let url = temporaryURL()
        try Data("partial".utf8).write(to: url)
        let session = RecordingWriterSession(queue: queue) { _, _, _, _ in
            throw TestError.initialization
        }

        queue.sync {
            do {
                try session.prepare(outputURL: url, width: 2, height: 2, fps: 30)
                XCTFail("Expected initialization failure")
            } catch {
                XCTAssertEqual(error as? TestError, .initialization)
            }
        }

        XCTAssertEqual(session.state, .failed)
        XCTAssertNil(session.outputURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testWriterFailureWinsOverWrittenFrameAndCleansOutput() async throws {
        let fixture = try makeFixture(createOutputFile: true)
        fixture.backend.error = TestError.finish

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .zero))
        }
        let outcome = await finish(fixture)

        assertFailure(outcome, equals: TestError.finish)
        XCTAssertEqual(fixture.session.state, .failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.url.path))
    }

    func testBackpressureAndAppendFailureDoNotClaimAFrame() throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            fixture.backend.isReadyForMoreMediaData = false
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .zero))
            fixture.backend.isReadyForMoreMediaData = true
            fixture.backend.appendResult = false
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .zero))
        }

        XCTAssertFalse(fixture.session.hasWrittenFrame)
        XCTAssertEqual(fixture.backend.sessionStartTimes.count, 1)
    }

    func testRepeatedFinishStartsOneBackendCompletionAndRejectsFrames() async throws {
        let fixture = try makeFixture()
        fixture.backend.automaticallyFinishes = false
        let completionExpectation = expectation(description: "writer completion")
        let completionCount = SendableCounter()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .zero))
            XCTAssertTrue(fixture.session.finish { _ in
                completionCount.increment()
                completionExpectation.fulfill()
            })
            XCTAssertFalse(fixture.session.finish { _ in
                completionCount.increment()
            })
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .zero))
        }
        fixture.backend.completeFinish()

        await fulfillment(of: [completionExpectation], timeout: 1)
        XCTAssertEqual(completionCount.value, 1)
        XCTAssertEqual(fixture.backend.finishCount, 1)
    }

    func testInvalidStateTransitionsAreIgnoredOrRejected() throws {
        let fixture = try makeFixture()

        try fixture.queue.sync {
            fixture.session.pause(at: 1)
            fixture.session.resume(at: 2)
            XCTAssertFalse(fixture.session.finish { _ in })
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)

            XCTAssertThrowsError(
                try fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            ) { error in
                XCTAssertEqual(error as? ScreenRecordingError, .writerSetupFailed)
            }

            fixture.session.pause(at: 10)
            fixture.session.pause(at: 11)
            fixture.session.resume(at: 8)
            fixture.session.resume(at: 12)
            XCTAssertEqual(fixture.session.totalPausedDuration, 0)
            XCTAssertEqual(fixture.session.state, .recording)
        }
    }

    func testFinishCanBeginWhilePaused() async throws {
        let fixture = try makeFixture(createOutputFile: true)

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            fixture.session.pause(at: 10)
        }
        let outcome = await finish(fixture)

        assertFailure(outcome, equals: ScreenRecordingError.noFrames)
        XCTAssertEqual(fixture.session.state, .failed)
    }

    func testCancelWhileFinishIsPendingWinsAndCompletionStillFiresOnce() async throws {
        let fixture = try makeFixture(createOutputFile: true)
        fixture.backend.automaticallyFinishes = false
        let completionExpectation = expectation(description: "writer completion after cancellation")
        let completionCount = SendableCounter()
        let outcomeBox = SendableOutcomeBox()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .zero))
            XCTAssertTrue(fixture.session.finish { outcome in
                outcomeBox.value = outcome
                completionCount.increment()
                completionExpectation.fulfill()
            })
            fixture.session.cancel()
        }
        fixture.backend.completeFinish()

        await fulfillment(of: [completionExpectation], timeout: 1)
        XCTAssertEqual(completionCount.value, 1)
        XCTAssertEqual(fixture.session.state, .cancelled)
        XCTAssertEqual(fixture.backend.cancelCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.url.path))
        guard let outcome = outcomeBox.value else {
            return XCTFail("Expected completion outcome")
        }
        assertFailure(outcome, equals: ScreenRecordingError.writerSetupFailed)
    }

    private struct Fixture: @unchecked Sendable {
        let queue: DispatchQueue
        let session: RecordingWriterSession
        let backend: FakeBackend
        let pixelBuffer: CVPixelBuffer
        let url: URL
    }

    private final class SendableCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }

        func increment() {
            lock.lock()
            count += 1
            lock.unlock()
        }
    }

    private final class SendableOutcomeBox: @unchecked Sendable {
        private let lock = NSLock()
        private var storedValue: RecordingWriterFinishOutcome?

        var value: RecordingWriterFinishOutcome? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return storedValue
            }
            set {
                lock.lock()
                storedValue = newValue
                lock.unlock()
            }
        }
    }

    private func makeFixture(createOutputFile: Bool = false) throws -> Fixture {
        let queue = DispatchQueue(label: "RecordingWriterSessionTests.\(UUID().uuidString)")
        let backend = FakeBackend()
        let session = RecordingWriterSession(queue: queue) { _, _, _, _ in backend }
        let url = temporaryURL()
        if createOutputFile {
            try Data("partial".utf8).write(to: url)
        }
        return Fixture(
            queue: queue,
            session: session,
            backend: backend,
            pixelBuffer: try makePixelBuffer(),
            url: url
        )
    }

    private func finish(_ fixture: Fixture) async -> RecordingWriterFinishOutcome {
        await withCheckedContinuation { continuation in
            fixture.queue.async {
                XCTAssertTrue(fixture.session.finish { outcome in
                    continuation.resume(returning: outcome)
                })
            }
        }
    }

    private func assertFailure<T: Error & Equatable>(
        _ outcome: RecordingWriterFinishOutcome,
        equals expectedError: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let error) = outcome else {
            return XCTFail("Expected writer failure", file: file, line: line)
        }
        XCTAssertEqual(error as? T, expectedError, file: file, line: line)
    }

    private func makePixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            2,
            2,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw ScreenRecordingError.writerSetupFailed
        }
        return pixelBuffer
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("RecordingWriterSessionTests-\(UUID().uuidString).mp4")
    }
}
