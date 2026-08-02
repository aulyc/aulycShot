import AppKit
import XCTest
@testable import aulycShot

@MainActor
final class ImageMergeLayoutPresetTests: XCTestCase {
    private let preferenceKeys = [
        "imageMergeSpacing",
        "imageMergeMargin",
        "imageMergeCornerRadius",
        "imageMergeBackgroundIsSolid",
        "imageMergeBackgroundColorHex",
    ]

    func testLayoutPresetsExposeOnlyTheApprovedFixedValues() {
        XCTAssertEqual(ImageMergeSpacingPreset.allCases.map(\.value), [0, 8, 16, 24])
        XCTAssertEqual(ImageMergeMarginPreset.allCases.map(\.value), [0, 12, 24, 40])
        XCTAssertEqual(ImageMergeCornerPreset.allCases.map(\.value), [0, 12])
    }

    func testLegacyValuesMapToTheNearestPreset() {
        XCTAssertEqual(ImageMergeSpacingPreset.nearest(to: 9), .small)
        XCTAssertEqual(ImageMergeMarginPreset.nearest(to: 14), .small)
        XCTAssertEqual(ImageMergeCornerPreset.nearest(to: 10), .rounded)
        XCTAssertEqual(ImageMergeSpacingPreset.nearest(to: -20), .none)
        XCTAssertEqual(ImageMergeMarginPreset.nearest(to: 400), .large)
    }

    func testTiesChooseTheMoreVisiblePreset() {
        XCTAssertEqual(ImageMergeSpacingPreset.nearest(to: 12), .medium)
        XCTAssertEqual(ImageMergeCornerPreset.nearest(to: 6), .rounded)
    }

    func testDefaultsMigrateLegacyNumbersAndDocumentUsesNormalizedValues() {
        withRestoredPreferences {
            let defaults = UserDefaults.standard
            defaults.set(9.0, forKey: "imageMergeSpacing")
            defaults.set(14.0, forKey: "imageMergeMargin")
            defaults.set(10.0, forKey: "imageMergeCornerRadius")

            let document = ImageMergeDocument()

            XCTAssertEqual(Defaults.imageMergeSpacingPreset, .small)
            XCTAssertEqual(Defaults.imageMergeMarginPreset, .small)
            XCTAssertEqual(Defaults.imageMergeCornerPreset, .rounded)
            XCTAssertEqual(document.spacing, 8)
            XCTAssertEqual(document.margin, 12)
            XCTAssertEqual(document.cornerRadius, 12)
            XCTAssertEqual(defaults.double(forKey: "imageMergeSpacing"), 8)
            XCTAssertEqual(defaults.double(forKey: "imageMergeMargin"), 12)
            XCTAssertEqual(defaults.double(forKey: "imageMergeCornerRadius"), 12)
        }
    }

