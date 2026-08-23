import AppKit
import XCTest
@testable import aulycShot

@MainActor
final class RecordingSavePromptConfigurationTests: XCTestCase {
    func testManualPreferenceUsesLastSelectedFormatAndAllowsChanges() {
        let configuration = RecordingSavePromptConfiguration(
            preference: .manual,
            lastSelectedFormat: .gif
        )

        XCTAssertEqual(configuration.initialFormat, .gif)
        XCTAssertTrue(configuration.allowsFormatSelection)
    }

    func testMP4PreferenceFixesPromptToMP4() {
        let configuration = RecordingSavePromptConfiguration(
            preference: .mp4,
            lastSelectedFormat: .gif
        )

        XCTAssertEqual(configuration.initialFormat, .mp4)
        XCTAssertFalse(configuration.allowsFormatSelection)
    }

    func testGIFPreferenceFixesPromptToGIF() {
        let configuration = RecordingSavePromptConfiguration(
            preference: .gif,
            lastSelectedFormat: .mp4
        )

        XCTAssertEqual(configuration.initialFormat, .gif)
        XCTAssertFalse(configuration.allowsFormatSelection)
    }

    func testSavePathUsesConfiguredDirectoryByDefault() {
        let defaultDirectory = URL(fileURLWithPath: "/tmp/aulycShot-default-recording-path")
        let selection = RecordingSavePathSelection(defaultDirectory: defaultDirectory)

        XCTAssertTrue(selection.usesDefaultDirectory)
        XCTAssertEqual(selection.selectedDirectory, defaultDirectory)
    }

    func testSavePathUsesCustomDirectoryOnlyWhenDefaultIsDisabled() {
        let defaultDirectory = URL(fileURLWithPath: "/tmp/aulycShot-default-recording-path")
        let customDirectory = URL(fileURLWithPath: "/tmp/aulycShot-custom-recording-path")
        var selection = RecordingSavePathSelection(defaultDirectory: defaultDirectory)

        selection.selectCustomDirectory(customDirectory)
        XCTAssertEqual(selection.selectedDirectory, defaultDirectory)

        selection.usesDefaultDirectory = false
        XCTAssertEqual(selection.selectedDirectory, customDirectory)

        selection.usesDefaultDirectory = true
        XCTAssertEqual(selection.selectedDirectory, defaultDirectory)
    }

    func testSavePathRestoresLastCustomDirectoryForTheNextPrompt() {
        let defaultDirectory = URL(fileURLWithPath: "/tmp/aulycShot-default-recording-path")
        let customDirectory = URL(fileURLWithPath: "/tmp/aulycShot-remembered-recording-path")
        var selection = RecordingSavePathSelection(
            defaultDirectory: defaultDirectory,
            customDirectory: customDirectory
        )

        XCTAssertEqual(selection.customDirectory, customDirectory)
        XCTAssertEqual(selection.selectedDirectory, defaultDirectory)

        selection.usesDefaultDirectory = false
        XCTAssertEqual(selection.selectedDirectory, customDirectory)
    }

    func testLastCustomDirectoryPersistsIndependentlyFromTheDefaultDirectory() {
        let originalCustomDirectory = Defaults.lastCustomRecordingSaveDirectory
        let originalDefaultDirectory = Defaults.recordingSaveDirectory
        defer {
            Defaults.lastCustomRecordingSaveDirectory = originalCustomDirectory
        }

        let customDirectory = URL(
            fileURLWithPath: "/tmp/aulycShot-persisted-recording-path",
            isDirectory: true
        ).standardizedFileURL
        Defaults.lastCustomRecordingSaveDirectory = customDirectory

        XCTAssertEqual(Defaults.lastCustomRecordingSaveDirectory, customDirectory)
        XCTAssertEqual(Defaults.recordingSaveDirectory, originalDefaultDirectory)
    }

