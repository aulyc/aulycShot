import XCTest
@testable import aulycShot

final class ToastPresentationTests: XCTestCase {
    func testScreenshotSuccessIsImmediateAndVisibleForExactlyOneSecond() {
        XCTAssertEqual(ToastPresentation.screenshotSuccess.visibleDuration, 1)
        XCTAssertEqual(ToastPresentation.screenshotSuccess.fadeInDuration, 0)
        XCTAssertEqual(ToastPresentation.screenshotSuccess.fadeOutDuration, 0)
    }

    func testStandardToastAnimationRemainsUnchanged() {
        let presentation = ToastPresentation.standard(duration: 3.5)

        XCTAssertEqual(presentation.visibleDuration, 3.5)
        XCTAssertEqual(presentation.fadeInDuration, 0.2)
        XCTAssertEqual(presentation.fadeOutDuration, 0.3)
    }
}
