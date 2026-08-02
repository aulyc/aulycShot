import AppKit
import UniformTypeIdentifiers

private final class ImageMergeWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let commandModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(commandModifiers)
        if modifiers == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class ImageMergeWindowController: NSWindowController, NSWindowDelegate, NSPopoverDelegate {
    static let outputButtonHeight: CGFloat = 33

    private let mergeDocument: ImageMergeDocument
    private let onContinueEditing: (NSImage) -> Void
    private let onClose: () -> Void

    private let canvasView = ImageMergeCanvasView(frame: .zero)
    private let thumbnailListView = ImageMergeThumbnailListView(frame: NSRect(x: 0, y: 0, width: 260, height: 120))
    private let arrangementDropdown = ImageMergeDropdownButton()
    private let spacingDropdown = ImageMergeDropdownButton()
    private let marginDropdown = ImageMergeDropdownButton()
    private let cornerDropdown = ImageMergeDropdownButton()
    private let backgroundDropdown = ImageMergeDropdownButton()
    private let backgroundColorButton = ImageMergeColorPaletteButton()
    private let parametersButton = NSButton(
        title: L10n.imageMergeParameters,
        target: nil,
        action: nil
    )
    private let copyButton = NSButton(title: L10n.imageMergeCopy, target: nil, action: nil)
    private let saveButton = NSButton(title: L10n.imageMergeSave, target: nil, action: nil)
    private let continueButton = NSButton(title: L10n.imageMergeContinueEditing, target: nil, action: nil)
    private(set) lazy var parametersPopover: NSPopover = {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let contentViewController = NSViewController()
        let contentView = buildParametersPopoverContent()
        contentViewController.view = contentView
        popover.contentViewController = contentViewController
        popover.contentSize = contentView.frame.size
        return popover
    }()
    var parametersPopoverPreferredEdge: NSRectEdge {
        parametersButton.isFlipped ? .minY : .maxY
    }

    init(
        document: ImageMergeDocument,
        onContinueEditing: @escaping (NSImage) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mergeDocument = document
        self.onContinueEditing = onContinueEditing
        self.onClose = onClose

        let window = ImageMergeWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.imageMergeWindowTitle
        window.minSize = NSSize(width: 1040, height: 560)
        window.center()

        super.init(window: window)
        window.delegate = self
        window.contentView = buildContentView()
        configureControls()
        refreshAll()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func appendImages(from urls: [URL]) {
        let result = ImageMergeDocument.loadItems(from: urls)
        mergeDocument.append(result.items)
        mergeDocument.removeInvalidSelectionIfNeeded()
        refreshAll()
        if result.failedCount > 0 {
            ToastWindow.show(message: L10n.imageMergeSomeImagesSkipped)
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    private func buildContentView() -> NSView {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let split = ImageMergeSplitView()
        split.identifier = NSUserInterfaceItemIdentifier("image-merge-split-view")
        split.isVertical = true
        split.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(split)
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            split.topAnchor.constraint(equalTo: root.topAnchor),
            split.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        split.addArrangedSubview(buildWorkspaceView())

        let controls = buildControlsView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        split.addArrangedSubview(controls)
        controls.widthAnchor.constraint(greaterThanOrEqualToConstant: 336).isActive = true
        controls.widthAnchor.constraint(lessThanOrEqualToConstant: 380).isActive = true

        return root
    }

    private func buildWorkspaceView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.document = mergeDocument
        canvasView.onImportURLs = { [weak self] urls in
            self?.appendImages(from: urls)
        }
        canvasView.onDocumentChanged = { [weak self] in
            self?.refreshAll()
        }
        container.addSubview(canvasView)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: container.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func buildParametersPopoverContent() -> NSView {
        let labelColumnWidth = parameterLabelColumnWidth()
        let contentWidth = labelColumnWidth + 148
        let content = NSView(
            frame: NSRect(x: 0, y: 0, width: contentWidth, height: 222)
        )
        content.identifier = NSUserInterfaceItemIdentifier(
            "image-merge-parameters-popover-content"
        )

        let rows = [
            parameterRow(
                title: L10n.imageMergeTemplate,
                identifier: "image-merge-arrangement-label",
                rowIdentifier: "image-merge-parameters-arrangement-row",
                dropdown: arrangementDropdown,
                accessory: nil,
                labelColumnWidth: labelColumnWidth
            ),
            parameterRow(
                title: L10n.imageMergeSpacing,
                identifier: "image-merge-spacing-label",
                rowIdentifier: "image-merge-parameters-spacing-row",
                dropdown: spacingDropdown,
                accessory: nil,
                labelColumnWidth: labelColumnWidth
            ),
            parameterRow(
                title: L10n.imageMergeMargin,
                identifier: "image-merge-margin-label",
                rowIdentifier: "image-merge-parameters-margin-row",
                dropdown: marginDropdown,
                accessory: nil,
                labelColumnWidth: labelColumnWidth
            ),
            parameterRow(
                title: L10n.imageMergeCornerRadius,
                identifier: "image-merge-corner-label",
                rowIdentifier: "image-merge-parameters-corner-row",
                dropdown: cornerDropdown,
                accessory: nil,
                labelColumnWidth: labelColumnWidth
            ),
            parameterRow(
                title: L10n.imageMergeBackground,
                identifier: "image-merge-background-label",
                rowIdentifier: "image-merge-parameters-background-row",
                dropdown: backgroundDropdown,
                accessory: backgroundColorButton,
                labelColumnWidth: labelColumnWidth
            ),
        ]
        let stack = NSStackView(views: rows)
        stack.identifier = NSUserInterfaceItemIdentifier("image-merge-parameters-rows")
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
        return content
    }

    private func parameterLabelColumnWidth() -> CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let titles = [
            L10n.imageMergeTemplate,
            L10n.imageMergeSpacing,
            L10n.imageMergeMargin,
            L10n.imageMergeCornerRadius,
            L10n.imageMergeBackground,
        ]
        let widestTitle = titles.map {
            ($0 as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return max(82, ceil(widestTitle) + 28)
    }

    private func parameterRow(
        title: String,
        identifier: String,
        rowIdentifier: String,
        dropdown: ImageMergeDropdownButton,
        accessory: NSView?,
        labelColumnWidth: CGFloat
    ) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.identifier = NSUserInterfaceItemIdentifier(identifier)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let labelSlot = NSView()
        labelSlot.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        labelSlot.addSubview(label)
        var labelSlotConstraints = [
            label.leadingAnchor.constraint(equalTo: labelSlot.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: labelSlot.centerYAnchor),
        ]
        if let accessory {
            let accessoryContainer = NSView()
            accessoryContainer.identifier = NSUserInterfaceItemIdentifier(
                "image-merge-background-color-slot"
            )
            accessoryContainer.translatesAutoresizingMaskIntoConstraints = false
            labelSlot.addSubview(accessoryContainer)

            accessory.translatesAutoresizingMaskIntoConstraints = false
            accessoryContainer.addSubview(accessory)
            labelSlotConstraints.append(contentsOf: [
                label.trailingAnchor.constraint(
                    lessThanOrEqualTo: accessoryContainer.leadingAnchor,
                    constant: -6
                ),
                accessoryContainer.trailingAnchor.constraint(
                    equalTo: labelSlot.trailingAnchor
                ),
                accessoryContainer.centerYAnchor.constraint(
                    equalTo: labelSlot.centerYAnchor
                ),
                accessoryContainer.widthAnchor.constraint(equalToConstant: 22),
                accessoryContainer.heightAnchor.constraint(equalToConstant: 22),
                accessory.centerXAnchor.constraint(
                    equalTo: accessoryContainer.centerXAnchor
                ),
                accessory.centerYAnchor.constraint(
                    equalTo: accessoryContainer.centerYAnchor
                ),
                accessory.widthAnchor.constraint(equalToConstant: 22),
                accessory.heightAnchor.constraint(equalToConstant: 22),
            ])
        } else {
            labelSlotConstraints.append(
                label.trailingAnchor.constraint(
                    lessThanOrEqualTo: labelSlot.trailingAnchor
                )
            )
        }
        NSLayoutConstraint.activate(labelSlotConstraints)

        let row = NSStackView(views: [labelSlot, dropdown])
        row.identifier = NSUserInterfaceItemIdentifier(rowIdentifier)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 30),
            labelSlot.widthAnchor.constraint(equalToConstant: labelColumnWidth),
            dropdown.widthAnchor.constraint(equalToConstant: 106),
        ])
        return row
    }

    private func buildControlsView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageCard = imageListCard()
        imageCard.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageCard)

        let footer = outputControls()
        footer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(footer)

        NSLayoutConstraint.activate([
            imageCard.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            imageCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            imageCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            imageCard.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            imageCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 250),
            footer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            footer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            footer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        return container
    }

    private func imageListCard() -> NSView {
        let card = ImageMergeSidebarCardView()
        card.identifier = NSUserInterfaceItemIdentifier("image-merge-image-list-card")

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let label = NSTextField(labelWithString: L10n.imageMergeImageList)
        label.identifier = NSUserInterfaceItemIdentifier("image-merge-image-list-label")
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let sourceButtons = NSStackView()
        sourceButtons.identifier = NSUserInterfaceItemIdentifier("image-merge-image-source-buttons")
        sourceButtons.orientation = .horizontal
        sourceButtons.spacing = 8
        sourceButtons.alignment = .centerY
        let addFiles = NSButton(title: L10n.imageMergeAddFiles, target: self, action: #selector(addFilesClicked))
        let addClipboard = NSButton(title: L10n.imageMergeAddFromClipboard, target: self, action: #selector(addClipboardClicked))
        addFiles.identifier = NSUserInterfaceItemIdentifier("image-merge-add-files")
        addClipboard.identifier = NSUserInterfaceItemIdentifier("image-merge-add-from-clipboard")
        addFiles.bezelStyle = .rounded
        addClipboard.bezelStyle = .rounded
        sourceButtons.addArrangedSubview(addFiles)
        sourceButtons.addArrangedSubview(addClipboard)
        sourceButtons.setContentHuggingPriority(.required, for: .horizontal)
        sourceButtons.setContentCompressionResistancePriority(.required, for: .horizontal)

        let headerSpacer = NSView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [label, headerSpacer, sourceButtons])
        header.identifier = NSUserInterfaceItemIdentifier("image-merge-image-list-header")
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        stack.addArrangedSubview(header)

        thumbnailListView.document = mergeDocument
        thumbnailListView.onSelect = { [weak self] in self?.refreshAll() }
        thumbnailListView.onReorder = { [weak self] in self?.refreshAll() }
        thumbnailListView.onDelete = { [weak self] in self?.refreshAll() }
        let thumbScroll = NSScrollView()
        thumbScroll.hasVerticalScroller = true
        thumbScroll.borderType = .noBorder
        thumbScroll.drawsBackground = false
        thumbScroll.documentView = thumbnailListView
        thumbScroll.translatesAutoresizingMaskIntoConstraints = false
        thumbnailListView.autoresizingMask = [.width]
        stack.addArrangedSubview(thumbScroll)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            thumbScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            thumbScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
        ])
        return card
    }

    private func configureControls() {
        configureDropdown(
            arrangementDropdown,
            identifier: "image-merge-arrangement-dropdown",
            accessibilityLabel: L10n.imageMergeTemplate,
            titles: ImageMergeTemplate.allCases.map(\.title)
        )
        arrangementDropdown.onSelection = { [weak self] _ in
            self?.arrangementChanged()
        }
        configureDropdown(
            spacingDropdown,
            identifier: "image-merge-spacing-dropdown",
            accessibilityLabel: L10n.imageMergeSpacing,
            titles: ImageMergeSpacingPreset.allCases.map(\.title)
        )
        spacingDropdown.onSelection = { [weak self] _ in
            self?.layoutPresetChanged()
        }
        configureDropdown(
            marginDropdown,
            identifier: "image-merge-margin-dropdown",
            accessibilityLabel: L10n.imageMergeMargin,
            titles: ImageMergeMarginPreset.allCases.map(\.title)
        )
        marginDropdown.onSelection = { [weak self] _ in
            self?.layoutPresetChanged()
        }
        configureDropdown(
            cornerDropdown,
            identifier: "image-merge-corner-dropdown",
            accessibilityLabel: L10n.imageMergeCornerRadius,
            titles: ImageMergeCornerPreset.allCases.map(\.title)
        )
        cornerDropdown.onSelection = { [weak self] _ in
            self?.layoutPresetChanged()
        }
        configureDropdown(
            backgroundDropdown,
            identifier: "image-merge-background-dropdown",
            accessibilityLabel: L10n.imageMergeBackground,
            titles: [
                L10n.imageMergeTransparent,
                L10n.imageMergeSolid,
            ]
        )
        backgroundDropdown.onSelection = { [weak self] _ in
            self?.backgroundModeChanged()
        }

        backgroundColorButton.identifier = NSUserInterfaceItemIdentifier(
            "image-merge-background-color-edit"
        )
        backgroundColorButton.configure(
            color: ImageMergeDocument.color(
                fromHex: Defaults.imageMergeBackgroundColorHex
            ) ?? .white,
            accessibilityLabel: L10n.imageMergeBackground
        )
        backgroundColorButton.onSelection = { [weak self] color in
            self?.backgroundColorChanged(color)
        }

        parametersButton.target = self
        parametersButton.action = #selector(parametersClicked)
        copyButton.target = self
        copyButton.action = #selector(copyClicked)
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        continueButton.target = self
        continueButton.action = #selector(continueEditingClicked)
        parametersButton.identifier = NSUserInterfaceItemIdentifier("image-merge-parameters")
        continueButton.identifier = NSUserInterfaceItemIdentifier("image-merge-continue-editing")
        copyButton.identifier = NSUserInterfaceItemIdentifier("image-merge-copy")
        saveButton.identifier = NSUserInterfaceItemIdentifier("image-merge-save")
        parametersButton.setButtonType(.toggle)
        [parametersButton, continueButton, copyButton, saveButton].forEach {
            $0.bezelStyle = .rounded
            $0.controlSize = .large
        }
        saveButton.bezelColor = .controlAccentColor
    }

    private func configureDropdown(
        _ dropdown: ImageMergeDropdownButton,
        identifier: String,
        accessibilityLabel: String,
        titles: [String]
    ) {
        dropdown.identifier = NSUserInterfaceItemIdentifier(identifier)
        dropdown.opensUpward = false
        dropdown.configure(options: titles, accessibilityLabel: accessibilityLabel)
        dropdown.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func outputControls() -> NSView {
        let footer = ImageMergeSidebarCardView()
        footer.identifier = NSUserInterfaceItemIdentifier("image-merge-output-controls")
        footer.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.identifier = NSUserInterfaceItemIdentifier("image-merge-output-buttons")
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(stack)

        stack.addArrangedSubview(parametersButton)
        stack.addArrangedSubview(continueButton)
        stack.addArrangedSubview(copyButton)
        stack.addArrangedSubview(saveButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -12),
            parametersButton.heightAnchor.constraint(
                equalToConstant: Self.outputButtonHeight
            ),
            continueButton.heightAnchor.constraint(
                equalToConstant: Self.outputButtonHeight
            ),
            copyButton.heightAnchor.constraint(
                equalToConstant: Self.outputButtonHeight
            ),
            saveButton.heightAnchor.constraint(
                equalToConstant: Self.outputButtonHeight
            ),
            parametersButton.widthAnchor.constraint(equalTo: continueButton.widthAnchor),
            continueButton.widthAnchor.constraint(equalTo: copyButton.widthAnchor),
            copyButton.widthAnchor.constraint(equalTo: saveButton.widthAnchor),
        ])
        return footer
    }

    private func refreshAll() {
        canvasView.document = mergeDocument
        thumbnailListView.document = mergeDocument
        thumbnailListView.needsDisplay = true

        let spacingPreset = ImageMergeSpacingPreset.nearest(to: mergeDocument.spacing)
        let marginPreset = ImageMergeMarginPreset.nearest(to: mergeDocument.margin)
        let cornerPreset = ImageMergeCornerPreset.nearest(to: mergeDocument.cornerRadius)
        arrangementDropdown.selectItem(at: mergeDocument.template.rawValue)
        spacingDropdown.selectItem(at: spacingPreset.rawValue)
        marginDropdown.selectItem(at: marginPreset.rawValue)
        cornerDropdown.selectItem(at: cornerPreset.rawValue)

        switch mergeDocument.background {
        case .transparent:
            backgroundDropdown.selectItem(at: 0)
            backgroundColorButton.isEnabled = false
            backgroundColorButton.selectColor(
                ImageMergeDocument.color(
                    fromHex: Defaults.imageMergeBackgroundColorHex
                ) ?? .white
            )
        case .solid(let color):
            backgroundDropdown.selectItem(at: 1)
            backgroundColorButton.isEnabled = true
            backgroundColorButton.selectColor(color)
        }

        let canOutput = mergeDocument.canOutput
        copyButton.isEnabled = canOutput
        saveButton.isEnabled = canOutput
        continueButton.isEnabled = canOutput
        canvasView.needsDisplay = true
    }

    @objc private func addFilesClicked() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK else { return }
            self?.appendImages(from: panel.urls)
        }
    }

    @objc private func addClipboardClicked() {
        let urls = ClipboardImageSource.currentImageFileURLs()
        if !urls.isEmpty {
            let result = ImageMergeDocument.loadItems(from: urls)
            guard !result.items.isEmpty else {
                ToastWindow.show(message: L10n.imageMergeNoClipboardImage)
                return
            }
            mergeDocument.append(result.items)
            refreshAll()
            if result.failedCount > 0 {
                ToastWindow.show(message: L10n.imageMergeSomeImagesSkipped)
            }
            return
        }

        guard let image = ClipboardImageSource.currentImage(),
              let item = ImageMergeDocument.item(fromClipboardImage: image)
        else {
            ToastWindow.show(message: L10n.imageMergeNoClipboardImage)
            return
        }
        mergeDocument.append([item])
        refreshAll()
    }

    @objc private func parametersClicked() {
        if parametersPopover.isShown {
            parametersPopover.performClose(nil)
        } else {
            parametersPopover.show(
                relativeTo: parametersButton.bounds,
                of: parametersButton,
                preferredEdge: parametersPopoverPreferredEdge
            )
        }
    }

    func popoverWillShow(_ notification: Notification) {
        parametersButton.state = .on
    }

    func popoverDidClose(_ notification: Notification) {
        parametersButton.state = .off
        [
            arrangementDropdown,
            spacingDropdown,
            marginDropdown,
            cornerDropdown,
            backgroundDropdown,
        ].forEach {
            $0.dismissDropdown()
        }
        backgroundColorButton.dismissPalette()
    }

    @objc private func arrangementChanged() {
        let template = ImageMergeTemplate(
            rawValue: arrangementDropdown.selectedIndex
        ) ?? .grid
        mergeDocument.template = template
        Defaults.imageMergeTemplate = template
        refreshAll()
    }

    @objc private func layoutPresetChanged() {
        let spacingPreset = ImageMergeSpacingPreset(
            rawValue: spacingDropdown.selectedIndex
        ) ?? .medium
        let marginPreset = ImageMergeMarginPreset(
            rawValue: marginDropdown.selectedIndex
        ) ?? .medium
        let cornerPreset = ImageMergeCornerPreset(
            rawValue: cornerDropdown.selectedIndex
        ) ?? .square
        mergeDocument.spacing = spacingPreset.value
        mergeDocument.margin = marginPreset.value
        mergeDocument.cornerRadius = cornerPreset.value
        Defaults.imageMergeSpacingPreset = spacingPreset
        Defaults.imageMergeMarginPreset = marginPreset
        Defaults.imageMergeCornerPreset = cornerPreset
        refreshAll()
    }

    @objc private func backgroundModeChanged() {
        if backgroundDropdown.selectedIndex == 1 {
            mergeDocument.background = .solid(backgroundColorButton.selectedColor)
            Defaults.imageMergeBackgroundIsSolid = true
            persistBackgroundColor(backgroundColorButton.selectedColor)
        } else {
            mergeDocument.background = .transparent
            Defaults.imageMergeBackgroundIsSolid = false
        }
        refreshAll()
    }

    private func backgroundColorChanged(_ color: NSColor) {
        if backgroundDropdown.selectedIndex == 1 {
            mergeDocument.background = .solid(color)
            Defaults.imageMergeBackgroundIsSolid = true
            persistBackgroundColor(color)
        }
        refreshAll()
    }

    private func persistBackgroundColor(_ color: NSColor) {
        if let hex = ImageMergeDocument.hexString(from: color) {
            Defaults.imageMergeBackgroundColorHex = hex
        }
    }

    @objc private func copyClicked() {
        guard let image = renderOrToast() else { return }
        ClipboardManager.copyToClipboard(image: image)
        ToastWindow.show()
    }

    @objc private func saveClicked() {
        guard let image = renderOrToast() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultFilename()
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window!) { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = image.pngDataPreservingBacking() else {
                ToastWindow.show(message: L10n.imageMergeFailed)
                return
            }
            do {
                try data.write(to: url, options: .atomic)
                ToastWindow.show(message: L10n.imageMergeSaved)
            } catch {
                ToastWindow.show(message: L10n.imageMergeFailed)
            }
        }
    }

    @objc private func continueEditingClicked() {
        guard let image = renderOrToast() else { return }
        close()
        onContinueEditing(image)
    }

    private func renderOrToast() -> NSImage? {
        guard mergeDocument.canOutput,
              let image = ImageMergeRenderer.render(document: mergeDocument)
        else {
            ToastWindow.show(message: L10n.imageMergeFailed)
            return nil
        }
        return image
    }

    private func defaultFilename(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "aulycShot-merge-\(formatter.string(from: date)).png"
    }
}

