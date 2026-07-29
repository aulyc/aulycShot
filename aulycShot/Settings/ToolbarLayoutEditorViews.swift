import AppKit

/// Renders a toolbar icon flat-tinted to a single color.
func tintedToolbarIcon(_ itemID: ToolbarItemID, pointSize: CGFloat, color: NSColor) -> NSImage? {
    guard let icon = itemID.toolbarIconImage(pointSize: pointSize) else { return nil }
    let tinted = NSImage(size: icon.size, flipped: false) { rect in
        icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    return tinted
}

/// Prevents a toolbar tooltip from being recreated merely because scrolling
/// moved a different tile underneath a stationary pointer.
enum ToolbarTooltipHoverGate {
    private static var pointerLocationAtScroll: NSPoint?
    private static let movementThreshold: CGFloat = 1

    static func suppressForScroll(at pointerLocation: NSPoint = NSEvent.mouseLocation) {
        pointerLocationAtScroll = pointerLocation
    }

    static func permitsHover(at pointerLocation: NSPoint = NSEvent.mouseLocation) -> Bool {
        guard let scrollLocation = pointerLocationAtScroll else { return true }
        let distance = hypot(
            pointerLocation.x - scrollLocation.x,
            pointerLocation.y - scrollLocation.y
        )
        guard distance >= movementThreshold else { return false }
        pointerLocationAtScroll = nil
        return true
    }

    static func resumeAfterMouseMove(at pointerLocation: NSPoint = NSEvent.mouseLocation) -> Bool {
        guard pointerLocationAtScroll != nil else { return false }
        return permitsHover(at: pointerLocation)
    }

    static func reset() {
        pointerLocationAtScroll = nil
    }
}

enum ToolbarDragGhostPresentation {
    static let minimumEdge: CGFloat = 38
    static let cursorOverlap: CGFloat = 4
    static let shadowInset: CGFloat = 8

    static func size(for sourceSize: NSSize) -> NSSize {
        NSSize(
            width: max(minimumEdge, sourceSize.width),
            height: max(minimumEdge, sourceSize.height)
        )
    }

    static func ghostFrame(cursorPoint point: NSPoint, ghostSize: NSSize) -> NSRect {
        NSRect(
            x: point.x - ghostSize.width / 2,
            y: point.y - cursorOverlap,
            width: ghostSize.width,
            height: ghostSize.height
        )
    }

    static func panelFrame(cursorPoint point: NSPoint, ghostSize: NSSize) -> NSRect {
        ghostFrame(cursorPoint: point, ghostSize: ghostSize)
            .insetBy(dx: -shadowInset, dy: -shadowInset)
    }
}

/// A transparent, mouse-ignoring window that keeps the dragged icon above both
/// the settings window and its hidden-tools child panel.
final class ToolbarDragGhostOverlay {
    let panel: NSPanel
    let ghost: NSView

    init(ghost: NSView) {
        self.ghost = ghost
        let panelSize = NSSize(
            width: ghost.frame.width + ToolbarDragGhostPresentation.shadowInset * 2,
            height: ghost.frame.height + ToolbarDragGhostPresentation.shadowInset * 2
        )
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary]

        let content = NSView(frame: NSRect(origin: .zero, size: panelSize))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        ghost.frame.origin = NSPoint(
            x: ToolbarDragGhostPresentation.shadowInset,
            y: ToolbarDragGhostPresentation.shadowInset
        )
        content.addSubview(ghost)
        panel.contentView = content
    }

    var ghostFrameOnScreen: NSRect {
        panel.frame.insetBy(
            dx: ToolbarDragGhostPresentation.shadowInset,
            dy: ToolbarDragGhostPresentation.shadowInset
        )
    }

    func show(at screenPoint: NSPoint) {
        move(to: screenPoint)
        panel.orderFrontRegardless()
    }

    func move(to screenPoint: NSPoint) {
        panel.setFrame(
            ToolbarDragGhostPresentation.panelFrame(
                cursorPoint: screenPoint,
                ghostSize: ghost.frame.size
            ),
            display: true
        )
    }

    func close() {
        panel.orderOut(nil)
    }
}

// MARK: - Tool tile

enum ToolbarSlotLayoutMode: Equatable {
    case grid
    case horizontalPreview
    case verticalPreview

    var isPreview: Bool {
        self != .grid
    }
}

