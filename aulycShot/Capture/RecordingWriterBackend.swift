import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

protocol RecordingWriterBackend: AnyObject {
    var isReadyForMoreMediaData: Bool { get }
    var error: Error? { get }

    func startSession(at presentationTime: CMTime)
    func append(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) -> Bool
    func markAsFinished()
    func finish(completion: @escaping @Sendable () -> Void)
    func cancel()
}

final class AVAssetRecordingWriterBackend: RecordingWriterBackend, @unchecked Sendable {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor

    var isReadyForMoreMediaData: Bool { input.isReadyForMoreMediaData }
    var error: Error? { writer.error }

    init(outputURL: URL, width: Int, height: Int, fps: Int) throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: VideoEncodingSettings.outputSettings(width: width, height: height, fps: fps)
        )
        input.expectsMediaDataInRealTime = true

        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )

        guard writer.canAdd(input) else {
            throw ScreenRecordingError.writerSetupFailed
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? ScreenRecordingError.writerSetupFailed
        }

        self.writer = writer
        self.input = input
        self.adaptor = adaptor
    }

    func startSession(at presentationTime: CMTime) {
        writer.startSession(atSourceTime: presentationTime)
    }

    func append(_ pixelBuffer: CVPixelBuffer, at presentationTime: CMTime) -> Bool {
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    func markAsFinished() {
        input.markAsFinished()
    }

    func finish(completion: @escaping @Sendable () -> Void) {
        writer.finishWriting(completionHandler: completion)
    }

    func cancel() {
        writer.cancelWriting()
    }
}
