import AppKit
import Carbon
import XCTest
@testable import aulycShot

final class PermissionStatusFooterTests: XCTestCase {
    func testSidebarContainsOneFeatureStatusIndicator() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let indicators = settingsView.descendants(of: PermissionStatusIndicator.self)
        XCTAssertEqual(indicators.count, 1)
    }

    func testFeatureHelpButtonFollowsStatus() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let helpButton = try XCTUnwrap(settingsView.descendants(of: NSButton.self).first {
            $0.accessibilityLabel() == L10n.featurePermissionHelpTooltip
        })
        let feature = try XCTUnwrap(
            settingsView.descendants(of: PermissionStatusIndicator.self).first {
                $0.title == L10n.featurePermissionStatus
            }
        )

        let featureFrame = feature.convert(feature.bounds, to: settingsView)
        let helpFrame = helpButton.convert(
            helpButton.bounds,
            to: settingsView
        )

        XCTAssertGreaterThan(helpFrame.minX, featureFrame.maxX)
        XCTAssertEqual(helpFrame.midY, featureFrame.midY, accuracy: 0.5)
    }

    func testPermissionHelpButtonsUsePointingHandCursorTracking() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let button = try XCTUnwrap(settingsView.descendants(of: HoverButton.self).first {
            $0.accessibilityLabel() == L10n.featurePermissionHelpTooltip
        })
        button.updateTrackingAreas()
        XCTAssertTrue(button.trackingAreas.contains { area in
            area.options.contains(.cursorUpdate)
        })
    }

    func testFooterAlignsWithSettingsTitleAndUsesMatchingFontSize() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let textFields = settingsView.descendants(of: NSTextField.self)
        let settingsTitle = try XCTUnwrap(textFields.first { $0.stringValue == L10n.settings })
        let versionLabel = try XCTUnwrap(textFields.first {
            $0.identifier?.rawValue == "sidebar-version"
        })
        let feature = try XCTUnwrap(
            settingsView.descendants(of: PermissionStatusIndicator.self).first {
                $0.title == L10n.featurePermissionStatus
            }
        )

        let settingsTitleX = settingsTitle.convert(settingsTitle.bounds, to: settingsView).minX
        let featureTitleX = feature.titleLabel.convert(
            feature.titleLabel.bounds,
            to: settingsView
        ).minX
        let versionX = versionLabel.convert(versionLabel.bounds, to: settingsView).minX
        XCTAssertEqual(featureTitleX, settingsTitleX, accuracy: 0.5)
        XCTAssertEqual(versionX, settingsTitleX, accuracy: 0.5)
        XCTAssertEqual(versionLabel.font?.pointSize, feature.titleLabel.font?.pointSize)
    }

    func testStatusNameDotAndValueUseRequestedOrderAndColors() throws {
        let indicator = PermissionStatusIndicator(title: L10n.featurePermissionStatus)
        indicator.frame = NSRect(origin: .zero, size: indicator.fittingSize)
        indicator.layoutSubtreeIfNeeded()

        XCTAssertEqual(indicator.titleLabel.stringValue, L10n.featurePermissionStatus)
        XCTAssertEqual(indicator.titleLabel.textColor, SettingsPalette.secondaryText)
        XCTAssertGreaterThan(indicator.dotView.frame.minX, indicator.titleLabel.frame.maxX)
        XCTAssertEqual(indicator.stateLabel.stringValue, L10n.permissionUnavailable)
        XCTAssertEqual(indicator.stateLabel.textColor, PermissionStatusIndicator.unavailableColor)

        indicator.configure(isAvailable: true)

        XCTAssertEqual(indicator.stateLabel.stringValue, L10n.permissionAvailable)
        XCTAssertEqual(indicator.stateLabel.textColor, PermissionStatusIndicator.availableColor)
    }

    func testPermissionHelpButtonDispatchesUnifiedGuideRequest() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        var requestCount = 0
        settingsView.onPermissionHelpRequest = { requestCount += 1 }

        let helpButton = try XCTUnwrap(settingsView.descendants(of: NSButton.self).first {
            $0.accessibilityLabel() == L10n.featurePermissionHelpTooltip
        })

        helpButton.performClick(nil)
        XCTAssertEqual(requestCount, 1)
    }

    func testPermissionHelpAlertCombinesBothPermissionStatusesAndActions() {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        let alert = settingsView.makePermissionHelpAlert(
            availability: PermissionFeatureAvailability.make(
                accessibilityGranted: true,
                screenRecordingGranted: false
            )
        )

        XCTAssertEqual(alert.messageText, L10n.featurePermissionHelpTitle)
        XCTAssertEqual(
            alert.informativeText,
            L10n.featurePermissionHelpBody(
                accessibilityStatus: L10n.permissionAvailable,
                screenRecordingStatus: L10n.permissionUnavailable
            )
        )
        XCTAssertEqual(
            alert.buttons.map(\.title),
            [
                L10n.permissionHelpOpenAccessibility,
                L10n.permissionHelpOpenScreenRecording,
                L10n.permissionHelpDone,
            ]
        )
        XCTAssertEqual(alert.buttons[0].keyEquivalent, "")
        XCTAssertEqual(alert.buttons[1].keyEquivalent, "")
        XCTAssertEqual(alert.buttons.last?.keyEquivalent, "\r")
        XCTAssertEqual(alert.buttons.last?.keyEquivalentModifierMask, [])
        XCTAssertTrue(alert.window.defaultButtonCell === alert.buttons.last?.cell)
        XCTAssertNotEqual(alert.buttons[0].bezelColor, NSColor.controlAccentColor)
        XCTAssertNotEqual(alert.buttons[1].bezelColor, NSColor.controlAccentColor)
        XCTAssertEqual(alert.buttons[2].bezelColor, NSColor.controlAccentColor)
    }

    func testPermissionHelpAlertDismissesForBareEscapeOnly() {
        XCTAssertTrue(
            PermissionAlertDismissalPolicy.shouldDismiss(
                keyCode: UInt16(kVK_Escape),
                modifiers: []
            )
        )
        XCTAssertFalse(
            PermissionAlertDismissalPolicy.shouldDismiss(
                keyCode: UInt16(kVK_Escape),
                modifiers: [.command]
            )
        )
        XCTAssertFalse(
            PermissionAlertDismissalPolicy.shouldDismiss(
                keyCode: UInt16(kVK_Return),
                modifiers: []
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