/// A single draggable tool icon in a `ToolbarSlotGridView`. Pressing it
/// starts a drag handled by the owning grid.
final class ToolbarItemTile: NSView {
    static let previewIconPointSize: CGFloat = 15

    let itemID: ToolbarItemID
    weak var grid: ToolbarSlotGridView?
    let layoutMode: ToolbarSlotLayoutMode
    private let isDragPreview: Bool
    private var hoverTip: String?
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet {
            if oldValue != isHovered {
                needsDisplay = true
            }
        }
    }

    init(
        itemID: ToolbarItemID,
        layoutMode: ToolbarSlotLayoutMode = .grid,
        isDragPreview: Bool = false
    ) {
        self.itemID = itemID
        self.layoutMode = layoutMode
        self.isDragPreview = isDragPreview
        super.init(frame: .zero)
        wantsLayer = true
        refreshTooltip()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    func refreshTooltip() {
        hoverTip = itemID.tooltip
    }

    func clearTooltip() {
        hoverTip = nil
        ToolTipWindow.hide()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverTrackingArea {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        guard ToolbarTooltipHoverGate.permitsHover() else {
            ToolTipWindow.hide()
            return
        }
        showTooltip()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard ToolbarTooltipHoverGate.resumeAfterMouseMove() else { return }
        showTooltip()
    }

    private func showTooltip() {
        guard let tip = hoverTip, let window else { return }
        let frameInWindow = convert(bounds, to: nil)
        let frameOnScreen = window.convertToScreen(frameInWindow)
        ToolTipWindow.show(text: tip, anchor: frameOnScreen, relativeTo: window)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        ToolTipWindow.hide()
    }

    override func mouseDown(with event: NSEvent) {
        ToolTipWindow.hide()
        grid?.beginDrag(from: self, startEvent: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            ToolTipWindow.hide()
        }
    }

    private var iconColor: NSColor {
        switch itemID {
        case .close:   return toolbarDangerRed
        case .confirm: return accentGreen
        default:       return NSColor.white.withAlphaComponent(0.85)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let body = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            xRadius: isDragPreview ? 8 : (layoutMode.isPreview ? 5 : 7),
            yRadius: isDragPreview ? 8 : (layoutMode.isPreview ? 5 : 7)
        )
        if isDragPreview {
            NSColor(white: 0.18, alpha: 0.98).setFill()
            body.fill()
            NSColor.white.withAlphaComponent(0.18).setStroke()
            body.lineWidth = 1
            body.stroke()
        } else if layoutMode.isPreview {
            if isHovered {
                NSColor.white.withAlphaComponent(0.10).setFill()
                body.fill()
            }
        } else {
            NSColor.white.withAlphaComponent(0.08).setFill()
            body.fill()
            NSColor.white.withAlphaComponent(0.10).setStroke()
            body.lineWidth = 1
            body.stroke()
        }

        let iconPointSize: CGFloat = isDragPreview
            ? 18
            : (layoutMode.isPreview ? Self.previewIconPointSize : 15)
        if let icon = tintedToolbarIcon(itemID, pointSize: iconPointSize, color: iconColor) {
            let size = icon.size
            icon.draw(in: NSRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            ))
        }
    }
}

// MARK: - Slot grid

/// A wrapping grid of tool tiles for one toolbar section, with drag-and-drop
/// reordering both within the grid and across sibling grids.
final class ToolbarSlotGridView: NSView {
    static let tile: CGFloat = 34
    static let gap: CGFloat = 8
    static let previewTile: CGFloat = 24
    static let previewGap: CGFloat = 3
    static let previewPadding: CGFloat = 6

    let section: ToolbarSection
    let layoutMode: ToolbarSlotLayoutMode
    let maximumItemCount: Int?
    private(set) var items: [ToolbarItemID] = []

    /// Fired after a drag-and-drop edit changes any grid's contents.
    var onLayoutChanged: (() -> Void)?
    /// Supplies all sibling grids so a drag can move tiles across sections.
    var gridProvider: (() -> [ToolbarSlotGridView])?

    /// Insertion point shown during a drag (`nil` when not a drop target).
    var dropIndicator: Int? {
        didSet { if oldValue != dropIndicator { needsLayout = true; needsDisplay = true } }
    }

    private var tiles: [ToolbarItemTile] = []
    private var heightConstraint: NSLayoutConstraint!
    private(set) var columns: Int = 10
    private var animateNextLayout = false
    private let fixedGridColumns: Int?
    private let fixedGridRows: Int?