final class ImageMergeSplitView: NSSplitView {
    override var dividerThickness: CGFloat {
        0
    }

    override func drawDivider(in rect: NSRect) {}
}

final class ImageMergeColorPaletteButton: NSButton {
    static let paletteColumns = 6
    static let editIconSymbolName = "square.and.pencil"
    static let editIconPointSize: CGFloat = 10
    static let paletteHexColors = [
        "#7A1711", "#7A4400", "#7A6000", "#135E26", "#005E59", "#00377A",
        "#BE2921", "#BE6D00", "#BE9700", "#249340", "#00938C", "#0059BE",
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#007AFF",
        "#FF8373", "#FFB771", "#FFDD7A", "#81D98D", "#7AD9D1", "#64A6FF",
        "#FFC4B9", "#FFDCBB", "#FFEFC1", "#C3EDC6", "#C1ECE8", "#B2D4FF",
        "#000000", "#48484A", "#8E8E93", "#C7C7CC", "#E5E5EA", "#FFFFFF",
    ]
    static let paletteColors: [NSColor] = paletteHexColors.compactMap(
        ImageMergeDocument.color(fromHex:)
    )

    private static weak var expandedPalette: ImageMergeColorPaletteButton?
    private static let swatchSize: CGFloat = 22
    private static let swatchSpacing: CGFloat = 4
    private static let panelPadding: CGFloat = 10
    private static let panelGap: CGFloat = 8

