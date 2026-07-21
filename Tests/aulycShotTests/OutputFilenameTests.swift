import XCTest
@testable import aulycShot

final class OutputFilenameTests: XCTestCase {
    func testImageFilenameUsesFixedCollisionSafeFormat() {
        let filename = OutputFilename.imageFileName(fileExtension: "png")

        XCTAssertNotNil(
            filename.range(
                of: #"^aulycShot-[0-9]{6}-[0-9]{6}-[0-9a-f]{3}\.png$"#,
                options: .regularExpression
            )
        )
    }

    func testRecordingFilenameUsesFixedCollisionSafeFormat() {
        let filename = OutputFilename.recordingFileName(fileExtension: "mp4")

        XCTAssertNotNil(
            filename.range(
                of: #"^aulycShot-rec-[0-9]{6}-[0-9]{6}-[0-9a-f]{3}\.mp4$"#,
                options: .regularExpression
            )
        )
    }
}
