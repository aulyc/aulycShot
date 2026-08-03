import CoreMedia
import CoreVideo
import XCTest
@testable import aulycShot

final class RecordingWriterSessionTests: XCTestCase {
    private enum TestError: Error, Equatable {
        case initialization
        case finish
    }

    /// Test assertions and simulated AVFoundation callbacks may arrive outside
    /// the writer queue, so every mutable backend field is protected by `lock`.
    private final class FakeBackend: RecordingWriterBackend, @unchecked Sendable {
        private let lock = NSLock()
        private var storedIsReadyForMoreMediaData = true
        private var storedError: Error?
        private var storedAppendResult = true
        private var storedAutomaticallyFinishes = true
        private var storedSessionStartTimes: [CMTime] = []
        private var storedAppendedTimes: [CMTime] = []
        private var storedMarkAsFinishedCount = 0
        private var storedFinishCount = 0
        private var storedCancelCount = 0
        private var finishCompletion: (@Sendable () -> Void)?

        var isReadyForMoreMediaData: Bool {
            get { withLock { storedIsReadyForMoreMediaData } }
            set { withLock { storedIsReadyForMoreMediaData = newValue } }
        }

        var error: Error? {
            get { withLock { storedError } }
            set { withLock { storedError = newValue } }
        }

        var appendResult: Bool {
            get { withLock { storedAppendResult } }
            set { withLock { storedAppendResult = newValue } }
        }

        var automaticallyFinishes: Bool {
            get { withLock { storedAutomaticallyFinishes } }
            set { withLock { storedAutomaticallyFinishes = newValue } }
        }

        var sessionStartTimes: [CMTime] { withLock { storedSessionStartTimes } }
        var appendedTimes: [CMTime] { withLock { storedAppendedTimes } }
        var markAsFinishedCount: Int { withLock { storedMarkAsFinishedCount } }
        var finishCount: Int { withLock { storedFinishCount } }
        var cancelCount: Int { withLock { storedCancelCount } }

        func startSession(at presentationTime: CMTime) {
            withLock { storedSessionStartTimes.append(presentationTime) }
        }

        func append(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) -> Bool {
            withLock {
                storedAppendedTimes.append(presentationTime)
                return storedAppendResult
            }
        }

        func markAsFinished() {
            withLock { storedMarkAsFinishedCount += 1 }
        }

        func finish(completion: @escaping @Sendable () -> Void) {
            let shouldFinish = withLock {
                storedFinishCount += 1
                if !storedAutomaticallyFinishes {
                    finishCompletion = completion
                }
                return storedAutomaticallyFinishes
            }
            if shouldFinish {
                completion()
            }
        }

        func completeFinish() {
            let completion = withLock {
                let completion = finishCompletion
                finishCompletion = nil
                return completion
            }
            completion?()
        }

        func cancel() {
            withLock { storedCancelCount += 1 }
        }

        @discardableResult
        private func withLock<T>(_ body: () -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body()
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

    func testPauseResumeBuildsContinuousTimelineFromFramePTS() async throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: CMTime(seconds: 10, preferredTimescale: 600)))
            fixture.session.pause()
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: CMTime(seconds: 12, preferredTimescale: 600)))
            fixture.session.resume()
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: CMTime(seconds: 15, preferredTimescale: 600)))
        }
        _ = await finish(fixture)

        assertTimes(fixture.backend.appendedTimes, equal: [10, 10 + 1.0 / 30.0])
        XCTAssertEqual(fixture.backend.sessionStartTimes.map(CMTimeGetSeconds), [10])
    }

    func testMultiplePausesAdvanceByOneFrameAtEachResume() async throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 10)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(10)))
            fixture.session.pause()
            fixture.session.resume()
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(15)))
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(16)))
            fixture.session.pause()
            fixture.session.resume()
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(20)))
        }
        _ = await finish(fixture)

        assertTimes(fixture.backend.appendedTimes, equal: [10, 10.1, 11.1, 11.2])
    }

    func testPauseBeforeFirstFrameKeepsFirstSourcePTS() async throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            fixture.session.pause()
            fixture.session.resume()
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(40)))
        }
        _ = await finish(fixture)

        assertTimes(fixture.backend.appendedTimes, equal: [40])
        assertTimes(fixture.backend.sessionStartTimes, equal: [40])
    }

    func testResumeOffsetCommitsOnlyAfterAFrameIsWritten() async throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 10)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(10)))
            fixture.session.pause()
            fixture.session.resume()
            fixture.backend.appendResult = false
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(15)))
            fixture.backend.appendResult = true
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(16)))
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(17)))
        }
        _ = await finish(fixture)

        assertTimes(fixture.backend.appendedTimes, equal: [10, 10.1, 10.1, 11.1])
    }

    func testNonIncreasingSourcePTSIsRejectedOutsideResumeBoundary() throws {
        let fixture = try makeFixture()

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            XCTAssertTrue(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(10)))
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(10)))
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: seconds(9)))
            XCTAssertFalse(fixture.session.append(pixelBuffer: fixture.pixelBuffer, presentationTime: .invalid))
        }

        assertTimes(fixture.backend.appendedTimes, equal: [10])
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
            fixture.session.pause()
            fixture.session.resume()
            XCTAssertFalse(fixture.session.finish { _ in })
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)

            XCTAssertThrowsError(
                try fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            ) { error in
                XCTAssertEqual(error as? ScreenRecordingError, .writerSetupFailed)
            }

            fixture.session.pause()
            fixture.session.pause()
            fixture.session.resume()
            fixture.session.resume()
            XCTAssertEqual(fixture.session.state, .recording)
        }
    }

    func testFinishCanBeginWhilePaused() async throws {
        let fixture = try makeFixture(createOutputFile: true)

        fixture.queue.sync {
            try? fixture.session.prepare(outputURL: fixture.url, width: 2, height: 2, fps: 30)
            fixture.session.pause()
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

    /// Immutable fixture values cross into the queue closures used by the tests.
    /// CVPixelBuffer is not declared Sendable, but this 2x2 buffer is never
    /// mutated after fixture construction.
    private struct Fixture: @unchecked Sendable {
        let queue: DispatchQueue
        let session: RecordingWriterSession
        let backend: FakeBackend
        let pixelBuffer: CVPixelBuffer
        let url: URL
    }

    /// Completion callbacks update this counter only through its lock.
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

    /// Completion callbacks read and write the outcome only through its lock.
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

    private func assertTimes(
        _ actual: [CMTime],
        equal expected: [TimeInterval],
        accuracy: TimeInterval = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualTime, expectedTime) in zip(actual, expected) {
            XCTAssertEqual(CMTimeGetSeconds(actualTime), expectedTime, accuracy: accuracy, file: file, line: line)
        }
    }

    private func seconds(_ value: TimeInterval) -> CMTime {
        CMTime(seconds: value, preferredTimescale: 600)
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
