import AppKit
import XCTest
@testable import aulycShot

final class SettingsActionButtonHoverTests: XCTestCase {
    func testHoverChangesActionButtonAppearance() {
        let button = SettingsActionButton(frame: NSRect(x: 0, y: 0, width: 120, height: 34))
        button.enableHoverFeedback()

        XCTAssertEqual(button.bezelColor, SettingsActionButton.restingBezelColor)

        button.setHovered(true)

        XCTAssertTrue(button.isHovered)
        XCTAssertEqual(button.bezelColor, SettingsActionButton.hoveredBezelColor)

        button.setHovered(false)

        XCTAssertFalse(button.isHovered)
        XCTAssertEqual(button.bezelColor, SettingsActionButton.restingBezelColor)
    }

    func testDisabledActionButtonIgnoresHover() {
        let button = SettingsActionButton(frame: NSRect(x: 0, y: 0, width: 120, height: 34))
        button.enableHoverFeedback()
        button.isEnabled = false

        button.setHovered(true)

        XCTAssertFalse(button.isHovered)
        XCTAssertEqual(button.bezelColor, SettingsActionButton.disabledBezelColor)
    }

    func testTitleColorDoesNotChangeBetweenRestingAndHoveredStates() {
        let button = SettingsActionButton(
            title: "Record",
            target: nil,
            action: nil
        )
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.enableHoverFeedback()

        let restingColor = button.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
        button.setHovered(true)
        let hoveredColor = button.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor

        XCTAssertEqual(restingColor, SettingsActionButton.enabledTitleColor)
        XCTAssertEqual(hoveredColor, SettingsActionButton.enabledTitleColor)
    }

    func testDynamicTitleKeepsTheEnabledTitleColor() {
        let button = SettingsActionButton(
            title: "Record",
            target: nil,
            action: nil
        )
        button.enableHoverFeedback()

        button.title = "Cancel"

        let color = button.attributedTitle.attribute(
            .foregroundColor,
            at: 0,
            effectiveRange: nil
        ) as? NSColor
        XCTAssertEqual(color, SettingsActionButton.enabledTitleColor)
    }
}
