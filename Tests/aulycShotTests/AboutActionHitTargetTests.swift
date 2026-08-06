import AppKit
import XCTest
@testable import aulycShot

@MainActor
final class AboutActionHitTargetTests: XCTestCase {
    func testAboutPaneUsesTextLinksInsideScrollAndFixedCopyrightFooter() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.showAboutTab()
        settingsView.layoutSubtreeIfNeeded()

        let aboutContent = try XCTUnwrap(settingsView.descendants(of: NSStackView.self).first {
            $0.identifier?.rawValue == "about-content"
        })
        let detailScroll = try XCTUnwrap(settingsView.descendants(of: NSScrollView.self).first {
            $0.identifier?.rawValue == "settings-detail-scroll"
        })
        let footer = try XCTUnwrap(settingsView.descendants(of: NSView.self).first {
            $0.identifier?.rawValue == "about-footer"
        })
        let copyright = try XCTUnwrap(settingsView.descendants(of: NSTextField.self).first {
            $0.identifier?.rawValue == "about-copyright"
        })

        XCTAssertTrue(aboutContent.enclosingScrollView === detailScroll)
        XCTAssertNil(footer.enclosingScrollView)
        XCTAssertFalse(footer.isHidden)
        XCTAssertEqual(copyright.stringValue, L10n.aboutCopyright)
        XCTAssertTrue(aboutContent.descendants(of: NSImageView.self).isEmpty)

        let aboutTitle = try XCTUnwrap(settingsView.descendants(of: NSTextField.self).first {
            $0.stringValue == L10n.aboutTitle
        })
        let settingsTitle = try XCTUnwrap(settingsView.descendants(of: NSTextField.self).first {
            $0.stringValue == L10n.settings
        })
        XCTAssertNil(aboutTitle.enclosingScrollView)
        XCTAssertTrue(aboutContent.descendants(of: NSTextField.self).allSatisfy {
            $0.stringValue != L10n.aboutTitle
        })
        let acknowledgementCopy = [
            L10n.aboutAcknowledgementFirst,
            L10n.aboutAcknowledgementSecond,
            L10n.aboutAcknowledgementThird,
            L10n.aboutAcknowledgementFourth,
            L10n.aboutAcknowledgementFifth,
            L10n.aboutAcknowledgementSixth,
        ]
        let aboutLabels = aboutContent.descendants(of: NSTextField.self).map(\.stringValue)
        XCTAssertTrue(acknowledgementCopy.allSatisfy(aboutLabels.contains))

        let capcapURL = try XCTUnwrap(URL(string: "https://github.com/realskyrin/capcap"))
        let capcapLabel = try XCTUnwrap(aboutContent.descendants(of: NSTextField.self).first {
            var containsCapcapLink = false
            $0.attributedStringValue.enumerateAttribute(
                .link,
                in: NSRange(location: 0, length: $0.attributedStringValue.length)
            ) { value, _, stop in
                if value as? URL == capcapURL {
                    containsCapcapLink = true
                    stop.pointee = true
                }
            }
            return containsCapcapLink
        })
        XCTAssertTrue(capcapLabel.isSelectable)

        let aboutTitleFrame = settingsView.convert(aboutTitle.bounds, from: aboutTitle)
        let settingsTitleFrame = settingsView.convert(settingsTitle.bounds, from: settingsTitle)
        XCTAssertEqual(aboutTitleFrame.maxY, settingsTitleFrame.maxY, accuracy: 0.5)

        let textLinks = aboutContent.descendants(of: HoverButton.self)
        XCTAssertGreaterThanOrEqual(textLinks.count, 8)
        XCTAssertTrue(textLinks.allSatisfy { $0.image == nil && $0.title.isEmpty })
        XCTAssertTrue(textLinks.contains { $0.accessibilityLabel() == L10n.aboutWebsiteURL })
        XCTAssertTrue(textLinks.contains { $0.accessibilityLabel() == L10n.aboutUpdateTitle })
        XCTAssertTrue(textLinks.allSatisfy { $0.bounds.width > 20 })
        XCTAssertTrue(textLinks.allSatisfy { $0.interactiveBounds.width > 20 })
        XCTAssertTrue(textLinks.allSatisfy { button in
            guard let superview = button.superview else { return false }
            let localTarget = NSPoint(
                x: button.interactiveBounds.midX,
                y: button.interactiveBounds.midY
            )
            let target = superview.convert(localTarget, from: button)
            return button.hitTest(target) === button
        })
        XCTAssertGreaterThan(aboutContent.fittingSize.height, detailScroll.contentView.bounds.height)
    }

    func testContentSizedButtonIgnoresBlankAreaOutsideItsContent() {
        let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 440, height: 28))
        let content = NSView(frame: NSRect(x: 112, y: 4, width: 160, height: 20))
        button.addSubview(content)
        button.interactiveContentView = content

        XCTAssertIdentical(button.hitTest(NSPoint(x: 150, y: 14)), button)
        XCTAssertNil(button.hitTest(NSPoint(x: 360, y: 14)))
        XCTAssertFalse(button.interactiveBounds.contains(NSPoint(x: 360, y: 14)))
    }

    func testOtherHoverButtonsKeepTheirFullBoundsInteractive() {
        let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 220, height: 44))

        XCTAssertEqual(button.interactiveBounds, button.bounds)
        XCTAssertIdentical(button.hitTest(NSPoint(x: 210, y: 22)), button)
    }

    func testHoverButtonTracksCursorUpdatesAcrossItsInteractiveBounds() {
        let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 440, height: 28))
        let content = NSView(frame: NSRect(x: 112, y: 4, width: 160, height: 20))
        button.addSubview(content)
        button.interactiveContentView = content

        button.updateTrackingAreas()

        XCTAssertTrue(button.trackingAreas.contains { area in
            area.options.contains(.cursorUpdate)
        })
    }

    func testSettingsViewHitTestingReachesVisibleAboutLink() throws {
        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.showAboutTab()
        settingsView.layoutSubtreeIfNeeded()

        let websiteLink = try XCTUnwrap(settingsView.descendants(of: HoverButton.self).first {
            $0.accessibilityLabel() == L10n.aboutWebsiteURL
        })
        let localPoint = NSPoint(
            x: websiteLink.interactiveBounds.midX,
            y: websiteLink.interactiveBounds.midY
        )
        let settingsPoint = settingsView.convert(localPoint, from: websiteLink)

        let hitView = settingsView.hitTest(settingsPoint)
        XCTAssertTrue(
            hitView === websiteLink,
            "Expected website link, hit \(String(describing: hitView))"
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