    private(set) var selectedColor: NSColor = .white
    var onSelection: ((NSColor) -> Void)?

    private var palettePanel: NSPanel?
    private var dismissalMonitor: Any?

    override var isEnabled: Bool {
        didSet {
            if !isEnabled {
                closePalettePanel()
            }
            alphaValue = 1
            updateAppearance()
        }
    }

    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        MainActor.assumeIsolated {
            closePalettePanel()
        }
    }

    func configure(color: NSColor, accessibilityLabel: String) {
        setAccessibilityLabel(accessibilityLabel)
        toolTip = nil
        selectColor(color)
    }

    func selectColor(_ color: NSColor) {
        selectedColor = Self.nearestPaletteColor(to: color)
        setAccessibilityValue(
            ImageMergeDocument.hexString(from: selectedColor)
        )
        updateAppearance()
    }

    func selectPaletteColor(at index: Int) {
        guard Self.paletteColors.indices.contains(index) else { return }
        selectedColor = Self.paletteColors[index]
        setAccessibilityValue(
            ImageMergeDocument.hexString(from: selectedColor)
        )
        updateAppearance()
        onSelection?(selectedColor)
        closePalettePanel()
    }

    func dismissPalette() {
        closePalettePanel()
    }

    func palettePanelFrame(buttonScreenFrame: NSRect) -> NSRect {
        let rows = Int(
            ceil(Double(Self.paletteColors.count) / Double(Self.paletteColumns))
        )
        let width = Self.panelPadding * 2
            + CGFloat(Self.paletteColumns) * Self.swatchSize
            + CGFloat(Self.paletteColumns - 1) * Self.swatchSpacing
        let height = Self.panelPadding * 2
            + CGFloat(rows) * Self.swatchSize
            + CGFloat(max(rows - 1, 0)) * Self.swatchSpacing
        return NSRect(
            x: buttonScreenFrame.midX - width / 2,
            y: buttonScreenFrame.maxY + Self.panelGap,
            width: width,
            height: height
        )
    }

    func makePalettePanel(buttonScreenFrame: NSRect) -> NSPanel {
        let panelFrame = palettePanelFrame(buttonScreenFrame: buttonScreenFrame)
        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]

        let content = palettePanelContent()
        content.frame = NSRect(origin: .zero, size: panelFrame.size)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content
        panel.setFrame(panelFrame, display: false)
        panel.contentView?.frame = NSRect(origin: .zero, size: panelFrame.size)
        return panel
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        title = ""
        isBordered = false
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        image = NSImage(
            systemSymbolName: Self.editIconSymbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: Self.editIconPointSize,
                weight: .medium
            )
        )
        contentTintColor = .secondaryLabelColor
        toolTip = nil
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.cornerCurve = .continuous
        target = self
        action = #selector(togglePalettePanel)
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            closePalettePanel()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    @objc private func togglePalettePanel() {
        if palettePanel == nil {
            showPalettePanel()
        } else {
            closePalettePanel()
        }
    }

    private func showPalettePanel() {
        guard isEnabled, let hostWindow = window else { return }

        Self.expandedPalette?.closePalettePanel()

        let buttonFrameInWindow = convert(bounds, to: nil)
        let buttonScreenFrame = hostWindow.convertToScreen(buttonFrameInWindow)
        let panel = makePalettePanel(buttonScreenFrame: buttonScreenFrame)
        if let visibleFrame = hostWindow.screen?.visibleFrame {
            var panelFrame = panel.frame
            panelFrame.origin.x = min(
                max(panelFrame.minX, visibleFrame.minX + 8),
                visibleFrame.maxX - panelFrame.width - 8
            )
            panelFrame.origin.y = min(
                max(panelFrame.minY, visibleFrame.minY + 8),
                visibleFrame.maxY - panelFrame.height - 8
            )
            panel.setFrame(panelFrame, display: false)
        }
        panel.level = NSWindow.Level(rawValue: hostWindow.level.rawValue + 1)
        panel.appearance = effectiveAppearance

        palettePanel = panel
        Self.expandedPalette = self
        hostWindow.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        installDismissalMonitor()
        updateAppearance()
    }

    private func palettePanelContent() -> NSView {
        let content = ImageMergeColorPalettePanelView()
        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.distribution = .fillEqually
        grid.spacing = Self.swatchSpacing
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        for rowStart in stride(
            from: 0,
            to: Self.paletteColors.count,
            by: Self.paletteColumns
        ) {
            let rowEnd = min(
                rowStart + Self.paletteColumns,
                Self.paletteColors.count
            )
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.spacing = Self.swatchSpacing
            for index in rowStart..<rowEnd {
                let swatch = ImageMergeColorSwatchButton(
                    color: Self.paletteColors[index],
                    selected: Self.colorsMatch(
                        Self.paletteColors[index],
                        selectedColor
                    )
                )
                swatch.onSelect = { [weak self] in
                    self?.selectPaletteColor(at: index)
                }
                row.addArrangedSubview(swatch)
                NSLayoutConstraint.activate([
                    swatch.widthAnchor.constraint(
                        equalToConstant: Self.swatchSize
                    ),
                    swatch.heightAnchor.constraint(
                        equalToConstant: Self.swatchSize
                    ),
                ])
            }
            grid.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(
                equalTo: content.topAnchor,
                constant: Self.panelPadding
            ),
            grid.leadingAnchor.constraint(
                equalTo: content.leadingAnchor,
                constant: Self.panelPadding
            ),
            grid.trailingAnchor.constraint(
                equalTo: content.trailingAnchor,
                constant: -Self.panelPadding
            ),
            grid.bottomAnchor.constraint(
                equalTo: content.bottomAnchor,
                constant: -Self.panelPadding
            ),
        ])
        return content
    }

    private func installDismissalMonitor() {
        dismissalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                closePalettePanel()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let location = NSEvent.mouseLocation
                let insidePanel = palettePanel?.frame.contains(location) == true
                let insideButton = currentButtonScreenFrame()?.contains(location) == true
                if !insidePanel, !insideButton {
                    closePalettePanel()
                }
            }
            return event
        }
    }

    private func currentButtonScreenFrame() -> NSRect? {
        guard let hostWindow = window else { return nil }
        return hostWindow.convertToScreen(convert(bounds, to: nil))
    }

    private func closePalettePanel() {
        if let dismissalMonitor {
            NSEvent.removeMonitor(dismissalMonitor)
            self.dismissalMonitor = nil
        }
        if let palettePanel {
            palettePanel.parent?.removeChildWindow(palettePanel)
            palettePanel.orderOut(nil)
            self.palettePanel = nil
        }
        if Self.expandedPalette === self {
            Self.expandedPalette = nil
        }
        updateAppearance()
    }

    private func updateAppearance() {
        let fill = isEnabled ? selectedColor : NSColor.clear
        contentTintColor = isEnabled
            ? Self.editIconColor(for: selectedColor)
            : .disabledControlTextColor
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            fill,
            for: effectiveAppearance
        )
    }

    private static func editIconColor(for color: NSColor) -> NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .white }

        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        let luminance =
            0.2126 * linearized(rgb.redComponent)
            + 0.7152 * linearized(rgb.greenComponent)
            + 0.0722 * linearized(rgb.blueComponent)
        return luminance > 0.18 ? .black : .white
    }

    private static func nearestPaletteColor(to color: NSColor) -> NSColor {
        paletteColors.min {
            colorDistance($0, color) < colorDistance($1, color)
        } ?? .white
    }

    private static func colorsMatch(_ lhs: NSColor, _ rhs: NSColor) -> Bool {
        colorDistance(lhs, rhs) < 0.0001
    }

    private static func colorDistance(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
        guard let left = lhs.usingColorSpace(.sRGB),
              let right = rhs.usingColorSpace(.sRGB)
        else {
            return .greatestFiniteMagnitude
        }
        let red = left.redComponent - right.redComponent
        let green = left.greenComponent - right.greenComponent
        let blue = left.blueComponent - right.blueComponent
        return red * red + green * green + blue * blue
    }
}