    func testSavePanelUsesCompactLeftAlignedHeaderAndFolderIcon() throws {
        if ProcessInfo.processInfo.environment["AULYC_SKIP_WINDOW_SERVER_TESTS"] == "1" {
            throw XCTSkip("Requires an interactive WindowServer session")
        }

        let defaultDirectory = URL(fileURLWithPath: "/tmp/aulycShot-default-recording-path")
        let customDirectory = URL(fileURLWithPath: "/tmp/aulycShot-remembered-recording-path")
        let panel = RecordingSavePanel(
            initialFormat: .mp4,
            allowsFormatSelection: false,
            defaultDirectory: defaultDirectory,
            lastCustomDirectory: customDirectory
        )

        let contentView = try XCTUnwrap(panel.contentView)
        contentView.layoutSubtreeIfNeeded()

        XCTAssertFalse(contentView.hasAmbiguousLayout)
        XCTAssertEqual(panel.frame.width, 333, accuracy: 0.5)
        XCTAssertEqual(panel.appIconView.frame.width, 30, accuracy: 0.5)
        XCTAssertEqual(panel.appIconView.frame.height, 30, accuracy: 0.5)
        XCTAssertEqual(panel.appIconView.frame.midY, panel.headingLabel.frame.midY, accuracy: 0.5)
        XCTAssertEqual(panel.headingLabel.alignment, .left)
        XCTAssertEqual(
            panel.formatLabel.alignmentRect(forFrame: panel.formatLabel.frame).minX,
            panel.appIconView.frame.minX,
            accuracy: 0.5
        )
        XCTAssertEqual(
            panel.defaultPathCheckbox.alignmentRect(forFrame: panel.defaultPathCheckbox.frame).minX,
            panel.formatPopup.alignmentRect(forFrame: panel.formatPopup.frame).minX,
            accuracy: 0.5
        )
        XCTAssertEqual(
            panel.formatPopup.alignmentRect(forFrame: panel.formatPopup.frame).maxX,
            panel.choosePathButton.alignmentRect(forFrame: panel.choosePathButton.frame).maxX,
            accuracy: 0.5
        )
        XCTAssertEqual(
            panel.locationLabel.alignmentRect(forFrame: panel.locationLabel.frame).minX,
            panel.appIconView.frame.minX,
            accuracy: 0.5
        )
        XCTAssertEqual(
            panel.formatPopup.alignmentRect(forFrame: panel.formatPopup.frame).minX
                - panel.formatLabel.alignmentRect(forFrame: panel.formatLabel.frame).maxX,
            8,
            accuracy: 0.5
        )
        XCTAssertEqual(
            panel.pathValue.alignmentRect(forFrame: panel.pathValue.frame).minX
                - panel.locationLabel.alignmentRect(forFrame: panel.locationLabel.frame).maxX,
            8,
            accuracy: 0.5
        )
        XCTAssertEqual(panel.actionStack.frame.midX, contentView.bounds.midX, accuracy: 0.5)
        XCTAssertEqual(panel.locationLabel.stringValue, L10n.recordingSaveLocationLabel)
        XCTAssertEqual(panel.choosePathButton.title, "")
        XCTAssertEqual(panel.choosePathButton.imagePosition, .imageOnly)
        XCTAssertNotNil(panel.choosePathButton.image)
        XCTAssertFalse(panel.formatPopup.isEnabled)
        XCTAssertFalse(panel.choosePathButton.isEnabled)
        XCTAssertLessThan(
            panel.defaultPathCheckbox.frame.maxY,
            panel.locationLabel.frame.minY
        )

        panel.defaultPathCheckbox.performClick(nil)

        XCTAssertFalse(panel.usesDefaultDirectory)
        XCTAssertEqual(panel.selectedDirectory, customDirectory)
        XCTAssertTrue(panel.choosePathButton.isEnabled)
    }

    func testManualFormatKeepsSavePanelPopupEnabled() throws {
        if ProcessInfo.processInfo.environment["AULYC_SKIP_WINDOW_SERVER_TESTS"] == "1" {
            throw XCTSkip("Requires an interactive WindowServer session")
        }

        let panel = RecordingSavePanel(
            initialFormat: .gif,
            allowsFormatSelection: true,
            defaultDirectory: URL(fileURLWithPath: "/tmp/aulycShot-default-recording-path"),
            lastCustomDirectory: nil
        )

        XCTAssertTrue(panel.formatPopup.isEnabled)
        XCTAssertEqual(panel.selectedFormat, .gif)
    }
}