    init(
        section: ToolbarSection,
        layoutMode: ToolbarSlotLayoutMode = .grid,
        fixedGridColumns: Int? = nil,
        fixedGridRows: Int? = nil,
        maximumItemCount: Int? = nil
    ) {
        self.section = section
        self.layoutMode = layoutMode
        self.fixedGridColumns = fixedGridColumns
        self.fixedGridRows = fixedGridRows
        self.maximumItemCount = maximumItemCount
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        heightConstraint = heightAnchor.constraint(equalToConstant: initialHeight)
        heightConstraint.isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    // MARK: Contents

    func setItems(
        _ newItems: [ToolbarItemID],
        animated: Bool = false,
        initialFrames: [ToolbarItemID: NSRect] = [:]
    ) {
        items = newItems
        // Reuse existing tiles by id so layout changes can animate.
        var cache = Dictionary(tiles.map { ($0.itemID, $0) }, uniquingKeysWith: { a, _ in a })
        var reordered: [ToolbarItemTile] = []
        var created = Set<ToolbarItemID>()
        for id in newItems {
            if let existing = cache.removeValue(forKey: id) {
                reordered.append(existing)
            } else {
                let tile = ToolbarItemTile(itemID: id, layoutMode: layoutMode)
                tile.grid = self
                if let frame = initialFrames[id] {
                    tile.frame = frame
                } else if bounds.width > 0 {
                    columns = currentColumns()
                    tile.frame = slotFrame(at: reordered.count)
                }
                addSubview(tile)
                reordered.append(tile)
                created.insert(id)
            }
        }
        for (_, leftover) in cache { leftover.removeFromSuperview() }
        tiles = reordered
        refreshTooltips()
        // Newly created tiles without an explicit drag-start frame get their
        // final frame immediately so they don't animate in from the origin.
        if bounds.width > 0 {
            columns = currentColumns()
            for (index, tile) in tiles.enumerated()
            where created.contains(tile.itemID)
                && initialFrames[tile.itemID] == nil
                && tile.frame == .zero {
                tile.frame = slotFrame(at: index)
            }
        }
        animateNextLayout = animated
        needsLayout = true
        needsDisplay = true
    }

    func refreshTooltips() {
        for tile in tiles {
            tile.refreshTooltip()
        }
    }

    // MARK: Geometry

    private var tileSize: CGFloat {
        layoutMode.isPreview ? Self.previewTile : Self.tile
    }

    private var itemGap: CGFloat {
        layoutMode.isPreview ? Self.previewGap : Self.gap
    }

    private var contentInset: CGFloat {
        layoutMode.isPreview ? Self.previewPadding : 0
    }

    private var initialHeight: CGFloat {
        switch layoutMode {
        case .grid:
            return rowHeight(rows: fixedGridRows ?? 2)
        case .horizontalPreview, .verticalPreview:
            return tileSize + contentInset * 2
        }
    }

    private func currentColumns() -> Int {
        switch layoutMode {
        case .grid:
            if let fixedGridColumns {
                return max(1, fixedGridColumns)
            }
            return max(1, Int((bounds.width + itemGap) / (tileSize + itemGap)))
        case .horizontalPreview:
            return max(1, items.count + (dropIndicator == nil ? 0 : 1))
        case .verticalPreview:
            return 1
        }
    }

    private func rowHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * tileSize
            + CGFloat(max(0, rows - 1)) * itemGap
            + contentInset * 2
    }

    /// Rows to display — at least 2, and always enough to show the drop bar.
    private var displayRows: Int {
        let slots = max(items.count, dropIndicator.map { $0 + 1 } ?? 0)
        switch layoutMode {
        case .grid:
            if let fixedGridRows {
                return max(1, fixedGridRows)
            }
            return max(2, Int(ceil(Double(slots) / Double(max(1, columns)))))
        case .horizontalPreview:
            return 1
        case .verticalPreview:
            return max(1, slots)
        }
    }