final class ImageMergeColorSwatchButton: NSButton {
    static let selectionSymbolName = "checkmark"

    let swatchColor: NSColor
    let isCurrentSelection: Bool
    var onSelect: (() -> Void)?

    init(color: NSColor, selected: Bool) {
        swatchColor = color
        isCurrentSelection = selected
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        title = ""
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = swatchColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        if isCurrentSelection {
            image = NSImage(
                systemSymbolName: Self.selectionSymbolName,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(
                    pointSize: 12,
                    weight: .bold
                )
            )
            imagePosition = .imageOnly
            imageScaling = .scaleProportionallyDown
            contentTintColor = .black
        }
        target = self
        action = #selector(clicked)
        setAccessibilityLabel(
            ImageMergeDocument.hexString(from: swatchColor)
        )
        toolTip = nil
    }

    @objc private func clicked() {
        onSelect?()
    }
}

private final class ImageMergeColorPalettePanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            AdaptiveChrome.popoverBackground,
            for: effectiveAppearance
        )
        layer?.borderColor = AdaptiveChrome.resolvedCGColor(
            .separatorColor,
            for: effectiveAppearance
        )
    }
}

final class ImageMergeDropdownButton: NSButton {
    private(set) var optionTitles: [String] = []
    private(set) var selectedIndex = 0
    var opensUpward = false
    var onSelection: ((Int) -> Void)?

