import AppKit
import XCTest
@testable import aulycShot

final class UpdateAlertPresentationTests: XCTestCase {
    func testUpdateAlertIsVisibleWithoutStartingApplicationModalSession() throws {
        if ProcessInfo.processInfo.environment["AULYC_SKIP_WINDOW_SERVER_TESTS"] == "1" {
            throw XCTSkip("Requires an interactive WindowServer session")
        }

        let alert = NSAlert()
        alert.messageText = "Update failed"
        let button = alert.addButton(withTitle: "OK")
        var receivedResponse: NSApplication.ModalResponse?

        UpdateAlertPresenter.shared.present(alert) { response in
            receivedResponse = response
        }

        XCTAssertTrue(alert.window.isVisible)
        XCTAssertNil(NSApp.modalWindow)

        button.performClick(nil)

        XCTAssertEqual(receivedResponse, .alertFirstButtonReturn)
        XCTAssertFalse(alert.window.isVisible)
    }

    func testStatusBarUpdateAlertsDoNotUseBlockingRunModal() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot
            .appendingPathComponent("aulycShot/UI/StatusBarController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("alert.runModal()"))
        XCTAssertTrue(source.contains("UpdateAlertPresenter.shared.present(alert)"))
    }
}