    func testMergeWindowUsesParametersPopoverWithFixedPresetDropdowns() throws {
        try withRestoredPreferences {
            Defaults.imageMergeBackgroundIsSolid = false
            Defaults.imageMergeBackgroundColorHex = "#34C759"
            let controller = ImageMergeWindowController(
                document: ImageMergeDocument(),
                onContinueEditing: { _ in },
                onClose: {}
            )
            let contentView = try XCTUnwrap(controller.window?.contentView)
            contentView.layoutSubtreeIfNeeded()
            let popoverContentView = try XCTUnwrap(
                controller.parametersPopover.contentViewController?.view
            )
            popoverContentView.layoutSubtreeIfNeeded()

            let windowIdentifiers = Set(
                contentView.descendants(of: NSView.self).compactMap {
                    $0.identifier?.rawValue
                }
            )
            XCTAssertFalse(windowIdentifiers.contains("image-merge-toolbar"))
            XCTAssertFalse(windowIdentifiers.contains("image-merge-toolbar-fields"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-image-list-card"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-split-view"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-image-list-header"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-image-list-label"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-image-source-buttons"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-add-files"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-add-from-clipboard"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-output-controls"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-output-buttons"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-parameters"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-continue-editing"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-copy"))
            XCTAssertTrue(windowIdentifiers.contains("image-merge-save"))
            XCTAssertTrue(
                contentView.descendants(of: ImageMergeDropdownButton.self).isEmpty
            )

            let popoverIdentifiers = Set(
                popoverContentView.descendants(of: NSView.self).compactMap {
                    $0.identifier?.rawValue
                }
            )
            XCTAssertEqual(
                popoverContentView.identifier?.rawValue,
                "image-merge-parameters-popover-content"
            )
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-parameters-rows"))
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-arrangement-label"))
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-spacing-label"))
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-margin-label"))
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-corner-label"))
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-background-label"))
            XCTAssertTrue(
                popoverIdentifiers.contains("image-merge-arrangement-dropdown")
            )
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-spacing-dropdown"))
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-margin-dropdown"))
            XCTAssertTrue(popoverIdentifiers.contains("image-merge-corner-dropdown"))
            XCTAssertTrue(
                popoverIdentifiers.contains("image-merge-background-dropdown")
            )
            XCTAssertTrue(
                popoverIdentifiers.contains("image-merge-background-color-edit")
            )
            XCTAssertTrue(
                popoverIdentifiers.contains("image-merge-background-color-slot")
            )
            XCTAssertEqual(controller.parametersPopover.behavior, .transient)

            for rootView in [contentView, popoverContentView] {
                XCTAssertTrue(rootView.descendants(of: NSSlider.self).isEmpty)
                XCTAssertTrue(rootView.descendants(of: NSSegmentedControl.self).isEmpty)
                XCTAssertTrue(rootView.descendants(of: NSPopUpButton.self).isEmpty)
                XCTAssertTrue(rootView.descendants(of: NSColorWell.self).isEmpty)
            }

            let parameterDropdowns = popoverContentView
                .descendants(of: ImageMergeDropdownButton.self)
                .filter {
                    $0.identifier?.rawValue.hasPrefix("image-merge-") == true
                        && $0.identifier?.rawValue.hasSuffix("-dropdown") == true
                }
            XCTAssertEqual(parameterDropdowns.count, 5)
            XCTAssertTrue(parameterDropdowns.allSatisfy {
                $0.optionTitles.allSatisfy {
                    $0.rangeOfCharacter(from: .decimalDigits) == nil
                }
            })
            XCTAssertTrue(parameterDropdowns.allSatisfy {
                let buttonFrame = NSRect(x: 40, y: 300, width: 120, height: 30)
                let panelFrame = $0.dropdownPanelFrame(
                    buttonScreenFrame: buttonFrame,
                    optionCount: $0.optionTitles.count
                )
                return $0.usesDownwardChevron
                    && !$0.opensUpward
                    && $0.toolTip == nil
                    && panelFrame.width == buttonFrame.width
                    && panelFrame.maxY == buttonFrame.minY - 6
                    && panelFrame.minY < buttonFrame.minY
            })

            let arrangement = try XCTUnwrap(parameterDropdowns.first {
                $0.identifier?.rawValue == "image-merge-arrangement-dropdown"
            })
            let spacing = try XCTUnwrap(parameterDropdowns.first {
                $0.identifier?.rawValue == "image-merge-spacing-dropdown"
            })
            let margin = try XCTUnwrap(parameterDropdowns.first {
                $0.identifier?.rawValue == "image-merge-margin-dropdown"
            })
            let corner = try XCTUnwrap(parameterDropdowns.first {
                $0.identifier?.rawValue == "image-merge-corner-dropdown"
            })
            let background = try XCTUnwrap(parameterDropdowns.first {
                $0.identifier?.rawValue == "image-merge-background-dropdown"
            })
            XCTAssertEqual(arrangement.optionTitles, ImageMergeTemplate.allCases.map(\.title))
            XCTAssertEqual(spacing.optionTitles, ImageMergeSpacingPreset.allCases.map(\.title))
            XCTAssertEqual(margin.optionTitles, ImageMergeMarginPreset.allCases.map(\.title))
            XCTAssertEqual(corner.optionTitles, ImageMergeCornerPreset.allCases.map(\.title))
            XCTAssertEqual(
                background.optionTitles,
                [L10n.imageMergeTransparent, L10n.imageMergeSolid]
            )

            let selectorFrame = NSRect(x: 40, y: 300, width: 120, height: 30)
            let dropdownPanel = arrangement.makeDropdownPanel(
                buttonScreenFrame: selectorFrame
            )
            let panelContentView = try XCTUnwrap(dropdownPanel.contentView)
            XCTAssertEqual(dropdownPanel.frame.width, selectorFrame.width, accuracy: 0.5)
            XCTAssertEqual(
                panelContentView.frame.width,
                selectorFrame.width,
                accuracy: 0.5
            )
            let panelBackground = try XCTUnwrap(
                panelContentView.layer?.backgroundColor
            )
            XCTAssertEqual(panelBackground.alpha, 1, accuracy: 0.01)
            let optionLabels = panelContentView.descendants(of: NSTextField.self)
            XCTAssertFalse(optionLabels.isEmpty)
            XCTAssertTrue(optionLabels.allSatisfy {
                $0.font?.pointSize == arrangement.selectorFont?.pointSize
                    && $0.font?.fontDescriptor.symbolicTraits
                        == arrangement.selectorFont?.fontDescriptor.symbolicTraits
            })
            dropdownPanel.close()

            let parameterRows = try XCTUnwrap(
                popoverContentView.descendants(of: NSStackView.self).first {
                    $0.identifier?.rawValue == "image-merge-parameters-rows"
                }
            )
            XCTAssertEqual(parameterRows.orientation, .vertical)
            XCTAssertEqual(parameterRows.arrangedSubviews.count, 5)
            XCTAssertTrue(parameterDropdowns.allSatisfy {
                abs($0.frame.width - 106) < 0.5
            })
            for case let row as NSStackView in parameterRows.arrangedSubviews {
                XCTAssertEqual(row.orientation, .horizontal)
                XCTAssertEqual(row.arrangedSubviews.count, 2)
                let label = try XCTUnwrap(
                    row.descendants(of: NSTextField.self).first
                )
                let dropdown = try XCTUnwrap(
                    row.arrangedSubviews[1] as? ImageMergeDropdownButton
                )
                let labelFrame = label.convert(label.bounds, to: row)
                let dropdownFrame = dropdown.convert(dropdown.bounds, to: row)
                XCTAssertEqual(labelFrame.midY, dropdownFrame.midY, accuracy: 1)
                let rowFrame = row.convert(row.bounds, to: popoverContentView)
                XCTAssertEqual(
                    rowFrame.maxX,
                    popoverContentView.bounds.maxX - 16,
                    accuracy: 1
                )
            }

            let colorEditButton = try XCTUnwrap(
                popoverContentView
                    .descendants(of: ImageMergeColorPaletteButton.self)
                    .first {
                        $0.identifier?.rawValue
                            == "image-merge-background-color-edit"
                    }
            )
            let colorButtonSlot = try XCTUnwrap(
                popoverContentView.descendants(of: NSView.self).first {
                    $0.identifier?.rawValue == "image-merge-background-color-slot"
                }
            )
            XCTAssertEqual(colorButtonSlot.frame.width, 22, accuracy: 0.5)
            XCTAssertEqual(colorButtonSlot.frame.height, 22, accuracy: 0.5)
            XCTAssertEqual(colorEditButton.frame.width, 22, accuracy: 0.5)
            XCTAssertEqual(colorEditButton.frame.height, 22, accuracy: 0.5)
            XCTAssertEqual(
                colorEditButton.frame.width,
                colorEditButton.frame.height,
                accuracy: 0.5
            )
            XCTAssertEqual(
                colorEditButton.alignmentRect(
                    forFrame: colorEditButton.frame
                ).width,
                colorEditButton.alignmentRect(
                    forFrame: colorEditButton.frame
                ).height,
                accuracy: 0.5
            )
            XCTAssertFalse(colorEditButton.isBordered)
            XCTAssertEqual(colorEditButton.imagePosition, .imageOnly)
            XCTAssertNotNil(colorEditButton.image)
            XCTAssertNil(colorEditButton.toolTip)
            XCTAssertFalse(colorEditButton.isEnabled)
            XCTAssertEqual(
                try XCTUnwrap(colorEditButton.layer?.backgroundColor).alpha,
                0,
                accuracy: 0.01
            )
            XCTAssertEqual(
                colorEditButton.contentTintColor,
                .disabledControlTextColor
            )
            XCTAssertEqual(
                ImageMergeColorPaletteButton.editIconSymbolName,
                "square.and.pencil"
            )
            XCTAssertEqual(
                ImageMergeColorPaletteButton.editIconPointSize,
                10
            )
            XCTAssertEqual(ImageMergeColorPaletteButton.paletteColumns, 6)
            XCTAssertEqual(ImageMergeColorPaletteButton.paletteColors.count, 36)
            XCTAssertEqual(
                ImageMergeColorPaletteButton.paletteHexColors,
                [
                    "#7A1711", "#7A4400", "#7A6000", "#135E26", "#005E59", "#00377A",
                    "#BE2921", "#BE6D00", "#BE9700", "#249340", "#00938C", "#0059BE",
                    "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#007AFF",
                    "#FF8373", "#FFB771", "#FFDD7A", "#81D98D", "#7AD9D1", "#64A6FF",
                    "#FFC4B9", "#FFDCBB", "#FFEFC1", "#C3EDC6", "#C1ECE8", "#B2D4FF",
                    "#000000", "#48484A", "#8E8E93", "#C7C7CC", "#E5E5EA", "#FFFFFF",
                ]
            )

            let colorButtonFrame = NSRect(
                x: 100,
                y: 200,
                width: 22,
                height: 22
            )
            let paletteFrame = colorEditButton.palettePanelFrame(
                buttonScreenFrame: colorButtonFrame
            )
            XCTAssertEqual(
                paletteFrame.minY,
                colorButtonFrame.maxY + 8,
                accuracy: 0.5
            )
            let palettePanel = colorEditButton.makePalettePanel(
                buttonScreenFrame: colorButtonFrame
            )
            let paletteContent = try XCTUnwrap(palettePanel.contentView)
            paletteContent.layoutSubtreeIfNeeded()
            let swatches = paletteContent.descendants(
                of: ImageMergeColorSwatchButton.self
            )
            XCTAssertEqual(swatches.count, 36)
            XCTAssertTrue(swatches.allSatisfy { $0.title.isEmpty })
            XCTAssertTrue(swatches.allSatisfy {
                abs($0.frame.width - 22) < 0.5
                    && abs($0.frame.height - 22) < 0.5
                    && abs($0.frame.width - $0.frame.height) < 0.5
            })
            let selectedSwatch = try XCTUnwrap(
                swatches.first(where: \.isCurrentSelection)
            )
            selectedSwatch.layoutSubtreeIfNeeded()
            XCTAssertEqual(selectedSwatch.layer?.borderWidth, 1)
            XCTAssertTrue(selectedSwatch.layer?.sublayers?.isEmpty ?? true)
            XCTAssertNotNil(selectedSwatch.image)
            XCTAssertEqual(selectedSwatch.contentTintColor, .black)
            XCTAssertEqual(
                ImageMergeColorSwatchButton.selectionSymbolName,
                "checkmark"
            )
            XCTAssertTrue(
                paletteContent.descendants(of: NSTextField.self).isEmpty
            )
            palettePanel.close()

            let colorButtonFrameInPopover = colorButtonSlot.convert(
                colorButtonSlot.bounds,
                to: popoverContentView
            )
            let backgroundDropdownFrame = background.convert(
                background.bounds,
                to: popoverContentView
            )
            XCTAssertLessThan(
                colorButtonFrameInPopover.maxX,
                backgroundDropdownFrame.minX
            )
            XCTAssertEqual(
                backgroundDropdownFrame.minX - colorButtonFrameInPopover.maxX,
                10,
                accuracy: 1
            )

            let imageListHeader = try XCTUnwrap(
                contentView.descendants(of: NSStackView.self).first {
                    $0.identifier?.rawValue == "image-merge-image-list-header"
                }
            )
            let imageListLabel = try XCTUnwrap(
                contentView.descendants(of: NSTextField.self).first {
                    $0.identifier?.rawValue == "image-merge-image-list-label"
                }
            )
            let addFilesButton = try XCTUnwrap(
                contentView.descendants(of: NSButton.self).first {
                    $0.identifier?.rawValue == "image-merge-add-files"
                }
            )
            let addClipboardButton = try XCTUnwrap(
                contentView.descendants(of: NSButton.self).first {
                    $0.identifier?.rawValue == "image-merge-add-from-clipboard"
                }
            )
            XCTAssertEqual(imageListHeader.orientation, .horizontal)
            XCTAssertTrue(imageListLabel.isDescendant(of: imageListHeader))
            XCTAssertTrue(addFilesButton.isDescendant(of: imageListHeader))
            XCTAssertTrue(addClipboardButton.isDescendant(of: imageListHeader))
            let imageListLabelAlignmentMidY = alignmentMidY(
                of: imageListLabel,
                in: imageListHeader
            )
            XCTAssertEqual(
                imageListLabelAlignmentMidY,
                alignmentMidY(of: addFilesButton, in: imageListHeader),
                accuracy: 1
            )
            XCTAssertEqual(
                imageListLabelAlignmentMidY,
                alignmentMidY(of: addClipboardButton, in: imageListHeader),
                accuracy: 1
            )

            let outputButtons = try XCTUnwrap(
                contentView.descendants(of: NSStackView.self).first {
                    $0.identifier?.rawValue == "image-merge-output-buttons"
                }
            )
            let splitView = try XCTUnwrap(
                contentView.descendants(of: ImageMergeSplitView.self).first {
                    $0.identifier?.rawValue == "image-merge-split-view"
                }
            )
            XCTAssertEqual(splitView.dividerThickness, 0)
            XCTAssertEqual(outputButtons.orientation, .horizontal)
            XCTAssertEqual(outputButtons.distribution, .fillEqually)
            XCTAssertEqual(outputButtons.arrangedSubviews.count, 4)
            XCTAssertEqual(
                outputButtons.arrangedSubviews.first?.identifier?.rawValue,
                "image-merge-parameters"
            )
            let outputButtonWidths = outputButtons.arrangedSubviews.map(\.frame.width)
            let minimumOutputButtonWidth = try XCTUnwrap(outputButtonWidths.min())
            let maximumOutputButtonWidth = try XCTUnwrap(outputButtonWidths.max())
            XCTAssertLessThanOrEqual(
                maximumOutputButtonWidth - minimumOutputButtonWidth,
                1
            )
            let compactOutputButtons = outputButtons.arrangedSubviews.compactMap {
                $0 as? NSButton
            }
            XCTAssertEqual(compactOutputButtons.count, 4)
            XCTAssertTrue(compactOutputButtons.allSatisfy {
                $0.controlSize == .large
            })
            XCTAssertEqual(ImageMergeWindowController.outputButtonHeight, 33)
            XCTAssertTrue(compactOutputButtons.allSatisfy {
                abs(
                    $0.alignmentRect(forFrame: $0.frame).height
                        - ImageMergeWindowController.outputButtonHeight
                ) < 0.5
            })
            let smallReferenceButton = NSButton(
                title: L10n.imageMergeParameters,
                target: nil,
                action: nil
            )
            smallReferenceButton.bezelStyle = .rounded
            smallReferenceButton.controlSize = .small
            smallReferenceButton.frame = NSRect(
                origin: .zero,
                size: compactOutputButtons[0].bounds.size
            )
            let smallDrawingHeight = try XCTUnwrap(
                smallReferenceButton.cell?.drawingRect(
                    forBounds: smallReferenceButton.bounds
                ).height
            )
            XCTAssertTrue(compactOutputButtons.allSatisfy {
                guard let drawingHeight = $0.cell?.drawingRect(
                    forBounds: $0.bounds
                ).height else {
                    return false
                }
                return drawingHeight >= smallDrawingHeight + 6
            })
            let parametersButton = try XCTUnwrap(compactOutputButtons.first)
            XCTAssertEqual(parametersButton.title, L10n.imageMergeParameters)
            XCTAssertTrue(parametersButton.isEnabled)
            XCTAssertEqual(
                controller.parametersPopoverPreferredEdge,
                parametersButton.isFlipped ? .minY : .maxY
            )
        }
    }

