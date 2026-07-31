import AppKit
import XCTest
@testable import aulycShot

final class UpdateAlertPresentationTests: XCTestCase {
    func testUpdatePanelContainsOnlyRequestedControlsAndIsNonmodal() throws {
        if ProcessInfo.processInfo.environment["AULYC_SKIP_WINDOW_SERVER_TESTS"] == "1" {
            throw XCTSkip("Requires an interactive WindowServer session")
        }

        var receivedResponse: NSApplication.ModalResponse?
        let panel = try XCTUnwrap(
            UpdateAlertPresenter.shared.present(
                UpdateAlertPresentation(
                    title: "You're up to date",
                    message: "Current version v1.8.2",
                    buttonTitles: ["OK"]
                )
            ) { response in
                receivedResponse = response
            }
        )

        XCTAssertTrue(panel.isVisible)
        XCTAssertNil(NSApp.modalWindow)
        XCTAssertEqual(panel.sharingType, .readWrite)
        XCTAssertEqual(panel.actionButtons.map(\.title), ["OK"])
        XCTAssertNil(panel.standardWindowButton(.closeButton))
        XCTAssertNil(panel.standardWindowButton(.miniaturizeButton))
        XCTAssertNil(panel.standardWindowButton(.zoomButton))

        let contentView = try XCTUnwrap(panel.contentView)
        contentView.layoutSubtreeIfNeeded()
        let contentButtons = contentView.descendantButtons
        XCTAssertEqual(contentButtons.map(\.title), ["OK"])
        XCTAssertFalse(contentButtons.contains(where: { $0.title.isEmpty }))
        XCTAssertFalse(contentView.hasAmbiguousLayout)
        XCTAssertEqual(panel.frame.width, 340, accuracy: 0.5)
        XCTAssertEqual(panel.actionButtons[0].frame.width, 300, accuracy: 0.5)
        XCTAssertEqual(panel.actionButtons[0].frame.height, 36, accuracy: 0.5)
        let titleLabel = try XCTUnwrap(
            contentView.descendantTextFields.first { $0.stringValue == "You're up to date" }
        )
        let titleFont = try XCTUnwrap(titleLabel.font)
        XCTAssertEqual(titleFont.pointSize, 17, accuracy: 0.5)

        panel.actionButtons[0].performClick(nil)

        XCTAssertEqual(receivedResponse, .alertFirstButtonReturn)
        XCTAssertFalse(panel.isVisible)
    }

    func testUpdatePanelReturnsTheSelectedActionWithoutCreatingBlankButtons() throws {
        if ProcessInfo.processInfo.environment["AULYC_SKIP_WINDOW_SERVER_TESTS"] == "1" {
            throw XCTSkip("Requires an interactive WindowServer session")
        }

        var receivedResponse: NSApplication.ModalResponse?
        let panel = try XCTUnwrap(
            UpdateAlertPresenter.shared.present(
                UpdateAlertPresentation(
                    title: "Version v1.8.3 is available",
                    message: "Install the latest version",
                    buttonTitles: ["Update Now", "Skip This Version", "Later"]
                )
            ) { response in
                receivedResponse = response
            }
        )

        XCTAssertEqual(
            panel.actionButtons.map(\.title),
            ["Update Now", "Skip This Version", "Later"]
        )
        XCTAssertFalse(panel.actionButtons.contains { $0.title.isEmpty })

        panel.actionButtons[1].performClick(nil)

        XCTAssertEqual(receivedResponse, .alertSecondButtonReturn)
        XCTAssertFalse(panel.isVisible)
    }

    func testStatusBarUpdateAlertsUseDedicatedPanelInsteadOfNSAlert() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot
            .appendingPathComponent("aulycShot/UI/StatusBarController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("NSAlert()"))
        XCTAssertTrue(source.contains("UpdateAlertPresentation("))
        XCTAssertTrue(source.contains("UpdateAlertPresenter.shared.present("))
    }

    func testUpToDateCopyDoesNotRepeatLatestVersionMeaning() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let chinese = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Resources/zh-Hans.lproj/Localizable.strings"),
            encoding: .utf8
        )
        let english = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Resources/en.lproj/Localizable.strings"),
            encoding: .utf8
        )

        XCTAssertTrue(chinese.contains("\"updateUpToDateTitle\" = \"已是最新版本\""))
        XCTAssertTrue(chinese.contains("\"updateUpToDateBody\" = \"当前版本 v%@\""))
        XCTAssertTrue(english.contains("\"updateUpToDateTitle\" = \"You're up to date\""))
        XCTAssertTrue(english.contains("\"updateUpToDateBody\" = \"Current version v%@\""))
    }
}

private extension NSView {
    var descendantButtons: [NSButton] {
        subviews.flatMap { view in
            (view as? NSButton).map { [$0] } ?? view.descendantButtons
        }
    }

    var descendantTextFields: [NSTextField] {
        subviews.flatMap { view in
            (view as? NSTextField).map { [$0] } ?? view.descendantTextFields
        }
    }
}