    var preferredContentSize: NSSize {
        let count = max(items.count, dropIndicator.map { $0 + 1 } ?? 0, 1)
        switch layoutMode {
        case .grid:
            return NSSize(width: bounds.width, height: rowHeight(rows: displayRows))
        case .horizontalPreview:
            return NSSize(
                width: CGFloat(count) * tileSize
                    + CGFloat(max(0, count - 1)) * itemGap
                    + contentInset * 2,
                height: tileSize + contentInset * 2
            )
        case .verticalPreview:
            return NSSize(
                width: tileSize + contentInset * 2,
                height: CGFloat(count) * tileSize
                    + CGFloat(max(0, count - 1)) * itemGap
                    + contentInset * 2
            )
        }
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0 else { return }
        columns = currentColumns()
        let animated = animateNextLayout
        animateNextLayout = false
        for (index, tile) in tiles.enumerated() {
            let frame = slotFrame(at: index)
            if animated {
                tile.animator().frame = frame
            } else {
                tile.frame = frame
            }
        }
        let height = rowHeight(rows: displayRows)
        if abs(heightConstraint.constant - height) > 0.5 {
            heightConstraint.constant = height
        }
    }

    /// Frame of the slot at a flow index (flipped: row 0 sits at the top).
    func slotFrame(at index: Int) -> NSRect {
        let col: Int
        let row: Int
        switch layoutMode {
        case .grid, .horizontalPreview:
            let cols = max(1, columns)
            col = index % cols
            row = index / cols
        case .verticalPreview:
            col = 0
            row = index
        }
        return NSRect(
            x: contentInset + CGFloat(col) * (tileSize + itemGap),
            y: contentInset + CGFloat(row) * (tileSize + itemGap),
            width: tileSize,
            height: tileSize
        )
    }

    /// Insertion index nearest a point in this grid's coordinate space.
    func insertionIndex(at point: NSPoint) -> Int {
        let cell = tileSize + itemGap
        let localX = max(0, point.x - contentInset)
        let localY = max(0, point.y - contentInset)
        let index: Int
        switch layoutMode {
        case .grid:
            let col = Int((localX + tileSize / 2) / cell)
            let row = max(0, Int(localY / cell))
            index = row * columns + min(max(0, col), columns)
        case .horizontalPreview:
            index = Int((localX + tileSize / 2) / cell)
        case .verticalPreview:
            index = Int((localY + tileSize / 2) / cell)
        }
        return min(max(0, index), items.count)
    }

    override func draw(_ dirtyRect: NSRect) {
        if layoutMode.isPreview {
            let body = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                xRadius: 8,
                yRadius: 8
            )
            NSColor(white: 0.12, alpha: 0.95).setFill()
            body.fill()
            NSColor.white.withAlphaComponent(0.10).setStroke()
            body.lineWidth = 1
            body.stroke()
        }

        // Empty placeholder slots out to the displayed row count.
        let total: Int
        switch layoutMode {
        case .grid:
            total = displayRows * columns
        case .horizontalPreview, .verticalPreview:
            total = items.isEmpty || dropIndicator != nil ? max(1, items.count + 1) : items.count
        }
        if items.count < total {
            NSColor.white.withAlphaComponent(0.12).setStroke()
            for index in items.count..<total {
                let rect = slotFrame(at: index).insetBy(dx: 1, dy: 1)
                let radius: CGFloat = layoutMode.isPreview ? 5 : 7
                let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
                path.lineWidth = 1
                path.setLineDash([3, 3], count: 2, phase: 0)
                path.stroke()
            }
        }