    func testColorPaletteOnlyEmitsItsFixedColors() throws {
        let button = ImageMergeColorPaletteButton()
        button.configure(
            color: NSColor(
                srgbRed: 0.31,
                green: 0.42,
                blue: 0.53,
                alpha: 1
            ),
            accessibilityLabel: L10n.imageMergeBackground
        )

        var selectedColor: NSColor?
        button.onSelection = { selectedColor = $0 }
        button.selectPaletteColor(at: 3)

        XCTAssertEqual(
            ImageMergeDocument.hexString(from: button.selectedColor),
            ImageMergeDocument.hexString(
                from: ImageMergeColorPaletteButton.paletteColors[3]
            )
        )
        XCTAssertEqual(
            ImageMergeDocument.hexString(from: selectedColor ?? .clear),
            ImageMergeDocument.hexString(
                from: ImageMergeColorPaletteButton.paletteColors[3]
            )
        )
        let enabledFill = try XCTUnwrap(button.layer?.backgroundColor)
        let enabledFillColor = try XCTUnwrap(NSColor(cgColor: enabledFill))
        XCTAssertEqual(
            ImageMergeDocument.hexString(from: enabledFillColor),
            ImageMergeDocument.hexString(from: button.selectedColor)
        )
        XCTAssertEqual(button.contentTintColor, .white)

        button.isEnabled = false
        let disabledFill = try XCTUnwrap(button.layer?.backgroundColor)
        XCTAssertEqual(disabledFill.alpha, 0, accuracy: 0.01)
        XCTAssertEqual(button.contentTintColor, .disabledControlTextColor)
        XCTAssertNotNil(button.image)

        button.isEnabled = true
        let restoredFill = try XCTUnwrap(button.layer?.backgroundColor)
        let restoredFillColor = try XCTUnwrap(NSColor(cgColor: restoredFill))
        XCTAssertEqual(
            ImageMergeDocument.hexString(from: restoredFillColor),
            ImageMergeDocument.hexString(from: button.selectedColor)
        )
        XCTAssertNil(button.toolTip)
    }

    private func withRestoredPreferences(_ body: () throws -> Void) rethrows {
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
        try body()
    }

    private func alignmentMidY(of view: NSView, in coordinateView: NSView) -> CGFloat {
        let alignmentRect = view.alignmentRect(forFrame: view.frame)
        return view.superview?.convert(alignmentRect, to: coordinateView).midY
            ?? alignmentRect.midY
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
