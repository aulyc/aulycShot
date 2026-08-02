import AppKit
import Carbon.HIToolbox

/// Which toolbar a grid section maps to in `ToolbarLayout`.
enum ToolbarSection {
    case primary
    case side
    case hidden
}

/// Settings tab for customizing the editor toolbars. The main and side
/// toolbars are edited directly in the preview, while hidden tools live in an
/// on-demand nine-slot panel anchored to the preview's lower-right corner.
@MainActor
final class ToolbarSettingsPane: NSView {
    /// Layout currently shown in the grids and preview. Drag edits persist
    /// immediately, so the settings page has no separate apply step.
    private var workingLayout: ToolbarLayout = Defaults.toolbarLayout.normalized()

    private let preview = ToolbarLayoutPreviewView()
    private var previewHeightConstraint: NSLayoutConstraint!
    let hiddenGrid = ToolbarSlotGridView(
        section: .hidden,
        fixedGridColumns: 3,
        fixedGridRows: 3,
        maximumItemCount: ToolbarLayout.maximumHiddenItems
    )
    let hiddenToolsButton = SettingsOutlinedButton(title: "", target: nil, action: nil)
    private var hiddenToolsPanel: ToolbarHiddenToolsPanel?
    private var hiddenToolsEventMonitor: Any?
    private var pageScrollObserver: NSObjectProtocol?
    private weak var observedPageClipView: NSClipView?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildUI()
        syncFromWorkingLayout()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onLanguageChanged),
            name: .languageDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            dismissHiddenToolsPanel(restoreFocus: false)
            stopObservingPageScroll()
            NotificationCenter.default.removeObserver(self)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopObservingPageScroll()
        guard window != nil else {
            dismissHiddenToolsPanel(restoreFocus: false)
            return
        }
        guard let clipView = enclosingScrollView?.contentView else { return }
        clipView.postsBoundsChangedNotifications = true
        observedPageClipView = clipView
        pageScrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                ToolbarTooltipHoverGate.suppressForScroll()
                ToolTipWindow.hide()
                self?.positionHiddenToolsPanel()
            }
        }
    }

    private func stopObservingPageScroll() {
        if let pageScrollObserver {
            NotificationCenter.default.removeObserver(pageScrollObserver)
            self.pageScrollObserver = nil
        }
        observedPageClipView = nil
    }

    // MARK: - Build

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let allDropZones: () -> [ToolbarSlotGridView] = { [weak self] in
            guard let self else { return [] }
            return [self.preview.primaryGrid, self.preview.sideGrid, self.hiddenGrid]
        }
        preview.onLayoutChanged = { [weak self] in self?.collectWorkingLayout() }
        preview.gridProvider = allDropZones
        hiddenGrid.identifier = NSUserInterfaceItemIdentifier("toolbar-hidden-drop-zone")
        hiddenGrid.onLayoutChanged = { [weak self] in self?.collectWorkingLayout() }
        hiddenGrid.gridProvider = allDropZones

        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.setContentCompressionResistancePriority(.required, for: .vertical)
        preview.setContentHuggingPriority(.required, for: .vertical)
        previewHeightConstraint = preview.heightAnchor.constraint(equalToConstant: preview.preferredHeight)
        stack.addArrangedSubview(preview)
        preview.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        previewHeightConstraint.isActive = true

        hiddenToolsButton.identifier = NSUserInterfaceItemIdentifier("toolbar-hidden-tools-toggle")
        hiddenToolsButton.target = self
        hiddenToolsButton.action = #selector(hiddenToolsButtonClicked)
        hiddenToolsButton.imagePosition = .imageOnly
        hiddenToolsButton.imageScaling = .scaleProportionallyDown
        hiddenToolsButton.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(hiddenToolsButton)

        NSLayoutConstraint.activate([
            hiddenToolsButton.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -14),
            hiddenToolsButton.bottomAnchor.constraint(equalTo: preview.bottomAnchor, constant: -14),
            hiddenToolsButton.widthAnchor.constraint(equalToConstant: 36),
            hiddenToolsButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
        ])

        applyLocalizedStrings()
    }

    // MARK: - Layout sync

    /// Pushes `workingLayout` into the preview drop zones and hidden grid.
    private func syncFromWorkingLayout() {
        hiddenGrid.setItems(workingLayout.hidden)
        preview.layout = workingLayout
        updatePreviewHeight()
    }

    /// Pulls all three drop zones back into `workingLayout`. Called after every
    /// drag-and-drop edit, with no second preview state to synchronize.
    private func collectWorkingLayout() {
        workingLayout = ToolbarLayout(
            primary: preview.primaryItems,
            side: preview.sideItems,
            hidden: hiddenGrid.items
        ).normalized()
        preview.layout = workingLayout
        hiddenGrid.setItems(workingLayout.hidden)
        updatePreviewHeight()
        Defaults.toolbarLayout = workingLayout
    }

    private func updatePreviewHeight() {
        previewHeightConstraint.constant = preview.preferredHeight
    }

    // MARK: - Actions

    func resetToDefault() {
        workingLayout = .default
        syncFromWorkingLayout()
        Defaults.toolbarLayout = workingLayout
    }

    @objc private func onLanguageChanged() {
        applyLocalizedStrings()
    }

    private func applyLocalizedStrings() {
        let tooltip = L10n.toolbarSettingsHiddenTitle
        hiddenToolsButton.image = NSImage(
            systemSymbolName: "square.grid.3x3",
            accessibilityDescription: tooltip
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        )
        hiddenToolsButton.toolTip = tooltip
        hiddenToolsButton.setAccessibilityLabel(tooltip)
        preview.primaryGrid.refreshTooltips()
        preview.sideGrid.refreshTooltips()
        hiddenGrid.refreshTooltips()
    }

    // MARK: - Hidden tools panel

    var isHiddenToolsPanelVisible: Bool {
        hiddenToolsPanel?.isVisible == true
    }

    @objc private func hiddenToolsButtonClicked() {
        if isHiddenToolsPanelVisible {
            dismissHiddenToolsPanel(restoreFocus: true)
        } else {
            showHiddenToolsPanel()
        }
    }

    func showHiddenToolsPanel() {
        guard let parentWindow = window else { return }
        dismissHiddenToolsPanel(restoreFocus: false)

        let gridEdge = ToolbarSlotGridView.tile * 3 + ToolbarSlotGridView.gap * 2
        let panelPadding: CGFloat = 14
        let panelSize = NSSize(
            width: gridEdge + panelPadding * 2,
            height: gridEdge + panelPadding * 2
        )
        let panel = ToolbarHiddenToolsPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            owner: self
        )
        panel.appearance = effectiveAppearance

        let content = NSView(frame: NSRect(origin: .zero, size: panelSize))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.145, alpha: 0.99).cgColor
        content.layer?.cornerRadius = 10
        content.layer?.cornerCurve = .continuous
        content.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        content.layer?.borderWidth = 1
        content.layer?.masksToBounds = true
        panel.contentView = content

        hiddenGrid.removeFromSuperview()
        hiddenGrid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hiddenGrid)
        NSLayoutConstraint.activate([
            hiddenGrid.topAnchor.constraint(equalTo: content.topAnchor, constant: panelPadding),
            hiddenGrid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: panelPadding),
            hiddenGrid.widthAnchor.constraint(equalToConstant: gridEdge),
            hiddenGrid.heightAnchor.constraint(equalToConstant: gridEdge),
        ])

        hiddenToolsPanel = panel
        positionHiddenToolsPanel()
        installHiddenToolsEventMonitor()
        parentWindow.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismissHiddenToolsPanel(restoreFocus: Bool = true) {
        removeHiddenToolsEventMonitor()
        guard let panel = hiddenToolsPanel else { return }
        hiddenToolsPanel = nil
        panel.prepareToClose()
        let parentWindow = panel.parent
        parentWindow?.removeChildWindow(panel)
        panel.orderOut(nil)
        hiddenGrid.removeFromSuperview()
        if restoreFocus {
            parentWindow?.makeKey()
            parentWindow?.makeFirstResponder(hiddenToolsButton)
        }
    }

    private func positionHiddenToolsPanel() {
        guard
            let panel = hiddenToolsPanel,
            let parentWindow = window,
            !hiddenToolsButton.isHiddenOrHasHiddenAncestor
        else { return }

        let triggerFrame = parentWindow.convertToScreen(
            hiddenToolsButton.convert(hiddenToolsButton.bounds, to: nil)
        )
        let panelSize = panel.frame.size
        let visibleFrame = (parentWindow.screen ?? NSScreen.main)?.visibleFrame ?? triggerFrame
        var origin = NSPoint(
            x: triggerFrame.maxX - panelSize.width,
            y: triggerFrame.maxY + 8
        )
        if origin.y + panelSize.height > visibleFrame.maxY - 8 {
            origin.y = triggerFrame.minY - panelSize.height - 8
        }
        origin.x = min(
            max(origin.x, visibleFrame.minX + 8),
            visibleFrame.maxX - panelSize.width - 8
        )
        origin.y = max(origin.y, visibleFrame.minY + 8)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    private func installHiddenToolsEventMonitor() {
        removeHiddenToolsEventMonitor()
        hiddenToolsEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self,
                  let panel = self.hiddenToolsPanel,
                  panel.isVisible
            else {
                return event
            }

            if event.type == .keyDown, event.keyCode == UInt16(kVK_Escape) {
                self.dismissHiddenToolsPanel()
                return nil
            }
            guard event.type == .leftMouseDown || event.type == .rightMouseDown else {
                return event
            }

            let clickPoint = NSEvent.mouseLocation
            if panel.frame.contains(clickPoint) {
                return event
            }
            let triggerFrame = self.window.map {
                $0.convertToScreen(
                    self.hiddenToolsButton.convert(self.hiddenToolsButton.bounds, to: nil)
                )
            }
            if triggerFrame?.contains(clickPoint) == true || Self.isToolbarTileEvent(event) {
                return event
            }

            self.dismissHiddenToolsPanel(restoreFocus: false)
            return event
        }
    }

    private func removeHiddenToolsEventMonitor() {
        guard let hiddenToolsEventMonitor else { return }
        NSEvent.removeMonitor(hiddenToolsEventMonitor)
        self.hiddenToolsEventMonitor = nil
    }

    private static func isToolbarTileEvent(_ event: NSEvent) -> Bool {
        guard let contentView = event.window?.contentView else { return false }
        let point = contentView.convert(event.locationInWindow, from: nil)
        var hitView: NSView? = contentView.hitTest(point)
        while let view = hitView {
            if view is ToolbarItemTile {
                return true
            }
            hitView = view.superview
        }
        return false
    }
}

private final class ToolbarHiddenToolsPanel: NSPanel {
    private weak var owner: ToolbarSettingsPane?

    init(contentRect: NSRect, owner: ToolbarSettingsPane) {
        self.owner = owner
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.transient, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        owner?.dismissHiddenToolsPanel()
    }

    func prepareToClose() {
        owner = nil
    }
}
