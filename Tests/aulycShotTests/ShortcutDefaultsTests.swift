import AppKit
import Carbon
import XCTest
@testable import aulycShot

final class ShortcutDefaultsTests: XCTestCase {
    private let preferenceKeys = [
        "screenshotHotkeyKeyCode",
        "screenshotHotkeyModifiers",
        "selectedImagePinHotkeyKeyCode",
        "selectedImagePinHotkeyModifiers",
        "clipboardImagePinHotkeyKeyCode",
        "clipboardImagePinHotkeyModifiers",
        "clipboardTextPinHotkeyKeyCode",
        "clipboardTextPinHotkeyModifiers",
        "selectedImageEditHotkeyKeyCode",
        "selectedImageEditHotkeyModifiers",
        "clipboardImageEditHotkeyKeyCode",
        "clipboardImageEditHotkeyModifiers",
        "recordHotkeyKeyCode",
        "recordHotkeyModifiers",
        "imageMergeHotkeyKeyCode",
        "imageMergeHotkeyModifiers",
        "clipboardHotkeyKeyCode",
        "clipboardHotkeyModifiers",
        "saveHotkeyKeyCode",
        "saveHotkeyModifiers",
        "clipboardHotkeyMigrated",
    ]

    func testResetLeavesEveryShortcutUnconfigured() {
        withRestoredPreferences {
            let keyCode = Int(kVK_ANSI_3)
            let modifiers = Int(cmdKey)
            for key in preferenceKeys where key.hasSuffix("KeyCode") {
                UserDefaults.standard.set(keyCode, forKey: key)
            }
            for key in preferenceKeys where key.hasSuffix("Modifiers") {
                UserDefaults.standard.set(modifiers, forKey: key)
            }
            UserDefaults.standard.removeObject(forKey: "clipboardHotkeyMigrated")

            Defaults.resetShortcutHotkeysToDefaults()

            XCTAssertFalse(Defaults.hasCustomScreenshotHotkey)
            XCTAssertFalse(Defaults.hasCustomSelectedImagePinHotkey)
            XCTAssertFalse(Defaults.hasCustomClipboardImagePinHotkey)
            XCTAssertFalse(Defaults.hasCustomClipboardTextPinHotkey)
            XCTAssertFalse(Defaults.hasCustomSelectedImageEditHotkey)
            XCTAssertFalse(Defaults.hasCustomClipboardImageEditHotkey)
            XCTAssertFalse(Defaults.hasCustomRecordHotkey)
            XCTAssertFalse(Defaults.hasCustomImageMergeHotkey)
            XCTAssertFalse(Defaults.hasCustomClipboardHotkey)
        }
    }

    func testUnconfiguredScreenshotAndExecutionHaveNoFallbackKeys() {
        withRestoredPreferences {
            Defaults.clearScreenshotHotkey()
            Defaults.clearClipboardHotkey()

            let screenshotMenuItem = NSMenuItem()
            HotkeyManager.applyToMenuItem(screenshotMenuItem)

            XCTAssertNil(HotkeyManager.currentDisplayString())
            XCTAssertNil(HotkeyManager.currentClipboardDisplayString())
            XCTAssertEqual(screenshotMenuItem.keyEquivalent, "")
            XCTAssertEqual(screenshotMenuItem.keyEquivalentModifierMask, [])
            XCTAssertNil(ToolbarItemID.confirm.editorShortcutDisplay)
        }
    }

    func testShortcutRowsDoNotContainPerRowRestoreButtons() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let shortcutTab = try XCTUnwrap(
            settingsView.descendants(of: TabButton.self).first { $0.tab == .shortcuts }
        )
        shortcutTab.sendAction(shortcutTab.action, to: shortcutTab.target)
        settingsView.layoutSubtreeIfNeeded()

        let imageOnlyActionButtons = settingsView.descendants(of: SettingsActionButton.self).filter {
            $0.imagePosition == .imageOnly
        }
        XCTAssertTrue(imageOnlyActionButtons.isEmpty)
    }

    private func withRestoredPreferences(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previousValues = Dictionary(uniqueKeysWithValues: preferenceKeys.map {
            ($0, defaults.object(forKey: $0))
        })
        defer {
            for (key, value) in previousValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        body()
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