        // Drop insertion bar.
        if let indicator = dropIndicator {
            let slot = slotFrame(at: indicator)
            let bar: NSRect
            if layoutMode == .verticalPreview {
                bar = NSRect(
                    x: slot.minX,
                    y: slot.minY - itemGap / 2 - 1.5,
                    width: tileSize,
                    height: 3
                )
            } else {
                bar = NSRect(
                    x: slot.minX - itemGap / 2 - 1.5,
                    y: slot.minY,
                    width: 3,
                    height: tileSize
                )
            }
            accentGreen.setFill()
            NSBezierPath(roundedRect: bar, xRadius: 1.5, yRadius: 1.5).fill()
        }
    }

    // MARK: Drag & drop

    /// Runs a modal drag-tracking loop for `tile` until the mouse is released.
    func beginDrag(from tile: ToolbarItemTile, startEvent: NSEvent) {
        guard let trackingWindow = tile.window ?? window else { return }

        let grids = gridProvider?() ?? [self]
        let draggedID = tile.itemID
        let sourceGrid = self
        let sourceIndex = items.firstIndex(of: draggedID) ?? 0

        var ghostOverlay: ToolbarDragGhostOverlay?
        var dragging = false
        var targetGrid: ToolbarSlotGridView?
        var targetIndex = 0

        func startDrag() {
            dragging = true
            // Lift the tile out of its grid so every grid reflows around the gap.
            var src = sourceGrid.items
            if let idx = src.firstIndex(of: draggedID) {
                src.remove(at: idx)
                sourceGrid.setItems(src, animated: true)
            }
            let view = Self.makeGhost(
                for: draggedID,
                layoutMode: sourceGrid.layoutMode,
                size: tile.bounds.size
            )
            let overlay = ToolbarDragGhostOverlay(ghost: view)
            let startScreenPoint = trackingWindow.convertToScreen(
                NSRect(origin: startEvent.locationInWindow, size: .zero)
            ).origin
            overlay.show(at: startScreenPoint)
            ghostOverlay = overlay
            NSCursor.closedHand.set()
        }

        func positionGhost(_ event: NSEvent) {
            guard let ghostOverlay else { return }
            let screenPoint = trackingWindow.convertToScreen(
                NSRect(origin: event.locationInWindow, size: .zero)
            ).origin
            ghostOverlay.move(to: screenPoint)
        }

        trackingLoop: while true {
            guard let event = trackingWindow.nextEvent(matching: [.leftMouseDragged, .leftMouseUp])
            else { break }

            switch event.type {
            case .leftMouseDragged:
                if !dragging { startDrag() }
                positionGhost(event)
                let screenPoint = trackingWindow.convertToScreen(
                    NSRect(origin: event.locationInWindow, size: .zero)
                ).origin
                let hit = Self.dropTarget(screenPoint: screenPoint, grids: grids)
                targetGrid = hit.grid
                targetIndex = hit.index
                for grid in grids {
                    grid.dropIndicator = (grid === targetGrid) ? targetIndex : nil
                }
            case .leftMouseUp:
                break trackingLoop
            default:
                break
            }
        }

        let ghostFrameOnScreen = ghostOverlay?.ghostFrameOnScreen
        ghostOverlay?.close()
        for grid in grids { grid.dropIndicator = nil }
        NSCursor.arrow.set()

        guard dragging else { return }  // a plain click — nothing moved

        let destGrid = targetGrid ?? sourceGrid
        var destItems = destGrid.items
        // No target grid means the drop landed outside — restore the tile.
        let insertAt = targetGrid == nil
            ? min(sourceIndex, destItems.count)
            : min(max(0, targetIndex), destItems.count)
        destItems.insert(draggedID, at: insertAt)
        let initialFrame = ghostFrameOnScreen.flatMap {
            Self.convert(screenRect: $0, to: destGrid)
        }
        destGrid.setItems(
            destItems,
            animated: true,
            initialFrames: initialFrame.map { [draggedID: $0] } ?? [:]
        )
        onLayoutChanged?()
    }

    /// Finds the grid (and insertion index) under a screen-space point. Screen
    /// coordinates keep drag targeting correct when the hidden grid is hosted
    /// in a child panel rather than the settings window itself.
    private static func dropTarget(
        screenPoint: NSPoint,
        grids: [ToolbarSlotGridView]
    ) -> (grid: ToolbarSlotGridView?, index: Int) {
        for grid in grids {
            guard let gridWindow = grid.window else { continue }
            if let maximumItemCount = grid.maximumItemCount,
               grid.items.count >= maximumItemCount {
                continue
            }
            let windowPoint = gridWindow.convertFromScreen(
                NSRect(origin: screenPoint, size: .zero)
            ).origin
            let local = grid.convert(windowPoint, from: nil)
            if grid.visibleRect.insetBy(dx: -10, dy: -10).contains(local) {
                return (grid, grid.insertionIndex(at: local))
            }
        }
        return (nil, 0)
    }

    private static func convert(
        screenRect: NSRect,
        to destinationView: NSView
    ) -> NSRect? {
        guard let destinationWindow = destinationView.window else { return nil }
        let destinationWindowRect = destinationWindow.convertFromScreen(screenRect)
        return destinationView.convert(destinationWindowRect, from: nil)
    }

    /// A lifted copy of a tile that follows the cursor during a drag.
    private static func makeGhost(
        for id: ToolbarItemID,
        layoutMode: ToolbarSlotLayoutMode,
        size: NSSize
    ) -> NSView {
        let ghost = ToolbarItemTile(
            itemID: id,
            layoutMode: layoutMode,
            isDragPreview: true
        )
        ghost.clearTooltip()
        ghost.frame = NSRect(
            origin: .zero,
            size: ToolbarDragGhostPresentation.size(for: size)
        )
        ghost.alphaValue = 0.95
        ghost.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = 8
            shadow.shadowOffset = NSSize(width: 0, height: -3)
            return shadow
        }()
        return ghost
    }
}

