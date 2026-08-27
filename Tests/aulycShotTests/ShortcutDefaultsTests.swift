import AppKit
import Carbon
import XCTest
@testable import aulycShot

@MainActor
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
        "pinHotkeyKeyCode",
        "pinHotkeyModifiers",
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

            for slot in HotkeySlot.allCases {
                XCTAssertFalse(Defaults.hasHotkey(for: slot))
            }
            XCTAssertNil(UserDefaults.standard.object(forKey: "pinHotkeyKeyCode"))
            XCTAssertNil(UserDefaults.standard.object(forKey: "pinHotkeyModifiers"))
        }
    }

    func testLegacySaveHotkeyMigratesLazilyOnFirstClipboardRead() {
        withRestoredPreferences {
            clearPreferenceKeys()
            let defaults = UserDefaults.standard
            defaults.set(Int(kVK_ANSI_A), forKey: "saveHotkeyKeyCode")
            defaults.set(Int(cmdKey), forKey: "saveHotkeyModifiers")

            XCTAssertEqual(
                Defaults.hotkey(for: .clipboard),
                HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(cmdKey))
            )
            XCTAssertTrue(defaults.bool(forKey: "clipboardHotkeyMigrated"))
            XCTAssertNil(defaults.object(forKey: "saveHotkeyKeyCode"))
            XCTAssertNil(defaults.object(forKey: "saveHotkeyModifiers"))
        }
    }

    func testExistingClipboardHotkeyWinsOverLegacySaveHotkey() {
        withRestoredPreferences {
            clearPreferenceKeys()
            let defaults = UserDefaults.standard
            defaults.set(Int(kVK_ANSI_B), forKey: "clipboardHotkeyKeyCode")
            defaults.set(Int(shiftKey), forKey: "clipboardHotkeyModifiers")
            defaults.set(Int(kVK_ANSI_A), forKey: "saveHotkeyKeyCode")
            defaults.set(Int(cmdKey), forKey: "saveHotkeyModifiers")

            XCTAssertEqual(
                Defaults.hotkey(for: .clipboard),
                HotkeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(shiftKey))
            )
            XCTAssertTrue(defaults.bool(forKey: "clipboardHotkeyMigrated"))
            XCTAssertNotNil(defaults.object(forKey: "saveHotkeyKeyCode"))
            XCTAssertNotNil(defaults.object(forKey: "saveHotkeyModifiers"))
        }
    }

    func testFirstClipboardReadSetsMigrationLatchEvenWhenNothingMigrates() {
        withRestoredPreferences {
            clearPreferenceKeys()
            let defaults = UserDefaults.standard

            XCTAssertFalse(Defaults.hasHotkey(for: .clipboard))
            XCTAssertTrue(defaults.bool(forKey: "clipboardHotkeyMigrated"))

            defaults.set(Int(kVK_ANSI_A), forKey: "saveHotkeyKeyCode")
            defaults.set(Int(cmdKey), forKey: "saveHotkeyModifiers")
            XCTAssertFalse(Defaults.hasHotkey(for: .clipboard))
            XCTAssertNotNil(defaults.object(forKey: "saveHotkeyKeyCode"))
        }
    }

    func testHotkeySlotDescriptorsPreserveStorageAndCarbonIdentity() {
        XCTAssertEqual(HotkeySlot.allCases.count, 9)
        XCTAssertEqual(
            Set(HotkeySlot.allCases.map(\.descriptor.defaultsKeyPrefix)),
            Set([
                "screenshot",
                "selectedImagePin",
                "clipboardImagePin",
                "clipboardTextPin",
                "selectedImageEdit",
                "clipboardImageEdit",
                "record",
                "imageMerge",
                "clipboard",
            ])
        )

        let expectedCarbonIDs: [HotkeySlot: UInt32?] = [
            .screenshot: 1,
            .selectedImagePin: 3,
            .selectedImageEdit: 4,
            .clipboardImageEdit: 5,
            .clipboardImagePin: 6,
            .record: 9,
            .imageMerge: 10,
            .clipboardTextPin: 14,
            .clipboard: nil,
        ]
        for (slot, expectedID) in expectedCarbonIDs {
            XCTAssertEqual(slot.descriptor.carbonHotKeyID, expectedID)
        }

        let globalIDs = HotkeySlot.allCases.compactMap(\.descriptor.carbonHotKeyID)
        XCTAssertEqual(globalIDs.count, 8)
        XCTAssertEqual(Set(globalIDs).count, globalIDs.count)
        XCTAssertEqual(HotkeySlot.allCases.filter(\.descriptor.allowsBareKey), [.clipboard])
    }

    func testCarbonEventIDsRouteBackToTheirDeclaredSlots() {
        for slot in HotkeySlot.globalCases {
            let id = try! XCTUnwrap(slot.descriptor.carbonHotKeyID)
            XCTAssertEqual(HotkeySlot(carbonHotKeyID: id), slot)
        }
        XCTAssertNil(HotkeySlot(carbonHotKeyID: 0))
        XCTAssertNil(HotkeySlot(carbonHotKeyID: UInt32.max))
    }

    func testGenericHotkeyStorageRoundTripsEverySlot() {
        withRestoredPreferences {
            clearPreferenceKeys()

            for (index, slot) in HotkeySlot.allCases.enumerated() {
                let binding = HotkeyBinding(
                    keyCode: UInt32(index),
                    modifiers: UInt32(cmdKey | shiftKey)
                )
                Defaults.setHotkey(binding, for: slot)

                XCTAssertEqual(Defaults.hotkey(for: slot), binding)
                XCTAssertTrue(Defaults.hasHotkey(for: slot))

                Defaults.clearHotkey(for: slot)
                XCTAssertNil(Defaults.hotkey(for: slot))
                XCTAssertFalse(Defaults.hasHotkey(for: slot))
            }
        }
    }

    func testGenericCurrentHotkeyAppliesGlobalAndLocalModifierRules() {
        withRestoredPreferences {
            clearPreferenceKeys()
            Defaults.setHotkey(
                HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: 0),
                for: .screenshot
            )
            Defaults.setHotkey(
                HotkeyBinding(keyCode: UInt32(kVK_F1), modifiers: 0),
                for: .record
            )
            Defaults.setHotkey(
                HotkeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: 0),
                for: .clipboard
            )

            XCTAssertNil(HotkeyManager.shared.currentHotkey(for: .screenshot))
            XCTAssertEqual(
                HotkeyManager.shared.currentHotkey(for: .record),
                HotkeyBinding(keyCode: UInt32(kVK_F1), modifiers: 0)
            )
            XCTAssertEqual(
                HotkeyManager.shared.currentHotkey(for: .clipboard),
                HotkeyBinding(keyCode: UInt32(kVK_ANSI_B), modifiers: 0)
            )
        }
    }

    func testConflictDetectionChecksEveryOtherSlotAndSkipsSelf() {
        withRestoredPreferences {
            clearPreferenceKeys()
            let bindings = Dictionary(uniqueKeysWithValues: HotkeySlot.allCases.enumerated().map {
                index, slot in
                (
                    slot,
                    HotkeyBinding(keyCode: UInt32(index + 1), modifiers: UInt32(cmdKey))
                )
            })
            for (slot, binding) in bindings {
                Defaults.setHotkey(binding, for: slot)
            }

            for slot in HotkeySlot.allCases {
                let binding = try! XCTUnwrap(bindings[slot])
                let otherSlot = HotkeySlot.allCases.first { $0 != slot }!
                XCTAssertEqual(
                    HotkeyManager.shared.hotkeyConflictMessage(
                        forKeyCode: binding.keyCode,
                        modifiers: binding.modifiers,
                        assigningTo: otherSlot
                    ),
                    slot.localizedConflictMessage
                )
                XCTAssertNil(
                    HotkeyManager.shared.hotkeyConflictMessage(
                        forKeyCode: binding.keyCode,
                        modifiers: binding.modifiers,
                        assigningTo: slot
                    )
                )
            }
        }
    }

    func testUnconfiguredScreenshotAndExecutionHaveNoFallbackKeys() {
        withRestoredPreferences {
            Defaults.clearHotkey(for: .screenshot)
            Defaults.clearHotkey(for: .clipboard)

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

    func testShortcutPaneBuildsOneRowPerDeclaredSlot() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))

        XCTAssertEqual(Set(settingsView.shortcutRows.keys), Set(HotkeySlot.allCases))
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

    private func clearPreferenceKeys() {
        for key in preferenceKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
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