    private static weak var expandedDropdown: ImageMergeDropdownButton?

    private var controlAccessibilityLabel = ""
    private let valueLabel = NSTextField(labelWithString: "")
    private let chevronView = NSImageView()
    private var dropdownPanel: NSPanel?
    private var dismissalMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        MainActor.assumeIsolated {
            closeDropdownPanel()
        }
    }

    func configure(options: [String], accessibilityLabel: String) {
        optionTitles = options
        controlAccessibilityLabel = accessibilityLabel
        selectedIndex = min(selectedIndex, max(options.count - 1, 0))
        setAccessibilityLabel(accessibilityLabel)
        updateTitle()
    }

    func selectItem(at index: Int) {
        guard optionTitles.indices.contains(index) else { return }
        selectedIndex = index
        updateTitle()
    }

    func dismissDropdown() {
        closeDropdownPanel()
    }

    func dropdownPanelFrame(
        buttonScreenFrame: NSRect,
        optionCount: Int
    ) -> NSRect {
        let rowHeight: CGFloat = 38
        let rowSpacing: CGFloat = 2
        let verticalPadding: CGFloat = 12
        let rowsHeight = CGFloat(optionCount) * rowHeight
        let spacingHeight = CGFloat(max(optionCount - 1, 0)) * rowSpacing
        let panelHeight = rowsHeight + spacingHeight + verticalPadding
        let panelY = opensUpward
            ? buttonScreenFrame.maxY + 6
            : buttonScreenFrame.minY - panelHeight - 6
        return NSRect(
            x: buttonScreenFrame.minX,
            y: panelY,
            width: buttonScreenFrame.width,
            height: panelHeight
        )
    }

    func makeDropdownPanel(buttonScreenFrame: NSRect) -> NSPanel {
        let panelFrame = dropdownPanelFrame(
            buttonScreenFrame: buttonScreenFrame,
            optionCount: optionTitles.count
        )
        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]

        let content = dropdownPanelContent()
        content.frame = NSRect(origin: .zero, size: panelFrame.size)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content

        // Assigning a content view can let its intrinsic width influence the
        // borderless panel. Reapply the requested frame so the menu remains
        // exactly as wide as its selector.
        panel.setFrame(panelFrame, display: false)
        panel.contentView?.frame = NSRect(origin: .zero, size: panelFrame.size)
        return panel
    }

    var usesDownwardChevron: Bool {
        true
    }

    var selectorFont: NSFont? {
        valueLabel.font
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        controlSize = .small
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 12, weight: .medium)
        valueLabel.textColor = .labelColor
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.maximumNumberOfLines = 1
        addSubview(valueLabel)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        )
        chevronView.contentTintColor = .secondaryLabelColor
        chevronView.imageScaling = .scaleProportionallyDown
        addSubview(chevronView)

        NSLayoutConstraint.activate([
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -6),
            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),
            chevronView.heightAnchor.constraint(equalToConstant: 10),
        ])

        target = self
        action = #selector(toggleDropdownPanel)
        updateAppearance()
    }

    private func updateTitle() {
        guard optionTitles.indices.contains(selectedIndex) else {
            valueLabel.stringValue = ""
            return
        }
        let selectedTitle = optionTitles[selectedIndex]
        valueLabel.stringValue = selectedTitle
        toolTip = nil
        setAccessibilityValue(selectedTitle)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            closeDropdownPanel()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private func updateAppearance() {
        let fill = dropdownPanel == nil
            ? AdaptiveChrome.subtleFill
            : NSColor.controlAccentColor.withAlphaComponent(0.18)
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            fill,
            for: effectiveAppearance
        )
    }

    @objc private func toggleDropdownPanel() {
        if dropdownPanel != nil {
            closeDropdownPanel()
        } else {
            showDropdownPanel()
        }
    }

    private func showDropdownPanel() {
        guard !optionTitles.isEmpty,
              let hostWindow = window
        else {
            return
        }

        Self.expandedDropdown?.closeDropdownPanel()

        let buttonFrameInWindow = convert(bounds, to: nil)
        let buttonScreenFrame = hostWindow.convertToScreen(buttonFrameInWindow)
        let panel = makeDropdownPanel(buttonScreenFrame: buttonScreenFrame)
        panel.level = NSWindow.Level(rawValue: hostWindow.level.rawValue + 1)
        panel.appearance = effectiveAppearance

        dropdownPanel = panel
        Self.expandedDropdown = self
        hostWindow.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        installDismissalMonitor()
        updateAppearance()
    }

    private func dropdownPanelContent() -> NSView {
        let content = ImageMergeDropdownPanelView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        for (index, optionTitle) in optionTitles.enumerated() {
            let row = ImageMergeDropdownOptionButton(
                title: optionTitle,
                index: index,
                selected: index == selectedIndex
            )
            row.onSelect = { [weak self] selectedIndex in
                self?.selectDropdownItem(at: selectedIndex)
            }
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
        ])
        return content
    }

    private func installDismissalMonitor() {
        dismissalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                closeDropdownPanel()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                let location = NSEvent.mouseLocation
                let insidePanel = dropdownPanel?.frame.contains(location) == true
                let insideButton = currentButtonScreenFrame()?.contains(location) == true
                if !insidePanel, !insideButton {
                    closeDropdownPanel()
                }
            }
            return event
        }
    }

    private func currentButtonScreenFrame() -> NSRect? {
        guard let hostWindow = window else { return nil }
        return hostWindow.convertToScreen(convert(bounds, to: nil))
    }

    private func closeDropdownPanel() {
        if let monitor = dismissalMonitor {
            NSEvent.removeMonitor(monitor)
            dismissalMonitor = nil
        }
        if let panel = dropdownPanel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
            dropdownPanel = nil
        }
        if Self.expandedDropdown === self {
            Self.expandedDropdown = nil
        }
        updateAppearance()
    }

    private func selectDropdownItem(at index: Int) {
        selectItem(at: index)
        onSelection?(selectedIndex)
        closeDropdownPanel()
    }
}