// MARK: - Layout preview

/// A live toolbar editor embedded directly into the editor preview. Its main
/// and side drop zones are the same controls the user drags, so the preview is
/// the source of truth instead of a second rendering of the grids below it.
final class ToolbarLayoutPreviewView: NSView {
    var layout: ToolbarLayout = .default {
        didSet {
            invalidateIntrinsicContentSize()
            if primaryGrid.items != layout.primary {
                primaryGrid.setItems(layout.primary)
            }
            if sideGrid.items != layout.side {
                sideGrid.setItems(layout.side)
            }
            updateToolbarDropZones()
            needsDisplay = true
        }
    }

    var onLayoutChanged: (() -> Void)? {
        didSet {
            primaryGrid.onLayoutChanged = onLayoutChanged
            sideGrid.onLayoutChanged = onLayoutChanged
        }
    }

    var gridProvider: (() -> [ToolbarSlotGridView])? {
        didSet {
            primaryGrid.gridProvider = gridProvider
            sideGrid.gridProvider = gridProvider
        }
    }

    let primaryGrid = ToolbarSlotGridView(
        section: .primary,
        layoutMode: .horizontalPreview
    )
    let sideGrid = ToolbarSlotGridView(
        section: .side,
        layoutMode: .verticalPreview
    )

    var primaryItems: [ToolbarItemID] { primaryGrid.items }
    var sideItems: [ToolbarItemID] { sideGrid.items }

    private let primaryScrollView = ToolbarPreviewScrollView(orientation: .horizontal)
    private let sideScrollView = ToolbarPreviewScrollView(orientation: .vertical)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = 8
        identifier = NSUserInterfaceItemIdentifier("toolbar-layout-preview")
        primaryGrid.identifier = NSUserInterfaceItemIdentifier("toolbar-primary-drop-zone")
        sideGrid.identifier = NSUserInterfaceItemIdentifier("toolbar-side-drop-zone")
        primaryGrid.translatesAutoresizingMaskIntoConstraints = true
        sideGrid.translatesAutoresizingMaskIntoConstraints = true
        primaryScrollView.documentView = primaryGrid
        sideScrollView.documentView = sideGrid
        addSubview(primaryScrollView)
        addSubview(sideScrollView)
        primaryGrid.setItems(layout.primary)
        sideGrid.setItems(layout.side)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static let desktopMenuBarHeight: CGFloat = 22
    static let selectionMenuBarGap: CGFloat = 10
    static let selectionTopInset = desktopMenuBarHeight + selectionMenuBarGap
    static let selectionBottomInset: CGFloat = 94
    static let primaryToolbarGap: CGFloat = 10

    private let fixedHeight: CGFloat = 450
    private let previewMargin: CGFloat = 14

