import AppKit
import XCTest
@testable import aulycShot

final class SettingsScreenshotQualityControlTests: XCTestCase {
    func testBooleanSettingsUseActivationPickersInsteadOfSwitches() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let expectedStates = SettingsActivationState.allCases
        let expectedRawValues = expectedStates.map(\.rawValue)
        let expectedTitles = expectedStates.map(\.localizedTitle)
        for identifier in [
            "menu-bar-state-picker",
            "launch-at-login-state-picker",
            "automatic-update-checks-state-picker",
            "demo-mode-state-picker",
        ] {
            let picker = try XCTUnwrap(
                settingsView.descendants(of: SettingsPopUpButton.self).first {
                    $0.identifier?.rawValue == identifier
                }
            )

            XCTAssertEqual(
                picker.itemArray.compactMap { $0.representedObject as? String },
                expectedRawValues
            )
            XCTAssertEqual(picker.itemTitles, expectedTitles)
        }

        XCTAssertTrue(settingsView.descendants(of: NSSwitch.self).isEmpty)
    }

    func testAutomaticUpdateChecksDefaultToEnabledAndPersistUserChoice() {
        let key = "automaticUpdateChecksEnabled"
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        XCTAssertTrue(Defaults.automaticUpdateChecksEnabled)

        Defaults.automaticUpdateChecksEnabled = false
        XCTAssertFalse(Defaults.automaticUpdateChecksEnabled)

        Defaults.automaticUpdateChecksEnabled = true
        XCTAssertTrue(Defaults.automaticUpdateChecksEnabled)
    }

    func testGeneralPaneContainsOneSharedScreenshotQualityPicker() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let qualityPickers = settingsView.descendants(of: NSPopUpButton.self).filter { popup in
            Set(popup.itemArray.compactMap { $0.representedObject as? String }) == ["original", "compressed"]
        }

        XCTAssertEqual(qualityPickers.count, 1)
    }

    func testSavePathControlsMatchPopupWidthAndUseSquareFolderButtons() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let referencePopup = try XCTUnwrap(settingsView.descendants(of: SettingsPopUpButton.self).first)
        for prefix in ["screenshot", "recording"] {
            let group = try XCTUnwrap(settingsView.descendants(of: NSStackView.self).first {
                $0.identifier?.rawValue == "\(prefix)-save-path-controls"
            })
            let chooseButton = try XCTUnwrap(settingsView.descendants(of: SettingsOutlinedButton.self).first {
                $0.identifier?.rawValue == "\(prefix)-save-path-choose"
            })
            let revealButton = try XCTUnwrap(settingsView.descendants(of: SettingsOutlinedButton.self).first {
                $0.identifier?.rawValue == "\(prefix)-save-path-reveal"
            })

            XCTAssertEqual(group.frame.width, referencePopup.frame.width, accuracy: 0.5)
            XCTAssertEqual(chooseButton.frame.minX, group.bounds.minX, accuracy: 0.5)
            XCTAssertEqual(revealButton.frame.maxX, group.bounds.maxX, accuracy: 0.5)
            XCTAssertEqual(
                chooseButton.frame.width + group.spacing + revealButton.frame.width,
                referencePopup.frame.width,
                accuracy: 0.5
            )
            XCTAssertEqual(revealButton.frame.width, 34, accuracy: 0.5)
            XCTAssertEqual(revealButton.frame.height, 34, accuracy: 0.5)
            XCTAssertEqual(revealButton.imagePosition, .imageOnly)
            XCTAssertEqual(revealButton.accessibilityLabel(), L10n.savePathReveal)
            XCTAssertEqual(chooseButton.layer?.cornerRadius, SettingsOutlinedButton.cornerRadius)
        }
    }

    func testGeneralPaneOmitsRemovedWindowShadowPicker() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let removedShadowValues = Set(["disabled", "small", "medium", "large"])
        let removedShadowPickers = settingsView.descendants(of: NSPopUpButton.self).filter { popup in
            Set(popup.itemArray.compactMap { $0.representedObject as? String }) == removedShadowValues
        }

        XCTAssertTrue(removedShadowPickers.isEmpty)
    }

    func testPermissionAlertOutsideClickDismissalPolicy() {
        let sheetFrame = NSRect(x: 100, y: 100, width: 300, height: 240)

        XCTAssertFalse(
            PermissionAlertDismissalPolicy.shouldDismiss(
                sheetFrame: sheetFrame,
                clickScreenPoint: NSPoint(x: 250, y: 220)
            )
        )
        XCTAssertTrue(
            PermissionAlertDismissalPolicy.shouldDismiss(
                sheetFrame: sheetFrame,
                clickScreenPoint: NSPoint(x: 40, y: 40)
            )
        )
    }
}

private extension NSView {
    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { child -> [T] in
            let current = child as? T
            return (current.map { [$0] } ?? []) + child.descendants(of: type)
        }
    }
}