private final class ImageMergeDropdownPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            AdaptiveChrome.popoverBackground,
            for: effectiveAppearance
        )
        layer?.borderColor = AdaptiveChrome.resolvedCGColor(
            .separatorColor,
            for: effectiveAppearance
        )
    }
}

private final class ImageMergeDropdownOptionButton: NSButton {
    let optionIndex: Int
    var onSelect: ((Int) -> Void)?

    private let optionLabel: NSTextField
    private let checkmarkView = NSImageView()
    private let isCurrentSelection: Bool
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init(title: String, index: Int, selected: Bool) {
        optionIndex = index
        optionLabel = NSTextField(labelWithString: title)
        isCurrentSelection = selected
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        target = self
        action = #selector(clicked)

        optionLabel.translatesAutoresizingMaskIntoConstraints = false
        optionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        optionLabel.textColor = .labelColor
        optionLabel.lineBreakMode = .byTruncatingTail
        addSubview(optionLabel)

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.image = NSImage(
            systemSymbolName: "checkmark",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        checkmarkView.contentTintColor = .labelColor
        checkmarkView.imageScaling = .scaleProportionallyDown
        checkmarkView.isHidden = !isCurrentSelection
        addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),
            optionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            optionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            optionLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkView.leadingAnchor, constant: -8),
            checkmarkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 14),
            checkmarkView.heightAnchor.constraint(equalToConstant: 14),
        ])
        updateAppearance()
    }

    private func updateAppearance() {
        let fill: NSColor
        if isCurrentSelection {
            fill = AdaptiveChrome.subtleFill
        } else if isHovered {
            fill = NSColor.labelColor.withAlphaComponent(0.08)
        } else {
            fill = .clear
        }
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            fill,
            for: effectiveAppearance
        )
    }

    @objc private func clicked() {
        onSelect?(optionIndex)
    }
}

private final class ImageMergeSidebarCardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 0
        applyAppearance()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            AdaptiveChrome.cardBackground,
            for: effectiveAppearance
        )
    }
}