    var preferredHeight: CGFloat {
        fixedHeight
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: preferredHeight)
    }

    private var capsuleThickness: CGFloat {
        ToolbarSlotGridView.previewTile + ToolbarSlotGridView.previewPadding * 2
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateToolbarDropZones()
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        updateToolbarDropZones()
    }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds

        drawDesktop(in: b)

        let selection = selectionRect(in: b)
        guard selection.width > 20, selection.height > 20 else { return }

        let dimmingPath = NSBezierPath(rect: b)
        dimmingPath.appendRect(selection)
        dimmingPath.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.38).setFill()
        dimmingPath.fill()

        let dashed = NSBezierPath(rect: selection)
        dashed.lineWidth = CaptureSelectionChrome.borderWidth
        dashed.setLineDash(
            CaptureSelectionChrome.dashPattern,
            count: CaptureSelectionChrome.dashPattern.count,
            phase: 0
        )
        CaptureSelectionChrome.accentColor.setStroke()
        dashed.stroke()
        drawHandles(around: selection)
    }

    private func drawDesktop(in rect: NSRect) {
        if let gradient = NSGradient(colors: [
            NSColor(srgbRed: 0.10, green: 0.16, blue: 0.34, alpha: 1),
            NSColor(srgbRed: 0.23, green: 0.34, blue: 0.62, alpha: 1),
            NSColor(srgbRed: 0.10, green: 0.49, blue: 0.53, alpha: 1),
        ]) {
            gradient.draw(in: rect, angle: -72)
        }

        drawWallpaperShapes(in: rect)
        drawDesktopMenuBar(in: rect)
        drawDesktopItems(in: rect)
        drawDesktopDock(in: rect)
    }

    private func drawWallpaperShapes(in rect: NSRect) {
        let glow = NSBezierPath(ovalIn: NSRect(
            x: rect.maxX - rect.width * 0.42,
            y: rect.maxY - rect.height * 0.50,
            width: rect.width * 0.54,
            height: rect.height * 0.60
        ))
        NSColor(srgbRed: 0.54, green: 0.33, blue: 0.78, alpha: 0.32).setFill()
        glow.fill()

        let lowerWave = NSBezierPath()
        lowerWave.move(to: NSPoint(x: rect.minX, y: rect.minY))
        lowerWave.line(to: NSPoint(x: rect.minX, y: rect.minY + rect.height * 0.28))
        lowerWave.curve(
            to: NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38),
            controlPoint1: NSPoint(
                x: rect.minX + rect.width * 0.34,
                y: rect.minY + rect.height * 0.48
            ),
            controlPoint2: NSPoint(
                x: rect.minX + rect.width * 0.70,
                y: rect.minY + rect.height * 0.16
            )
        )
        lowerWave.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        lowerWave.close()
        NSColor(srgbRed: 0.03, green: 0.55, blue: 0.55, alpha: 0.40).setFill()
        lowerWave.fill()
    }

    private func drawDesktopMenuBar(in rect: NSRect) {
        let menuBar = NSRect(
            x: rect.minX,
            y: rect.maxY - Self.desktopMenuBarHeight,
            width: rect.width,
            height: Self.desktopMenuBarHeight
        )
        NSColor.black.withAlphaComponent(0.22).setFill()
        menuBar.fill()

        NSColor.white.withAlphaComponent(0.72).setFill()
        NSBezierPath(
            ovalIn: NSRect(x: rect.minX + 12, y: menuBar.midY - 3, width: 6, height: 6)
        ).fill()
        for offset in [28.0, 40.0, 52.0] {
            NSBezierPath(
                roundedRect: NSRect(
                    x: rect.minX + offset,
                    y: menuBar.midY - 1.5,
                    width: 7,
                    height: 3
                ),
                xRadius: 1.5,
                yRadius: 1.5
            ).fill()
        }

        for offset in [14.0, 28.0, 42.0] {
            NSBezierPath(
                ovalIn: NSRect(x: rect.maxX - offset, y: menuBar.midY - 2, width: 4, height: 4)
            ).fill()
        }
    }

    private func drawDesktopItems(in rect: NSRect) {
        let itemOrigins = [
            NSPoint(x: rect.maxX - 54, y: rect.maxY - 78),
            NSPoint(x: rect.maxX - 54, y: rect.maxY - 128),
        ]
        for (index, origin) in itemOrigins.enumerated() {
            let body = NSRect(x: origin.x, y: origin.y, width: 24, height: 20)
            let color = index == 0
                ? NSColor(srgbRed: 0.35, green: 0.68, blue: 0.98, alpha: 0.90)
                : NSColor.white.withAlphaComponent(0.82)
            color.setFill()
            NSBezierPath(roundedRect: body, xRadius: 4, yRadius: 4).fill()
            NSColor.white.withAlphaComponent(0.30).setFill()
            NSBezierPath(
                roundedRect: NSRect(
                    x: body.minX + 4,
                    y: body.maxY - 6,
                    width: 10,
                    height: 3
                ),
                xRadius: 1.5,
                yRadius: 1.5
            ).fill()
        }
    }

    private func drawDesktopDock(in rect: NSRect) {
        let dock = NSRect(
            x: rect.midX - 112,
            y: rect.minY + 7,
            width: 224,
            height: 28
        )
        NSColor.black.withAlphaComponent(0.28).setFill()
        NSBezierPath(roundedRect: dock, xRadius: 10, yRadius: 10).fill()
        NSColor.white.withAlphaComponent(0.14).setStroke()
        let dockBorder = NSBezierPath(roundedRect: dock, xRadius: 10, yRadius: 10)
        dockBorder.lineWidth = 1
        dockBorder.stroke()

        let colors: [NSColor] = [
            .systemBlue, .systemPurple, .systemPink, .systemOrange,
            .systemGreen, .systemTeal, .systemIndigo,
        ]
        let iconEdge: CGFloat = 18
        let iconGap: CGFloat = 7
        let totalWidth = CGFloat(colors.count) * iconEdge + CGFloat(colors.count - 1) * iconGap
        var x = dock.midX - totalWidth / 2
        for color in colors {
            color.withAlphaComponent(0.92).setFill()
            NSBezierPath(
                roundedRect: NSRect(
                    x: x,
                    y: dock.midY - iconEdge / 2,
                    width: iconEdge,
                    height: iconEdge
                ),
                xRadius: 4,
                yRadius: 4
            ).fill()
            x += iconEdge + iconGap
        }
    }

    /// Selection rect leaves room below for the primary toolbar and to the
    /// right for the side toolbar.
    func selectionRect(in bounds: NSRect) -> NSRect {
        NSRect(
            x: bounds.minX + 44,
            y: bounds.minY + Self.selectionBottomInset,
            width: bounds.width - 44 - 70,
            height: bounds.height - Self.selectionBottomInset - Self.selectionTopInset
        )
    }

    private func updateToolbarDropZones() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let selection = selectionRect(in: bounds)

        updatePrimaryDropZone(selection: selection)
        updateSideDropZone(selection: selection)
    }

    private func updatePrimaryDropZone(selection: NSRect) {
        let contentSize = primaryGrid.preferredContentSize
        let run = contentSize.width
        let maxWidth = max(capsuleThickness, bounds.width - previewMargin * 2)
        let width = min(run, maxWidth)
        let proposedX = selection.midX - width / 2
        let x = max(previewMargin, min(bounds.maxX - previewMargin - width, proposedX))
        primaryScrollView.frame = NSRect(
            x: x,
            y: selection.minY - Self.primaryToolbarGap - capsuleThickness,
            width: width,
            height: capsuleThickness
        )
        primaryGrid.setFrameSize(contentSize)
        primaryScrollView.clampScrollOffset()
    }

    private func updateSideDropZone(selection: NSRect) {
        let contentSize = sideGrid.preferredContentSize
        let run = contentSize.height
        let height = min(run, max(capsuleThickness, selection.height))
        sideScrollView.frame = NSRect(
            x: selection.maxX + 10,
            y: selection.midY - height / 2,
            width: capsuleThickness,
            height: height
        )
        sideGrid.setFrameSize(contentSize)
        sideScrollView.clampScrollOffset()
    }

    private func drawHandles(around rect: NSRect) {
        let points = [
            NSPoint(x: rect.minX, y: rect.minY), NSPoint(x: rect.midX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY), NSPoint(x: rect.minX, y: rect.midY),
            NSPoint(x: rect.maxX, y: rect.midY), NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.midX, y: rect.maxY), NSPoint(x: rect.maxX, y: rect.maxY),
        ]
        CaptureSelectionChrome.accentColor.setFill()
        for point in points {
            let edge = CaptureSelectionChrome.handleSize
            let dot = NSRect(
                x: point.x - edge / 2,
                y: point.y - edge / 2,
                width: edge,
                height: edge
            )
            NSBezierPath(ovalIn: dot).fill()
        }
    }
}

private final class ToolbarPreviewScrollView: NSScrollView {
    private let orientation: ToolbarView.Orientation

    init(orientation: ToolbarView.Orientation) {
        self.orientation = orientation
        super.init(frame: .zero)
        borderType = .noBorder
        drawsBackground = false
        autohidesScrollers = true
        scrollerStyle = .overlay
        hasHorizontalScroller = orientation.isHorizontal
        hasVerticalScroller = orientation.isVertical
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        usesPredominantAxisScrolling = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func clampScrollOffset() {
        guard let documentView else { return }
        let maxX = max(0, documentView.frame.width - contentView.bounds.width)
        let maxY = max(0, documentView.frame.height - contentView.bounds.height)
        var origin = contentView.bounds.origin
        origin.x = max(0, min(maxX, origin.x))
        origin.y = max(0, min(maxY, origin.y))
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }
}

private extension ToolbarView.Orientation {
    var isHorizontal: Bool {
        if case .horizontal = self { return true }
        return false
    }

    var isVertical: Bool { !isHorizontal }
}
