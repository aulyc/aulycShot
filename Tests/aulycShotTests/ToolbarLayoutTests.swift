import AppKit
import XCTest
@testable import aulycShot

@MainActor
final class ToolbarLayoutTests: XCTestCase {
    nonisolated override func tearDown() {
        MainActor.assumeIsolated {
            ToolbarTooltipHoverGate.reset()
        }
        super.tearDown()
    }

    func testMosaicUsesPixelatedTileSymbol() {
        XCTAssertEqual(ToolbarItemID.mosaic.symbolName, "squareshape.split.3x3")
    }

    func testRectangleToolUsesSquareSymbol() {
        XCTAssertEqual(ToolbarItemID.rectangle.symbolName, "square")
        XCTAssertEqual(ToolbarItemID.rectangle.editTool, .rectangle)
    }

    func testTextToolUsesLiteralTInsteadOfLocalizedFormatSymbol() {
        XCTAssertEqual(ToolbarItemID.text.toolbarLetterGlyph, "T")
        XCTAssertNotEqual(ToolbarItemID.text.symbolName, "textformat")
        XCTAssertNotNil(ToolbarItemID.text.toolbarIconImage(pointSize: 14))
        XCTAssertNil(ToolbarItemID.rectangle.toolbarLetterGlyph)
    }

    func testRemovedItemsAreDroppedFromPersistedLayout() {
        let layout = ToolbarLayout(dictionary: [
            "primary": ["rectangle", "moveSelection", "ocr", "beautify", "colorPicker", "emoji", "ellipse"],
            "side": ["save"],
            "hidden": [],
        ]).normalized()

        let rawValues = layout.dictionary.values.flatMap { $0 }
        XCTAssertFalse(rawValues.contains("moveSelection"))
        XCTAssertFalse(rawValues.contains("ocr"))
        XCTAssertFalse(rawValues.contains("beautify"))
        XCTAssertFalse(rawValues.contains("colorPicker"))
        XCTAssertFalse(rawValues.contains("emoji"))
        XCTAssertTrue(rawValues.contains("magnifier"))
        XCTAssertEqual(Set(rawValues), Set(ToolbarItemID.allCases.map(\.rawValue)))
    }

    func testSaveRemainsInDefaultToolbarWithoutKeyboardShortcut() {
        XCTAssertTrue(ToolbarLayout.default.side.contains(.save))
        XCTAssertNil(ToolbarItemID.save.editorShortcutDisplay)
    }

    func testRuntimeToolbarButtonsExposeStableAccessibilityNames() throws {
        let toolbar = ToolbarView(items: [.scrollCapture, .record], orientation: .vertical)
        let buttons = toolbar.subviews.compactMap { $0 as? ToolButton }

        XCTAssertEqual(buttons.count, 2)
        XCTAssertEqual(buttons[0].identifier?.rawValue, "editor-toolbar-scrollCapture")
        XCTAssertEqual(buttons[0].accessibilityLabel(), ToolbarItemID.scrollCapture.tooltip)
        XCTAssertEqual(buttons[1].identifier?.rawValue, "editor-toolbar-record")
        XCTAssertEqual(buttons[1].accessibilityLabel(), ToolbarItemID.record.tooltip)
    }

    func testToolbarLayoutPreviewUsesFixedHeight() {
        let preview = ToolbarLayoutPreviewView()

        XCTAssertEqual(preview.preferredHeight, 450, accuracy: 0.01)
    }

    func testToolbarPreviewMovesSelectionAndPrimaryToolbarUpWithCaptureChrome() throws {
        let preview = ToolbarLayoutPreviewView()
        preview.frame = NSRect(x: 0, y: 0, width: 760, height: preview.preferredHeight)
        preview.layoutSubtreeIfNeeded()

        let selection = preview.selectionRect(in: preview.bounds)
        let primaryToolbar = try XCTUnwrap(preview.primaryGrid.enclosingScrollView)

        XCTAssertEqual(selection.minY, 94, accuracy: 0.01)
        XCTAssertEqual(selection.maxY, 418, accuracy: 0.01)
        XCTAssertEqual(
            selection.maxY,
            preview.bounds.maxY
                - ToolbarLayoutPreviewView.desktopMenuBarHeight
                - ToolbarLayoutPreviewView.selectionMenuBarGap,
            accuracy: 0.01
        )
        XCTAssertGreaterThan(selection.midY, preview.bounds.midY)
        XCTAssertEqual(primaryToolbar.frame.minY, 48, accuracy: 0.01)
        XCTAssertEqual(CaptureSelectionChrome.borderWidth, 2, accuracy: 0.01)
        XCTAssertEqual(CaptureSelectionChrome.dashPattern, [6, 4])
        XCTAssertEqual(CaptureSelectionChrome.handleSize, 8, accuracy: 0.01)
    }

