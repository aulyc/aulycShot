import AppKit
import UniformTypeIdentifiers

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