    func testMainAndSidePreviewIconsUseLargerPointSize() {
        XCTAssertEqual(ToolbarItemTile.previewIconPointSize, 15, accuracy: 0.01)
    }

    func testToolbarSettingsPaneUsesOnDemandHiddenToolsGrid() throws {
        let pane = ToolbarSettingsPane()
        pane.frame = NSRect(x: 0, y: 0, width: 760, height: 900)
        pane.layoutSubtreeIfNeeded()

        let preview = try XCTUnwrap(
            pane.descendants(of: ToolbarLayoutPreviewView.self).first
        )
        let grids = pane.descendants(of: ToolbarSlotGridView.self)
        let hiddenToggle = try XCTUnwrap(
            pane.descendants(of: NSButton.self).first {
                $0.identifier?.rawValue == "toolbar-hidden-tools-toggle"
            }
        )

        XCTAssertEqual(grids.count, 2)
        XCTAssertEqual(preview.primaryGrid.layoutMode, .horizontalPreview)
        XCTAssertEqual(preview.sideGrid.layoutMode, .verticalPreview)
        XCTAssertEqual(pane.hiddenGrid.layoutMode, .grid)
        XCTAssertEqual(pane.hiddenGrid.maximumItemCount, 9)
        XCTAssertTrue(preview.primaryGrid.isDescendant(of: preview))
        XCTAssertTrue(preview.sideGrid.isDescendant(of: preview))
        XCTAssertTrue(hiddenToggle.isDescendant(of: preview))
        XCTAssertNil(pane.hiddenGrid.superview)
        XCTAssertNil(
            pane.descendants(of: NSView.self).first {
                $0.identifier?.rawValue == "toolbar-hidden-tools-card"
            }
        )
        XCTAssertNil(
            pane.descendants(of: NSView.self).first {
                $0.identifier?.rawValue == "toolbar-layout-editor-card"
            }
        )

        let providedZones = preview.primaryGrid.gridProvider?() ?? []
        XCTAssertEqual(Set(providedZones.map(ObjectIdentifier.init)).count, 3)

        let visibleLabels = pane.descendants(of: NSTextField.self).map(\.stringValue)
        let paneButtons = pane.descendants(of: NSButton.self)
        XCTAssertFalse(visibleLabels.contains(L10n.toolbarSettingsPrimaryTitle))
        XCTAssertFalse(visibleLabels.contains(L10n.toolbarSettingsSideTitle))
        XCTAssertFalse(visibleLabels.contains(L10n.toolbarSettingsHiddenTitle))
        XCTAssertFalse(paneButtons.contains { $0.title == L10n.toolbarSettingsReset })
    }

    func testHiddenToolsPanelUsesThreeByThreeGridAndEscapeClosesIt() throws {
        let pane = ToolbarSettingsPane()
        pane.frame = NSRect(x: 0, y: 0, width: 760, height: 700)
        let window = NSWindow(
            contentRect: pane.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = pane
        pane.layoutSubtreeIfNeeded()

        pane.showHiddenToolsPanel()
        pane.hiddenGrid.frame = NSRect(x: 0, y: 0, width: 118, height: 118)
        pane.hiddenGrid.layoutSubtreeIfNeeded()

        XCTAssertTrue(pane.isHiddenToolsPanelVisible)
        XCTAssertEqual(pane.hiddenGrid.columns, 3)
        XCTAssertEqual(pane.hiddenGrid.preferredContentSize.height, 118, accuracy: 0.01)

        window.childWindows?.first?.cancelOperation(nil)
        XCTAssertFalse(pane.isHiddenToolsPanelVisible)
    }

    func testToolbarLayoutLimitsHiddenToolsToNineWithoutLosingItems() {
        let hidden = Array(ToolbarLayout.canonicalOrder.prefix(10))
        let remaining = Array(ToolbarLayout.canonicalOrder.dropFirst(10))
        let layout = ToolbarLayout(
            primary: remaining,
            side: [],
            hidden: hidden
        ).normalized()

        XCTAssertEqual(layout.hidden, Array(hidden.prefix(9)))
        XCTAssertTrue(layout.primary.contains(hidden[9]))
        XCTAssertEqual(
            Set(layout.primary + layout.side + layout.hidden),
            Set(ToolbarLayout.canonicalOrder)
        )
    }

    func testDragGhostUsesFloatingLayerAbovePopoverWithCursorSlightlyOverlappingBottomEdge() {
        let ghost = ToolbarItemTile(
            itemID: .save,
            layoutMode: .horizontalPreview,
            isDragPreview: true
        )
        ghost.frame = NSRect(
            origin: .zero,
            size: ToolbarDragGhostPresentation.size(
                for: NSSize(width: 24, height: 24)
            )
        )
        let overlay = ToolbarDragGhostOverlay(ghost: ghost)
        overlay.move(to: NSPoint(x: 180, y: 90))

        XCTAssertEqual(ghost.frame.width, 38, accuracy: 0.01)
        XCTAssertEqual(ghost.frame.height, 38, accuracy: 0.01)
        XCTAssertEqual(overlay.ghostFrameOnScreen.midX, 180, accuracy: 0.01)
        XCTAssertEqual(overlay.ghostFrameOnScreen.minY, 86, accuracy: 0.01)
        XCTAssertTrue(overlay.panel.ignoresMouseEvents)
        XCTAssertGreaterThan(
            overlay.panel.level.rawValue,
            NSWindow.Level.popUpMenu.rawValue
        )
    }

    func testToolbarResetUsesSharedDetailHeaderButton() throws {
        let originalLayout = Defaults.toolbarLayout
        defer { Defaults.toolbarLayout = originalLayout }
        Defaults.toolbarLayout = ToolbarLayout(
            primary: [],
            side: [],
            hidden: ToolbarLayout.canonicalOrder
        )

        let settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 920, height: 696))
        settingsView.layoutSubtreeIfNeeded()

        let resetButton = try XCTUnwrap(
            settingsView.descendants(of: NSButton.self).first {
                $0.identifier?.rawValue == "settings-detail-reset"
            }
        )
        let toolbarTab = try XCTUnwrap(
            settingsView.descendants(of: TabButton.self).first { $0.tab == .toolbar }
        )
        let headerDivider = try XCTUnwrap(
            settingsView.descendants(of: NSView.self).first {
                $0.identifier?.rawValue == "settings-detail-header-divider"
            }
        )

        XCTAssertTrue(resetButton.isHidden)
        XCTAssertFalse(headerDivider.isHidden)
        toolbarTab.sendAction(toolbarTab.action, to: toolbarTab.target)
        settingsView.layoutSubtreeIfNeeded()
        XCTAssertFalse(resetButton.isHidden)
        XCTAssertTrue(headerDivider.isHidden)

        resetButton.performClick(nil)
        XCTAssertEqual(Defaults.toolbarLayout, .default)
    }

    func testSelectionBorderHitTestingClaimsOnlyTheEdgeBand() {
        let rect = NSRect(x: 100, y: 80, width: 300, height: 200)

        XCTAssertTrue(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.midX, y: rect.minY),
                rect: rect,
                hitSize: 7
            )
        )
        XCTAssertTrue(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.maxX + 4, y: rect.midY),
                rect: rect,
                hitSize: 7
            )
        )
        XCTAssertFalse(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.midX, y: rect.midY),
                rect: rect,
                hitSize: 7
            )
        )
        XCTAssertFalse(
            SelectionChromeOverlay.isBorderHit(
                point: NSPoint(x: rect.maxX + 8, y: rect.midY),
                rect: rect,
                hitSize: 7
            )
        )
    }

    func testScrollingSuppressesHoverWhilePointerRemainsStationary() {
        let pointer = NSPoint(x: 240, y: 180)

        ToolbarTooltipHoverGate.suppressForScroll(at: pointer)

        XCTAssertFalse(ToolbarTooltipHoverGate.permitsHover(at: pointer))
        XCTAssertFalse(
            ToolbarTooltipHoverGate.resumeAfterMouseMove(
                at: NSPoint(x: pointer.x + 0.5, y: pointer.y)
            )
        )
    }

    func testHoverResumesAfterPointerActuallyMoves() {
        let pointer = NSPoint(x: 240, y: 180)
        ToolbarTooltipHoverGate.suppressForScroll(at: pointer)

        XCTAssertTrue(
            ToolbarTooltipHoverGate.resumeAfterMouseMove(
                at: NSPoint(x: pointer.x + 2, y: pointer.y)
            )
        )
        XCTAssertTrue(ToolbarTooltipHoverGate.permitsHover(at: pointer))
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
