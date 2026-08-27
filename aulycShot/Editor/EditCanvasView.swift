import AppKit

class EditCanvasView: NSView {
    private static let fallbackShapePreviewSeed: UInt64 = 0xC0DEC0DEC0DEC0DE

    var captureRect: CGRect?
    var captureScreen: NSScreen?
    var preSnapshot: CGImage?
    /// When set (image-edit mode), this image is the source-of-truth base
    /// instead of preSnapshot/live capture.
    var overrideBaseImage: NSImage?
    /// Exact clicked-window image, including the WindowServer alpha mask.
    var windowBaseImage: NSImage?
    var activeTool: EditTool = .none {
        didSet {
            if oldValue == .text, activeTool != .text {
                activeTextField?.commit()
            }
            if oldValue == .eraser, activeTool != .eraser {
                if eraserSelection?.didDelete != true {
                    discardPendingUndo()
                }
                eraserSelection = nil
            }
            if activeTool == .eraser {
                selectedIndex = nil
            }
            if activeTool != .rectangle && activeTool != .ellipse {
                shapeRoughSeed = nil
            }
            // Tool changes must route through the host selection first. A
            // direct canvas refresh can leave the eraser/loupe cursor visible
            // while the pointer is over a toolbar outside the screenshot.
            if let onCursorRefreshRequested {
                onCursorRefreshRequested()
            } else {
                refreshCursorAtCurrentLocation()
            }
        }
    }
    // Current drawing properties (set by toolbar)
    var currentColor: NSColor = EditorStyleDefaults.primaryColor {
        didSet { activeTextField?.annotationColor = currentColor }
    }
    /// Whether new text annotations get a contrast outline.
    var currentTextStroke: Bool = Defaults.lastTextStroke {
        didSet { activeTextField?.hasStroke = currentTextStroke }
    }
    /// Whether new text annotations render as callout bubbles with an arrow handle.
    var currentTextCallout: Bool = Defaults.lastTextCallout {
        didSet { activeTextField?.hasCallout = currentTextCallout }
    }
    /// Fill mode for newly drawn rectangles/ellipses.
    var currentShapeFillMode: ShapeFillMode = Defaults.lastShapeFillMode
    /// Border style for newly drawn rectangles/ellipses.
    var currentShapeStrokeStyle: ShapeStrokeStyle = .standard
    var currentLineWidth: CGFloat = EditorStyleDefaults.standardLineWidth
    var currentArrowStyle: ArrowStyle = .line
    /// Base width for the marker brush. Drawn at `× MarkerAnnotation.brushScale`.
    var currentMarkerLineWidth: CGFloat = EditorStyleDefaults.markerLineWidth
    /// Marker uses a separate color slot so switching tools keeps the
    /// highlighter's yellow without overriding the pen's red, and vice-versa.
    var currentMarkerColor: NSColor = EditorStyleDefaults.markerColor
    var currentMosaicBlockSize: CGFloat = CGFloat(Defaults.mosaicBlockSize)
    var currentFontSize: CGFloat = CGFloat(Defaults.lastTextFontSize) {
        didSet {
            guard let field = activeTextField else { return }
            field.font = NSFont.systemFont(ofSize: currentFontSize, weight: .bold)
            field.sizeToFitText()
        }
    }
    // Annotations stack (supports undo)
    private var annotations: [Annotation] = []

    // In-progress drawing state — pen and marker collect raw mouse points
    // and rebuild a smoothed bezier on every change so the live preview
    // matches the committed annotation.
    private var currentPenPoints: [NSPoint]?
    private var currentMarkerPoints: [NSPoint]?
    private var shapeStart: NSPoint?
    private var shapeCurrent: NSPoint?
    private var shapeRoughSeed: UInt64?
    /// Base image snapshot captured when a magnifier drag begins, reused for
    /// both the live preview and the committed lens so the (possibly
    /// expensive) base-image lookup happens only once per drag.
    private var magnifierBaseImage: NSImage?
    private var numberCounter: Int = 1
    private var activeTextField: EditableTextField?
    /// When editing an existing text annotation, we remove it from the
    /// `annotations` array so it isn't drawn under the editor and stash the
    /// original here. On commit it's discarded; on cancel/Esc it's reinserted
    /// at its original index.
    private var editingOriginalAnnotation: TextAnnotation?
    private var editingOriginalIndex: Int?
    /// Active drag interaction on a committed annotation. Captured in
    /// `mouseDown` regardless of which tool is active — clicking on any
    /// existing draggable annotation always starts a drag, so the user can
    /// reposition marks without first deselecting their tool.
    private var dragState: DragState?
    /// Pending number creation. `start` is the click point (badge center);
    /// `current` follows the drag, becoming the arrow tip on commit. When
    /// the cursor never moves, tip stays at start so the badge commits
    /// without an arrow.
    private var pendingNumberCreate: PendingNumberCreate?
    /// Pending text creation — same idea as number, plus a `wasEditing` flag
    /// so a click that just committed an in-progress field doesn't pop a new
    /// one.
    private var pendingTextCreate: PendingTextCreate?
    private var hoveredAnnotationIndex: Int?
    /// Active eraser drag rectangle. Matching annotations are removed as
    /// soon as they intersect the rectangle.
    private var eraserSelection: EraserSelection?
    private let dragThreshold: CGFloat = 4
    /// Primary selected annotation. Existing single-selection paths read this
    /// value for sub-toolbar seeding and handle editing, while `selectedIndexes`
    /// carries the full multi-selection set.
    private var selectedIndex: Int? {
        get { primarySelectedIndex }
        set {
            if let newValue {
                setSelectedIndexes([newValue], primary: newValue)
            } else {
                setSelectedIndexes([], primary: nil)
            }
        }
    }
    private var selectedIndexes: Set<Int> = []
    private var primarySelectedIndex: Int?
    private var hasSelection: Bool { !selectedIndexes.isEmpty }
    private var validSelectedIndexes: [Int] {
        selectedIndexes.filter { annotations.indices.contains($0) }.sorted()
    }
    private var selectedAnnotationForChrome: Annotation? {
        guard
            selectedIndexes.count == 1,
            let index = selectedIndex,
            annotations.indices.contains(index)
        else { return nil }
        return annotations[index]
    }

    /// Fired when the selected annotation identity changes — non-nil when a
    /// selection is gained, nil when the selection clears. Used by the
    /// controller to switch the active tool / sub-toolbar to match the
    /// selected annotation and seed it with that annotation's properties.
    var onAnnotationSelected: ((Annotation?) -> Void)?
    /// Fired when selection enters or leaves multi-select mode. The editor
    /// controller uses this to hide sub-toolbars and clear active tools only
    /// for true multi-selection, without disrupting normal drawing flows.
    var onMultiSelectionChanged: ((Bool) -> Void)?
    /// Fired whenever undo / redo availability changes so toolbar buttons can
    /// reflect the real history state instead of acting as no-op controls.
    var onHistoryStateChanged: ((Bool, Bool) -> Void)?
    /// Requests an immediate cursor refresh after the active tool changes.
    /// The editor controller routes this through `SelectionView` so custom
    /// tool cursors never leak outside the screenshot region.
    var onCursorRefreshRequested: (() -> Void)?
    private func notifySelectionChanged() {
        guard let cb = onAnnotationSelected else { return }
        if selectedIndexes.count == 1, let idx = selectedIndex, idx < annotations.count {
            cb(annotations[idx])
        } else {
            cb(nil)
        }
    }

    private func setSelectedIndexes(_ indexes: Set<Int>, primary: Int? = nil) {
        let wasMultiSelecting = selectedIndexes.count > 1
        let validIndexes = Set(indexes.filter { annotations.indices.contains($0) })
        let resolvedPrimary: Int?
        if let primary, validIndexes.contains(primary) {
            resolvedPrimary = primary
        } else if let current = primarySelectedIndex, validIndexes.contains(current) {
            resolvedPrimary = current
        } else {
            resolvedPrimary = validIndexes.max()
        }

        let changed = validIndexes != selectedIndexes || resolvedPrimary != primarySelectedIndex
        selectedIndexes = validIndexes
        primarySelectedIndex = resolvedPrimary
        if changed {
            needsDisplay = true
            let isMultiSelecting = validIndexes.count > 1
            if wasMultiSelecting != isMultiSelecting {
                onMultiSelectionChanged?(isMultiSelecting)
            }
            notifySelectionChanged()
        }
    }

    private func toggleSelection(of index: Int) {
        var next = selectedIndexes
        if next.contains(index) {
            next.remove(index)
            setSelectedIndexes(next)
        } else {
            next.insert(index)
            setSelectedIndexes(next, primary: index)
        }
    }

    @discardableResult
    func clearMultiSelection() -> Bool {
        guard selectedIndexes.count > 1 else { return false }
        selectedIndex = nil
        return true
    }

    private var handleDragState: HandleDragState?

    private struct DragState {
        let index: Int
        let startMouse: NSPoint
        let originals: [Int: Annotation]
        var didDrag: Bool
    }

    private func annotationForBodyDrag(_ annotation: Annotation, by delta: NSPoint) -> Annotation {
        if let magnifier = annotation as? MagnifierAnnotation {
            return magnifier.translatedPreservingSourceFocus(by: delta)
        }
        if let text = annotation as? TextAnnotation {
            return text.translatedBodyPreservingCalloutTip(by: delta)
        }
        return annotation.translated(by: delta)
    }

    private struct PendingTextCreate {
        let start: NSPoint
        var current: NSPoint
        let wasEditing: Bool
    }

    private struct PendingNumberCreate {
        let start: NSPoint
        var current: NSPoint
    }

    private struct EraserSelection {
        let start: NSPoint
        var current: NSPoint
        var didDelete: Bool
    }

    typealias ResizeAnchor = EditorCanvasGeometry.ResizeAnchor

    /// Active drag on a selection handle (rotate / curve / number tip /
    /// magnifier source / resize). The original annotation is captured so
    /// escape-style cancellations (e.g. tool switch mid-drag) can restore it
    /// cleanly.
    private struct HandleDragState {
        let kind: AnnotationHitTesting.Handle
        let index: Int
        let original: Annotation
        let startMouse: NSPoint
        /// For rotate: the angle from annotation center to startMouse,
        /// captured at mouseDown so the rotation delta is anchored.
        let startAngle: CGFloat
        /// For rotate: the original rotation captured at mouseDown.
        let startRotation: CGFloat
    }

    private static let hoverBoxPad: CGFloat = 5
    private static let hoverColor = NSColor(calibratedRed: 0.0, green: 0.56, blue: 1.0, alpha: 1.0)

    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // While a tool is active, the canvas always captures clicks.
        if activeTool != .none {
            return super.hitTest(point)
        }
        // In adjust mode we want to capture clicks that land on either an
        // existing draggable annotation, a drag handle (rotate / curve /
        // tip), or an action button (delete / edit). Handles and buttons
        // can sit outside the annotation body — without this, the click
        // falls through to the SelectionView and we never see a mouseDown.
        let local = convert(point, from: superview)
        if AnnotationHitTesting.topmostIndex(at: local, in: annotations) != nil {
            return super.hitTest(point)
        }
        if let annotation = selectedAnnotationForChrome,
           AnnotationHitTesting.chromeHit(at: local, for: annotation) != nil {
            return super.hitTest(point)
        }
        // Empty-canvas click in adjust mode normally falls through to
        // SelectionView so the user can re-crop. But when there's a
        // selection or in-progress text edit to dismiss, capture the
        // click so mouseDown can clear that chrome / commit the field.
        if hasSelection || activeTextField != nil {
            if bounds.contains(local) {
                return super.hitTest(point)
            }
        }
        return nil
    }

    /// Re-enter inline edit mode for an existing text annotation by removing
    /// the original from the canvas and creating a fresh editable text field
    /// at the same position with the same text pre-filled. On commit the new
    /// content replaces it; on cancel the original is reinserted.
    ///
    /// **Deferred to the next runloop tick on purpose.** Calling
    /// `makeFirstResponder` from inside a mouseDown stack frame can cause
    /// AppKit to immediately resign the new field once the surrounding
    /// mouse-event dispatch finishes — `controlTextDidEndEditing` then fires
    /// and our commit handler tears the field back down before the user
    /// sees it. Posting async lets the click finish dispatching first; the
    /// field is then created against a quiescent run loop and stays put.
    private func reEditTextAnnotation(at index: Int, annotation: TextAnnotation) {
        // The source annotation is briefly removed from the array while the
        // editor is open, so any stale selection on it would point at the
        // wrong row. Drop it before starting the edit.
        selectedIndex = nil
        DispatchQueue.main.async { [weak self] in
            self?.beginTextEditing(
                bottomLeft: annotation.origin,
                fontSize: annotation.fontSize,
                color: annotation.color,
                hasStroke: annotation.hasStroke,
                hasCallout: annotation.hasCallout,
                calloutTip: annotation.calloutTip,
                initialText: annotation.text,
                rotation: annotation.rotation,
                replacingIndex: index
            )
        }
    }

    // MARK: - Undo / Redo

    struct RestorableState {
        fileprivate let annotations: [Annotation]
        fileprivate let numberCounter: Int
        fileprivate let selectedIndexes: Set<Int>
        fileprivate let primarySelectedIndex: Int?
        fileprivate let history: UndoHistory<EditorSnapshot>
    }

    /// History snapshot. Annotations are value-typed (struct) so a plain
    /// array copy is a deep copy of the editor's logical state. The number
    /// counter is included so undo/redo also restores the next-badge value.
    fileprivate struct EditorSnapshot {
        let annotations: [Annotation]
        let numberCounter: Int
    }

    private var history = UndoHistory<EditorSnapshot>()
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }
    /// Stash for drag-style operations and text edits — captured before the
    /// mutation begins, then either committed (drag actually moved / text
    /// edit produced a change) or discarded (just a click / cancel).
    private var pendingSnapshot: EditorSnapshot?
    private static var annotationPasteboard: [Annotation] = []
    private static let defaultPasteOffset = NSPoint(x: 12, y: -12)

    private func currentSnapshot() -> EditorSnapshot {
        EditorSnapshot(annotations: annotations, numberCounter: numberCounter)
    }

    func restorableState() -> RestorableState {
        activeTextField?.commit()
        return RestorableState(
            annotations: annotations,
            numberCounter: numberCounter,
            selectedIndexes: selectedIndexes,
            primarySelectedIndex: primarySelectedIndex,
            history: history
        )
    }

    func restoreState(_ state: RestorableState) {
        cancelInFlightInteraction()
        annotations = state.annotations
        numberCounter = state.numberCounter
        history = state.history
        setSelectedIndexes(state.selectedIndexes, primary: state.primarySelectedIndex)
        needsDisplay = true
        notifyHistoryStateChanged()
        refreshCursorAtCurrentLocation()
    }

    private func apply(_ snapshot: EditorSnapshot) {
        annotations = snapshot.annotations
        numberCounter = snapshot.numberCounter
        setSelectedIndexes(selectedIndexes, primary: primarySelectedIndex)
    }

    /// Push current state onto the undo stack and clear the redo stack.
    /// Call BEFORE any direct, instantaneous mutation (creation / deletion
    /// / text edit commit).
    private func recordUndo() {
        history.record(currentSnapshot())
        notifyHistoryStateChanged()
    }

    /// Stash current state for a drag-style operation. Pair with
    /// `commitPendingUndo()` (drag actually moved) or `discardPendingUndo()`
    /// (just a click / cancel).
    private func captureUndoForPending() {
        pendingSnapshot = currentSnapshot()
    }

    private func commitPendingUndo() {
        guard let snap = pendingSnapshot else { return }
        pendingSnapshot = nil
        history.record(snap)
        notifyHistoryStateChanged()
    }

    private func discardPendingUndo() {
        pendingSnapshot = nil
    }

    @discardableResult
    func undo() -> Bool {
        guard let prev = history.undo(current: currentSnapshot()) else { return false }
        apply(prev)
        needsDisplay = true
        notifyHistoryStateChanged()
        refreshCursorAtCurrentLocation()
        return true
    }

    @discardableResult
    func redo() -> Bool {
        guard let next = history.redo(current: currentSnapshot()) else { return false }
        apply(next)
        needsDisplay = true
        notifyHistoryStateChanged()
        refreshCursorAtCurrentLocation()
        return true
    }

    private func notifyHistoryStateChanged() {
        onHistoryStateChanged?(canUndo, canRedo)
    }

    @discardableResult
    func deleteSelectedAnnotation() -> Bool {
        let indexes = validSelectedIndexes
        guard activeTextField == nil, !indexes.isEmpty else {
            return false
        }
        recordUndo()
        for idx in indexes.reversed() {
            annotations.remove(at: idx)
        }
        resetNumberCounterIfNumberAnnotationsAreGone()
        selectedIndex = nil
        needsDisplay = true
        refreshCursorAtCurrentLocation()
        return true
    }

    func deleteSelectedAnnotationFromKeyboard(for event: NSEvent) -> Bool {
        guard EditCanvasView.isSelectionDeleteKey(event) else { return false }
        return deleteSelectedAnnotation()
    }

    func nudgeSelectedAnnotationFromKeyboard(for event: NSEvent) -> Bool {
        let indexes = validSelectedIndexes
        guard
            activeTextField == nil,
            let delta = EditCanvasView.selectionNudgeDelta(for: event),
            !indexes.isEmpty
        else {
            return false
        }
        recordUndo()
        for idx in indexes {
            annotations[idx] = annotations[idx].translated(by: delta)
        }
        needsDisplay = true
        refreshCursorAtCurrentLocation()
        return true
    }

    func undoFromKeyboard(for event: NSEvent) -> Bool {
        guard EditCanvasView.isUndoKey(event) else { return false }
        return undo()
    }

    func redoFromKeyboard(for event: NSEvent) -> Bool {
        guard EditCanvasView.isRedoKey(event) else { return false }
        return redo()
    }

    func handleAnnotationClipboardShortcutFromKeyboard(for event: NSEvent) -> Bool {
        guard let shortcut = EditCanvasView.commandShortcutCharacter(for: event) else { return false }
        switch shortcut {
        case "x":
            return cutSelectedAnnotation()
        case "c":
            return copySelectedAnnotation()
        case "v":
            return pasteCopiedAnnotation()
        case "a":
            return selectAllAnnotations()
        default:
            return false
        }
    }

    @discardableResult
    func copySelectedAnnotation() -> Bool {
        let indexes = validSelectedIndexes
        guard activeTextField == nil, indexes.count == 1 else {
            return false
        }
        Self.annotationPasteboard = indexes.map { annotations[$0] }
        return true
    }

    @discardableResult
    func cutSelectedAnnotation() -> Bool {
        guard copySelectedAnnotation() else { return false }
        return deleteSelectedAnnotation()
    }

    @discardableResult
    func pasteCopiedAnnotation() -> Bool {
        let sources = Self.annotationPasteboard
        guard activeTextField == nil, sources.count == 1 else {
            return false
        }
        let offset = pasteOffset(forPasting: sources)
        let pasted = sources.map { $0.translated(by: offset) }
        let firstNewIndex = annotations.count
        recordUndo()
        annotations.append(contentsOf: pasted)
        pasted.forEach(syncNumberCounterAfterAdding)
        setSelectedIndexes(Set(firstNewIndex..<annotations.count), primary: annotations.indices.last)
        needsDisplay = true
        refreshCursorAtCurrentLocation()
        return true
    }

    @discardableResult
    func selectAllAnnotations() -> Bool {
        guard activeTextField == nil, !annotations.isEmpty else {
            return false
        }
        setSelectedIndexes(Set(annotations.indices), primary: annotations.indices.last)
        refreshCursorAtCurrentLocation()
        return true
    }

    @discardableResult
    func insertImage(_ image: NSImage) -> Bool {
        activeTextField?.commit()
        let size = fittedInsertedImageSize(for: image)
        guard size.width > 0, size.height > 0 else { return false }
        let rect = insertionRect(size: size)
        recordUndo()
        annotations.append(ImageAnnotation(image: image, rect: rect))
        selectedIndex = annotations.indices.last
        needsDisplay = true
        refreshCursorAtCurrentLocation()
        return true
    }

    private func fittedInsertedImageSize(for image: NSImage) -> NSSize {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let maxWidth = min(max(24, bounds.width - 16), 360)
        let maxHeight = min(max(24, bounds.height - 16), 360)
        let scale = min(1, maxWidth / imageSize.width, maxHeight / imageSize.height)
        return NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func insertionRect(size: NSSize) -> NSRect {
        let center = insertionCenter()
        let origin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        return clampedInsertionRect(NSRect(origin: origin, size: size))
    }

    private func insertionCenter() -> NSPoint {
        if let cursorPoint = currentMousePointInCanvas(), bounds.contains(cursorPoint) {
            return cursorPoint
        }
        return NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func clampedInsertionRect(_ rect: NSRect) -> NSRect {
        let margin: CGFloat = 8
        var result = rect
        let available = bounds.insetBy(dx: margin, dy: margin)

        if result.width <= available.width {
            result.origin.x = min(max(result.minX, available.minX), available.maxX - result.width)
        } else {
            result.origin.x = bounds.midX - result.width / 2
        }

        if result.height <= available.height {
            result.origin.y = min(max(result.minY, available.minY), available.maxY - result.height)
        } else {
            result.origin.y = bounds.midY - result.height / 2
        }

        return result
    }

    // MARK: - Selection adjustment (sub-toolbar driven)

    /// True between `beginSelectionAdjustment()` and `commitSelectionAdjustment()`
    /// once a live mutate has actually changed the annotation. Used to
    /// suppress no-op undo entries when the user clicks the slider but
    /// doesn't drag.
    private var selectionAdjustmentDirty: Bool = false

    /// Capture the pre-mutation snapshot for an in-progress sub-toolbar
    /// adjustment (e.g. slider drag). No-op when nothing is selected, so
    /// idle slider clicks don't pollute the undo stack.
    func beginSelectionAdjustment() {
        guard selectedIndexes.count == 1 else { return }
        captureUndoForPending()
        selectionAdjustmentDirty = false
    }

    func commitSelectionAdjustment() {
        if selectionAdjustmentDirty {
            commitPendingUndo()
        } else {
            discardPendingUndo()
        }
        selectionAdjustmentDirty = false
    }

    /// Atomic mutation to the selected annotation — captures undo, applies
    /// the transform, redraws. Used by color taps and discrete size dots
    /// where there's no drag to batch.
    func mutateSelectedAnnotationAtomic(_ transform: (Annotation) -> Annotation) {
        guard selectedIndexes.count == 1, let idx = selectedIndex, idx < annotations.count else { return }
        let original = annotations[idx]
        let updated = transform(original)
        guard !updated.hasSameUndoState(as: original) else { return }
        recordUndo()
        annotations[idx] = updated
        syncNumberCounterAfterMutation(from: original, to: updated)
        needsDisplay = true
    }

    /// Live mutation during a slider drag — caller is responsible for
    /// `beginSelectionAdjustment` / `commitSelectionAdjustment` bookending.
    func mutateSelectedAnnotationLive(_ transform: (Annotation) -> Annotation) {
        guard selectedIndexes.count == 1, let idx = selectedIndex, idx < annotations.count else { return }
        let original = annotations[idx]
        let updated = transform(original)
        guard !updated.hasSameUndoState(as: original) else { return }
        annotations[idx] = updated
        syncNumberCounterAfterMutation(from: original, to: updated)
        selectionAdjustmentDirty = true
        needsDisplay = true
    }

    func mutateSelectedMosaicBlockSizeLive(_ blockSize: CGFloat) {
        guard let baseImage = resolveBaseImageForEditing() else { return }
        let imageSize = bounds.size
        mutateSelectedAnnotationLive { annotation in
            guard
                let mosaic = annotation as? MosaicAnnotation,
                let region = MosaicTool.createMosaicRegion(
                    rect: mosaic.rect,
                    imageSize: imageSize,
                    baseImage: baseImage,
                    blockSize: blockSize
                )
            else {
                return annotation
            }
            return MosaicAnnotation(
                rect: region.rect,
                pixelatedImage: region.pixelatedImage,
                blockSize: blockSize
            )
        }
    }

    private func syncNumberCounterAfterMutation(from original: Annotation, to updated: Annotation) {
        guard
            let oldNumber = original as? NumberAnnotation,
            let newNumber = updated as? NumberAnnotation,
            oldNumber.number != newNumber.number
        else { return }
        numberCounter = max(1, newNumber.number + 1)
    }

    private func syncNumberCounterAfterAdding(_ annotation: Annotation) {
        guard let number = annotation as? NumberAnnotation else { return }
        numberCounter = max(numberCounter, number.number + 1)
    }

    private func pasteOffset(forPasting annotations: [Annotation]) -> NSPoint {
        if let cursorPoint = currentMousePointInCanvas(), bounds.contains(cursorPoint) {
            let rect = combinedBoundingRect(for: annotations)
            return NSPoint(x: cursorPoint.x - rect.midX, y: cursorPoint.y - rect.midY)
        }
        return adjacentPasteOffsetKeepingAnnotationsVisible(annotations)
    }

    private func currentMousePointInCanvas() -> NSPoint? {
        guard let window else { return nil }
        let mouseInScreen = NSEvent.mouseLocation
        let mouseInWindow = window.convertPoint(fromScreen: mouseInScreen)
        return convert(mouseInWindow, from: nil)
    }

    private func adjacentPasteOffsetKeepingAnnotationsVisible(_ annotations: [Annotation]) -> NSPoint {
        let margin: CGFloat = 4
        var offset = Self.defaultPasteOffset
        let pastedRect = combinedBoundingRect(for: annotations.map { $0.translated(by: offset) })

        if pastedRect.maxX > bounds.maxX - margin {
            offset.x -= pastedRect.maxX - (bounds.maxX - margin)
        }
        if pastedRect.minX < bounds.minX + margin {
            offset.x += (bounds.minX + margin) - pastedRect.minX
        }
        if pastedRect.maxY > bounds.maxY - margin {
            offset.y -= pastedRect.maxY - (bounds.maxY - margin)
        }
        if pastedRect.minY < bounds.minY + margin {
            offset.y += (bounds.minY + margin) - pastedRect.minY
        }

        return offset
    }

    private func combinedBoundingRect(for annotations: [Annotation]) -> NSRect {
        guard let first = annotations.first?.boundingRect else { return .zero }
        return annotations.dropFirst().reduce(first) { $0.union($1.boundingRect) }
    }

    private func resetNumberCounterIfNumberAnnotationsAreGone() {
        if !annotations.contains(where: { $0 is NumberAnnotation }) {
            numberCounter = 1
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        setHoveredAnnotationIndex(nil)
        let isShiftSelecting = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.shift)

        // Action buttons (delete / edit) — clicked, not dragged.
        let chromeHit = selectedAnnotationForChrome.flatMap {
            AnnotationHitTesting.chromeHit(
                at: point,
                for: $0,
                includeActions: !isShiftSelecting
            )
        }

        if case .action(let action) = chromeHit,
           let idx = selectedIndex {
            activeTextField?.commit()
            switch action {
            case .delete:
                _ = deleteSelectedAnnotation()
            case .edit:
                if let textAnnotation = annotations[idx] as? TextAnnotation {
                    reEditTextAnnotation(at: idx, annotation: textAnnotation)
                }
            case .incrementNumber:
                mutateSelectedAnnotationAtomic { annotation in
                    guard let n = annotation as? NumberAnnotation else { return annotation }
                    return n.withNumber(n.number + 1)
                }
            case .decrementNumber:
                // Sequence badges start at 1 — clamp so "−" can't go lower.
                mutateSelectedAnnotationAtomic { annotation in
                    guard let n = annotation as? NumberAnnotation else { return annotation }
                    return n.withNumber(max(1, n.number - 1))
                }
            case .zoomInMagnifier:
                mutateSelectedAnnotationAtomic { annotation in
                    guard let magnifier = annotation as? MagnifierAnnotation else { return annotation }
                    return magnifier.withZoom(magnifier.zoom + MagnifierAnnotation.zoomStep)
                }
            case .zoomOutMagnifier:
                mutateSelectedAnnotationAtomic { annotation in
                    guard let magnifier = annotation as? MagnifierAnnotation else { return annotation }
                    return magnifier.withZoom(magnifier.zoom - MagnifierAnnotation.zoomStep)
                }
            }
            return
        }

        if activeTool == .eraser {
            activeTextField?.commit()
            selectedIndex = nil
            eraserSelection = EraserSelection(start: point, current: point, didDelete: false)
            captureUndoForPending()
            EditCanvasCursors.eraserCursor.set()
            needsDisplay = true
            return
        }

        // Selection handles (rotate / curve / tip) take priority over body
        // drags so the user can grab a handle that visually overlaps the
        // annotation it controls.
        if case .handle(let kind) = chromeHit,
           let idx = selectedIndex {
            activeTextField?.commit()
            let original = annotations[idx]
            let center = NSPoint(x: original.boundingRect.midX, y: original.boundingRect.midY)
            let startAngle = atan2(point.y - center.y, point.x - center.x)
            handleDragState = HandleDragState(
                kind: kind,
                index: idx,
                original: original,
                startMouse: point,
                startAngle: startAngle,
                startRotation: original.rotation
            )
            captureUndoForPending()
            NSCursor.closedHand.set()
            return
        }

        // Universal: clicking on any draggable existing annotation starts a
        // drag, regardless of which tool is selected (or none). Drawing tools
        // only take over for clicks on empty canvas.
        if let idx = AnnotationHitTesting.topmostIndex(at: point, in: annotations) {
            // Commit any in-progress text edit before grabbing something else.
            activeTextField?.commit()
            if isShiftSelecting {
                toggleSelection(of: idx)
                refreshCursorAtCurrentLocation()
                return
            }
            if event.clickCount >= 2,
               selectedIndexes.count == 1,
               selectedIndex == idx,
               let textAnnotation = annotations[idx] as? TextAnnotation {
                reEditTextAnnotation(at: idx, annotation: textAnnotation)
                return
            }
            if selectedIndexes.contains(idx), selectedIndexes.count > 1 {
                setSelectedIndexes(selectedIndexes, primary: idx)
            } else {
                selectedIndex = idx
            }
            let originals = Dictionary(
                uniqueKeysWithValues: validSelectedIndexes.map { ($0, annotations[$0]) }
            )
            dragState = DragState(
                index: idx,
                startMouse: point,
                originals: originals,
                didDrag: false
            )
            captureUndoForPending()
            NSCursor.closedHand.set()
            return
        }

        // Click on empty canvas: commit any in-progress text edit and
        // clear the current selection so adjust-mode chrome dismisses;
        // the active tool then takes over (if any).
        let wasEditingText = activeTextField != nil
        activeTextField?.commit()
        selectedIndex = nil

        guard activeTool != .none else { return }

        switch activeTool {
        case .none, .eraser:
            return

        case .pen:
            currentPenPoints = [point]

        case .marker:
            currentMarkerPoints = [point]

        case .rectangle, .ellipse:
            shapeStart = point
            shapeCurrent = point
            shapeRoughSeed = RoughShapeStyle.randomSeed()

        case .arrow, .line, .mosaic:
            shapeStart = point
            shapeCurrent = point
            shapeRoughSeed = nil

        case .magnifier:
            shapeStart = point
            shapeCurrent = point
            shapeRoughSeed = nil
            // Resolve the base image once; both the live preview and the
            // committed lens sample it.
            magnifierBaseImage = resolveBaseImageForEditing()

        case .numbered:
            pendingNumberCreate = PendingNumberCreate(start: point, current: point)

        case .text:
            pendingTextCreate = PendingTextCreate(start: point, current: point, wasEditing: wasEditingText)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        setHoveredAnnotationIndex(nil)

        if let state = handleDragState {
            // First mutation of the handle drag — commit the pre-drag snapshot
            // so undo can roll back to before the rotate/curve/tip.
            commitPendingUndo()
            applyHandleDrag(state: state, currentMouse: point)
            return
        }

        if var state = dragState {
            if !state.didDrag {
                let distance = hypot(point.x - state.startMouse.x, point.y - state.startMouse.y)
                guard distance >= dragThreshold else { return }
                state.didDrag = true
                dragState = state
                commitPendingUndo()
            }
            let delta = NSPoint(
                x: point.x - state.startMouse.x,
                y: point.y - state.startMouse.y
            )
            var didMove = false
            for (idx, original) in state.originals where idx < annotations.count {
                annotations[idx] = annotationForBodyDrag(original, by: delta)
                didMove = true
            }
            if didMove {
                needsDisplay = true
            }
            return
        }

        if eraserSelection != nil {
            updateEraserSelection(to: point)
            return
        }

        // Number tool: drag pulls an arrow tip out of the badge — preview
        // it live and commit on mouseUp.
        if var pending = pendingNumberCreate {
            pending.current = point
            pendingNumberCreate = pending
            needsDisplay = true
            return
        }
        if var pending = pendingTextCreate {
            if currentTextCallout {
                pending.current = point
                pendingTextCreate = pending
                needsDisplay = true
            } else if hypot(point.x - pending.start.x, point.y - pending.start.y) >= dragThreshold {
                pendingTextCreate = nil
            }
            return
        }

        guard activeTool != .none else { return }

        switch activeTool {
        case .none, .numbered, .text, .eraser:
            return

        case .pen:
            appendStrokePoint(point, to: &currentPenPoints)
            needsDisplay = true

        case .marker:
            appendStrokePoint(point, to: &currentMarkerPoints)
            needsDisplay = true

        case .rectangle, .ellipse, .arrow, .line, .mosaic, .magnifier:
            shapeCurrent = point
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        // 0. Handle drag (rotate / curve) — commit current state and exit.
        if handleDragState != nil {
            handleDragState = nil
            // If the user only clicked a handle without dragging, the
            // pending snapshot was never committed by mouseDragged — drop it
            // so the undo stack doesn't grow no-op entries.
            discardPendingUndo()
            needsDisplay = true
            refreshCursorAtCurrentLocation()
            return
        }

        // 1. Drag interaction on existing annotation. In any tool, a click
        // (with or without drag) keeps the annotation selected so the
        // adjust-mode chrome appears. Drag also moves it.
        if let state = dragState {
            dragState = nil
            // Click without drag → no mutation happened; drop the stash.
            discardPendingUndo()
            if state.didDrag {
                setSelectedIndexes(Set(state.originals.keys), primary: state.index)
            } else {
                selectedIndex = state.index
            }
            refreshCursorAtCurrentLocation()
            return
        }

        if let selection = eraserSelection {
            eraserSelection = nil
            if !selection.didDelete {
                discardPendingUndo()
            }
            needsDisplay = true
            refreshCursorAtCurrentLocation()
            return
        }

        // 2. Pending number create — commits whether or not the user dragged.
        // No drag (or short drag) → no arrow. Drag past the minimum arrow
        // distance → tip is the drag end and an arrow points at it.
        if let pending = pendingNumberCreate {
            pendingNumberCreate = nil
            let dragDist = hypot(
                pending.current.x - pending.start.x,
                pending.current.y - pending.start.y
            )
            let tip: NSPoint? = dragDist >= NumberAnnotation.arrowMinDistance
                ? pending.current
                : nil
            recordUndo()
            annotations.append(NumberAnnotation(
                center: pending.start,
                tip: tip,
                number: numberCounter,
                color: currentColor
            ))
            numberCounter += 1
            needsDisplay = true
            refreshCursorAtCurrentLocation()
            return
        }

        // 3. Pending text create (skip if same click just committed an edit)
        if let pending = pendingTextCreate {
            pendingTextCreate = nil
            if !pending.wasEditing {
                let calloutTip: NSPoint? = {
                    guard currentTextCallout else { return nil }
                    let dragDist = hypot(
                        pending.current.x - pending.start.x,
                        pending.current.y - pending.start.y
                    )
                    return dragDist >= TextAnnotation.calloutArrowMinDistance
                        ? pending.current
                        : nil
                }()
                beginTextEditing(
                    bottomLeft: newTextOrigin(forClickAt: pending.start, fontSize: currentFontSize),
                    fontSize: currentFontSize,
                    color: currentColor,
                    hasStroke: currentTextStroke,
                    hasCallout: currentTextCallout,
                    calloutTip: calloutTip
                )
            }
            return
        }

        guard activeTool != .none else { return }

        switch activeTool {
        case .none, .numbered, .text, .eraser:
            return

        case .pen:
            if let points = currentPenPoints, !points.isEmpty {
                recordUndo()
                annotations.append(PenAnnotation(
                    path: NSBezierPath.smoothed(through: points),
                    color: currentColor,
                    lineWidth: currentLineWidth
                ))
                currentPenPoints = nil
            }

        case .marker:
            if let points = currentMarkerPoints, !points.isEmpty {
                recordUndo()
                annotations.append(MarkerAnnotation(
                    path: NSBezierPath.smoothed(through: points),
                    color: currentMarkerColor,
                    lineWidth: currentMarkerLineWidth
                ))
                currentMarkerPoints = nil
            }

        case .mosaic:
            if let start = shapeStart, let end = shapeCurrent {
                let rect = EditorCanvasGeometry.rectFromTwoPoints(start, end)
                if rect.width > 2, rect.height > 2,
                   let baseImage = resolveBaseImageForEditing(),
                   let region = MosaicTool.createMosaicRegion(
                       rect: rect,
                       imageSize: bounds.size,
                       baseImage: baseImage,
                       blockSize: currentMosaicBlockSize
                   ) {
                    recordUndo()
                    annotations.append(MosaicAnnotation(
                        rect: region.rect,
                        pixelatedImage: region.pixelatedImage,
                        blockSize: currentMosaicBlockSize
                    ))
                }
            }
            shapeStart = nil
            shapeCurrent = nil

        case .magnifier:
            if let start = shapeStart, let end = shapeCurrent,
               let baseImage = magnifierBaseImage {
                // The press point is the lens center; the drag distance is
                // its radius, so the lens grows outward from where the user
                // pressed.
                let radius = hypot(end.x - start.x, end.y - start.y)
                if radius >= MagnifierAnnotation.minRadius {
                    recordUndo()
                    annotations.append(MagnifierAnnotation(
                        center: start,
                        radius: radius,
                        color: currentColor,
                        lineWidth: currentLineWidth,
                        zoom: MagnifierAnnotation.defaultZoom,
                        sourceImage: baseImage
                    ))
                }
            }
            shapeStart = nil
            shapeCurrent = nil
            magnifierBaseImage = nil

        case .rectangle:
            if let start = shapeStart, let current = shapeCurrent {
                let end = EditorCanvasGeometry.constrainedShapeEnd(from: start, to: current, tool: .rectangle, modifiers: event.modifierFlags)
                let rect = EditorCanvasGeometry.rectFromTwoPoints(start, end)
                if rect.width > 2, rect.height > 2 {
                    recordUndo()
                    annotations.append(RectAnnotation(
                        rect: rect,
                        color: currentColor,
                        lineWidth: currentLineWidth,
                        fillMode: currentShapeFillMode,
                        strokeStyle: currentShapeStrokeStyle,
                        roughStyle: RoughShapeStyle.make(
                            seed: shapeRoughSeed ?? RoughShapeStyle.randomSeed(),
                            rect: rect,
                            lineWidth: currentLineWidth
                        )
                    ))
                }
            }
            shapeStart = nil
            shapeCurrent = nil

        case .ellipse:
            if let start = shapeStart, let current = shapeCurrent {
                let end = EditorCanvasGeometry.constrainedShapeEnd(from: start, to: current, tool: .ellipse, modifiers: event.modifierFlags)
                let rect = EditorCanvasGeometry.rectFromTwoPoints(start, end)
                if rect.width > 2, rect.height > 2 {
                    recordUndo()
                    annotations.append(EllipseAnnotation(
                        rect: rect,
                        color: currentColor,
                        lineWidth: currentLineWidth,
                        fillMode: currentShapeFillMode,
                        strokeStyle: currentShapeStrokeStyle,
                        roughStyle: RoughShapeStyle.make(
                            seed: shapeRoughSeed ?? RoughShapeStyle.randomSeed(),
                            rect: rect,
                            lineWidth: currentLineWidth
                        )
                    ))
                }
            }
            shapeStart = nil
            shapeCurrent = nil

        case .arrow:
            if let start = shapeStart, let current = shapeCurrent {
                let end = EditorCanvasGeometry.constrainedShapeEnd(from: start, to: current, tool: .arrow, modifiers: event.modifierFlags)
                let dist = hypot(end.x - start.x, end.y - start.y)
                if dist > 5 {
                    recordUndo()
                    annotations.append(ArrowAnnotation(
                        startPoint: start,
                        endPoint: end,
                        color: currentColor,
                        lineWidth: currentLineWidth,
                        style: currentArrowStyle
                    ))
                }
            }
            shapeStart = nil
            shapeCurrent = nil

        case .line:
            if let start = shapeStart, let current = shapeCurrent {
                let end = EditorCanvasGeometry.constrainedShapeEnd(from: start, to: current, tool: .line, modifiers: event.modifierFlags)
                let dist = hypot(end.x - start.x, end.y - start.y)
                if dist > 5 {
                    recordUndo()
                    annotations.append(LineAnnotation(
                        startPoint: start,
                        endPoint: end,
                        color: currentColor,
                        lineWidth: currentLineWidth
                    ))
                }
            }
            shapeStart = nil
            shapeCurrent = nil
        }

        shapeRoughSeed = nil
        needsDisplay = true
        refreshCursorAtCurrentLocation()
    }

    override func flagsChanged(with event: NSEvent) {
        if shapeStart != nil, EditorCanvasGeometry.constrainsShapeWithShift(activeTool) {
            needsDisplay = true
        }
        super.flagsChanged(with: event)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        if let image = overrideBaseImage ?? windowBaseImage {
            image.draw(in: NSRect(origin: .zero, size: bounds.size))
        }

        // Draw all committed annotations (rotation applied via helper)
        for annotation in annotations {
            annotation.drawApplyingTransforms(in: context, bounds: bounds)
        }

        drawActiveTextCalloutBackground(in: context)

        let selected = validSelectedIndexes
        if let idx = hoveredAnnotationIndex,
           annotations.indices.contains(idx),
           !selected.contains(idx) {
            drawHoverHighlight(for: annotations[idx], in: context)
        }

        // Selection chrome — drawn on top so it's always reachable.
        if selected.count == 1, let idx = selected.first {
            AnnotationChromeRenderer.drawSelectionHandles(for: annotations[idx], in: context)
        } else {
            for idx in selected {
                AnnotationChromeRenderer.drawSelectionOutline(for: annotations[idx], in: context)
            }
        }

        // Draw in-progress pen stroke (smoothed live so the preview matches
        // what gets committed on mouseUp).
        if let points = currentPenPoints, !points.isEmpty {
            let path = NSBezierPath.smoothed(through: points)
            currentColor.setStroke()
            path.lineWidth = currentLineWidth
            path.stroke()
        }

        // Draw in-progress marker stroke (semi-transparent, brush × 6).
        if let points = currentMarkerPoints, !points.isEmpty {
            let path = NSBezierPath.smoothed(through: points)
            NSGraphicsContext.saveGraphicsState()
            let stroke = currentMarkerColor.withAlphaComponent(1.0)
            stroke.setStroke()
            path.lineWidth = currentMarkerLineWidth * MarkerAnnotation.brushScale
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            context.setAlpha(MarkerAnnotation.markerAlpha)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            path.stroke()
            context.endTransparencyLayer()
            context.setAlpha(1.0)
            NSGraphicsContext.restoreGraphicsState()
        }

        // Draw in-progress shape preview
        if let start = shapeStart, let rawCurrent = shapeCurrent {
            let current = EditorCanvasGeometry.constrainedShapeEnd(
                from: start,
                to: rawCurrent,
                tool: activeTool,
                modifiers: NSEvent.modifierFlags
            )
            context.setStrokeColor(currentColor.cgColor)
            context.setLineWidth(currentLineWidth)

            switch activeTool {
            case .rectangle:
                let rect = EditorCanvasGeometry.rectFromTwoPoints(start, current)
                RectAnnotation(
                    rect: rect,
                    color: currentColor,
                    lineWidth: currentLineWidth,
                    fillMode: currentShapeFillMode,
                    strokeStyle: currentShapeStrokeStyle,
                    roughStyle: previewRoughStyle(for: rect)
                ).draw(in: context, bounds: bounds)
            case .ellipse:
                let rect = EditorCanvasGeometry.rectFromTwoPoints(start, current)
                EllipseAnnotation(
                    rect: rect,
                    color: currentColor,
                    lineWidth: currentLineWidth,
                    fillMode: currentShapeFillMode,
                    strokeStyle: currentShapeStrokeStyle,
                    roughStyle: previewRoughStyle(for: rect)
                ).draw(in: context, bounds: bounds)
            case .mosaic:
                // Mosaic preview: a semi-transparent gray fill marking the
                // region that will be pixelated on mouseUp.
                let rect = EditorCanvasGeometry.rectFromTwoPoints(start, current)
                context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
                context.fill(rect)
            case .line:
                context.setLineCap(.round)
                context.move(to: start)
                context.addLine(to: current)
                context.strokePath()
            case .arrow:
                // Defer to ArrowAnnotation so the live drag preview is
                // pixel-identical to the committed shape — anything else
                // creates a visible snap on mouseUp.
                ArrowAnnotation(
                    startPoint: start,
                    endPoint: current,
                    color: currentColor,
                    lineWidth: currentLineWidth,
                    style: currentArrowStyle
                ).draw(in: context, bounds: bounds)
            case .magnifier:
                // Live lens preview — centered on the press point, radius
                // following the drag, sampling the base image cached when
                // the drag began.
                let radius = hypot(current.x - start.x, current.y - start.y)
                if radius > 6, let baseImage = magnifierBaseImage {
                    MagnifierAnnotation(
                        center: start,
                        radius: radius,
                        color: currentColor,
                        lineWidth: currentLineWidth,
                        zoom: MagnifierAnnotation.defaultZoom,
                        sourceImage: baseImage
                    ).draw(in: context, bounds: bounds)
                }
            default:
                break
            }
        }

        if let eraserSelection {
            drawEraserSelection(
                EditorCanvasGeometry.rectFromTwoPoints(eraserSelection.start, eraserSelection.current),
                in: context
            )
        }

        // Draw number-tool preview while dragging — committed lazily on
        // mouseUp, but the user expects to see the badge + arrow track the
        // cursor live like the arrow tool does.
        if let pending = pendingNumberCreate {
            let tip: NSPoint? = (pending.current == pending.start) ? nil : pending.current
            let preview = NumberAnnotation(
                center: pending.start,
                tip: tip,
                number: numberCounter,
                color: currentColor
            )
            preview.draw(in: context, bounds: bounds)
        }

        if let pending = pendingTextCreate, currentTextCallout {
            TextAnnotation(
                text: "",
                origin: newTextOrigin(forClickAt: pending.start, fontSize: currentFontSize),
                color: currentColor,
                fontSize: currentFontSize,
                hasStroke: currentTextStroke,
                hasCallout: true,
                calloutTip: pending.current == pending.start ? nil : pending.current
            ).draw(in: context, bounds: bounds)
        }

    }

    private func drawActiveTextCalloutBackground(in context: CGContext) {
        guard let field = activeTextField, field.hasCallout else { return }
        let fontSize = field.font?.pointSize ?? currentFontSize
        TextAnnotation(
            text: field.stringValue,
            origin: field.annotationOrigin,
            color: field.annotationColor,
            fontSize: fontSize,
            rotation: field.rotation,
            hasStroke: field.hasStroke,
            hasCallout: field.hasCallout,
            calloutTip: field.calloutTip
        ).drawCalloutBackgroundOnly(in: context, bodyRect: field.frame)
    }

    private func drawEraserSelection(_ rect: NSRect, in context: CGContext) {
        guard rect.width > 0 || rect.height > 0 else { return }
        context.saveGState()
        context.setFillColor(NSColor.systemRed.withAlphaComponent(0.13).cgColor)
        context.fill(rect)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
        context.setLineWidth(3)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(rect.insetBy(dx: 1.5, dy: 1.5))
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.stroke(rect.insetBy(dx: 0.75, dy: 0.75))
        context.restoreGState()
    }

    override func scrollWheel(with event: NSEvent) {
        guard overrideBaseImage != nil else {
            super.scrollWheel(with: event)
            return
        }

        enclosingScrollView?.scrollWheel(with: event)
    }

    // MARK: - Composite

    func compositeImage(
        fallbackBaseImage: NSImage?,
        annotationClipMask: NSImage? = nil
    ) -> NSImage? {
        guard let baseImage = fallbackBaseImage else { return nil }
        return EditorCompositeRenderer.compositeImage(
            baseImage: baseImage,
            annotations: annotations,
            annotationBounds: bounds,
            annotationClipMask: annotationClipMask
        )
    }

    func updateViewportSize(_ size: NSSize) {
        setFrameSize(size)
        needsDisplay = true
    }

    // MARK: - Helpers

    func resolveBaseImageForEditing() -> NSImage? {
        if let overrideBaseImage {
            return overrideBaseImage
        }

        if let windowBaseImage {
            return windowBaseImage
        }

        if let snapshot = preSnapshot, let rect = captureRect, let screen = captureScreen {
            if let cropped = ScreenCapturer.crop(from: snapshot, captureRect: rect, screen: screen) {
                return cropped
            }
        }

        guard let rect = captureRect, let screen = captureScreen else { return nil }
        return ScreenCapturer.capture(rect: rect, screen: screen)
    }

    private func cancelInFlightInteraction() {
        currentPenPoints = nil
        currentMarkerPoints = nil
        shapeStart = nil
        shapeCurrent = nil
        shapeRoughSeed = nil
        magnifierBaseImage = nil
        dragState = nil
        handleDragState = nil
        pendingNumberCreate = nil
        pendingTextCreate = nil
        hoveredAnnotationIndex = nil
        if eraserSelection?.didDelete != true {
            discardPendingUndo()
        }
        eraserSelection = nil
        selectedIndex = nil
        activeTextField?.cancel()
    }

    /// Append a point to a stroke buffer, dropping samples that are too
    /// close to the previous one. Sub-pixel-spaced samples just bloat the
    /// path and amplify noise without adding visible detail.
    private func appendStrokePoint(_ point: NSPoint, to buffer: inout [NSPoint]?) {
        guard buffer != nil else { return }
        if let last = buffer?.last, hypot(point.x - last.x, point.y - last.y) < 1.0 {
            return
        }
        buffer?.append(point)
    }

    private var canShowHoverHighlight: Bool {
        activeTextField == nil
            && activeTool != .eraser
            && dragState == nil
            && handleDragState == nil
            && eraserSelection == nil
            && currentPenPoints == nil
            && currentMarkerPoints == nil
            && shapeStart == nil
            && pendingNumberCreate == nil
            && pendingTextCreate == nil
    }

    private func setHoveredAnnotationIndex(_ index: Int?) {
        let resolved = index.flatMap { annotations.indices.contains($0) ? $0 : nil }
        guard hoveredAnnotationIndex != resolved else { return }
        hoveredAnnotationIndex = resolved
        needsDisplay = true
    }

    private func updateHoverHighlight(at point: NSPoint) {
        guard canShowHoverHighlight, bounds.contains(point) else {
            setHoveredAnnotationIndex(nil)
            return
        }
        setHoveredAnnotationIndex(AnnotationHitTesting.topmostIndex(at: point, in: annotations))
    }

    private func updateEraserSelection(to point: NSPoint) {
        guard var selection = eraserSelection else { return }
        selection.current = point
        eraseAnnotations(in: EditorCanvasGeometry.rectFromTwoPoints(selection.start, point), selection: &selection)
        eraserSelection = selection
        needsDisplay = true
    }

    private func eraseAnnotations(in rect: NSRect, selection: inout EraserSelection) {
        guard rect.width >= 1 || rect.height >= 1 else { return }
        let kept = annotations.filter { !annotationSelectionBounds($0).intersects(rect) }
        guard kept.count != annotations.count else { return }

        if !selection.didDelete {
            commitPendingUndo()
            selection.didDelete = true
        }
        annotations = kept
        selectedIndex = nil
        resetNumberCounterIfNumberAnnotationsAreGone()
        refreshCursorAtCurrentLocation()
    }

    private func annotationSelectionBounds(_ annotation: Annotation) -> NSRect {
        let rect = annotation.boundingRect
        guard annotation.supportsRotation, annotation.rotation != 0 else { return rect }

        let corners = [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.maxY),
        ].map { AnnotationHandlePolicy.rotated($0, for: annotation) }

        guard let first = corners.first else { return rect }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in corners.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Force-commit any in-progress text. Called by the controller when
    /// switching tools or activating actions like save/confirm so the
    /// floating editor's contents make it into the composite.
    func commitActiveTextEditing() {
        activeTextField?.commit()
    }

    var isTextEditing: Bool {
        activeTextField != nil
    }

    private func newTextOrigin(forClickAt point: NSPoint, fontSize: CGFloat) -> NSPoint {
        let font = TextAnnotation.font(forSize: fontSize)
        return NSPoint(
            x: point.x,
            y: point.y - TextAnnotation.lineHeight(for: font)
        )
    }

    private func beginTextEditing(
        bottomLeft: NSPoint,
        fontSize: CGFloat,
        color: NSColor,
        hasStroke: Bool,
        hasCallout: Bool,
        calloutTip: NSPoint? = nil,
        initialText: String = "",
        rotation: CGFloat = 0,
        replacingIndex: Int? = nil
    ) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let lineHeight = TextAnnotation.lineHeight(for: font)

        // Capture the pre-edit state BEFORE we remove a re-edited annotation
        // from the array, so undo can restore the original cleanly.
        captureUndoForPending()

        // Hide the source annotation while editing so it isn't drawn under
        // the field. Stash it for cancel-restore.
        if let idx = replacingIndex,
           idx < annotations.count,
           let original = annotations[idx] as? TextAnnotation {
            annotations.remove(at: idx)
            editingOriginalAnnotation = original
            editingOriginalIndex = idx
            needsDisplay = true
        } else {
            editingOriginalAnnotation = nil
            editingOriginalIndex = nil
        }

        let initialSize = TextAnnotation.editorSize(for: initialText, font: font)
        let contentHeight = max(initialSize.height, lineHeight)
        let fieldRect: NSRect
        if hasCallout {
            fieldRect = NSRect(
                x: bottomLeft.x - TextAnnotation.calloutHorizontalPadding,
                y: bottomLeft.y - TextAnnotation.calloutVerticalPadding,
                width: initialSize.width + TextAnnotation.calloutHorizontalPadding * 2,
                height: contentHeight + TextAnnotation.calloutVerticalPadding * 2
            )
        } else {
            fieldRect = NSRect(
                x: bottomLeft.x,
                y: bottomLeft.y,
                width: initialSize.width,
                height: contentHeight
            )
        }

        let field = EditableTextField(frame: fieldRect)
        field.font = font
        field.annotationColor = color
        field.hasStroke = hasStroke
        field.hasCallout = hasCallout
        field.calloutTip = calloutTip
        field.rotation = rotation
        field.stringValue = initialText
        field.onCommit = { [weak self, weak field] text in
            self?.handleTextCommit(text: text, field: field)
        }
        field.onCancel = { [weak self, weak field] in
            self?.handleTextCancel(field: field)
        }
        field.onChange = { [weak self] in
            self?.needsDisplay = true
        }

        addSubview(field)
        activeTextField = field
        field.sizeToFitText()
        window?.makeFirstResponder(field)
        // Pre-select existing text directly on the cell editor.
        //
        // NEVER use `field.selectText(nil)` here — it internally calls
        // `makeFirstResponder` AGAIN on the field, which makes AppKit tear
        // down the just-built cell editor and rebuild it. Tearing it down
        // fires `controlTextDidEndEditing`, which our delegate treats as a
        // user commit and removes the field from the view hierarchy before
        // the user ever sees it. Reaching into `currentEditor()` and setting
        // `selectedRange` manipulates the same NSText proxy without going
        // back through the responder dance.
        if !initialText.isEmpty, let editor = field.currentEditor() {
            editor.selectedRange = NSRange(location: 0, length: (initialText as NSString).length)
        }
    }

    private func handleTextCommit(text: String, field: EditableTextField?) {
        guard let field else { return }
        field.removeFromSuperview()
        if activeTextField === field { activeTextField = nil }
        if activeTool == .text {
            window?.makeFirstResponder(self)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasReEdit = editingOriginalIndex != nil
        if !trimmed.isEmpty {
            let font = field.font ?? NSFont.systemFont(ofSize: currentFontSize, weight: .bold)
            let newAnnotation = TextAnnotation(
                text: text,
                origin: field.annotationOrigin,
                color: field.annotationColor,
                fontSize: font.pointSize,
                rotation: field.rotation,
                hasStroke: field.hasStroke,
                hasCallout: field.hasCallout,
                calloutTip: field.calloutTip
            )
            if let idx = editingOriginalIndex {
                let safeIdx = min(idx, annotations.count)
                annotations.insert(newAnnotation, at: safeIdx)
            } else {
                annotations.append(newAnnotation)
            }
        }
        editingOriginalAnnotation = nil
        editingOriginalIndex = nil
        // Net change happens whenever a new annotation was added OR a
        // re-edit was attempted (re-edit always replaces or removes the
        // original). A no-op fresh-create with empty text leaves state
        // untouched — drop the stash so the undo stack stays clean.
        if !trimmed.isEmpty || wasReEdit {
            commitPendingUndo()
        } else {
            discardPendingUndo()
        }
        needsDisplay = true
        refreshCursorAtCurrentLocation()
    }

    private func handleTextCancel(field: EditableTextField?) {
        guard let field else { return }
        field.removeFromSuperview()
        if activeTextField === field { activeTextField = nil }
        if activeTool == .text {
            window?.makeFirstResponder(self)
        }

        if let original = editingOriginalAnnotation, let idx = editingOriginalIndex {
            let safeIdx = min(idx, annotations.count)
            annotations.insert(original, at: safeIdx)
        }
        editingOriginalAnnotation = nil
        editingOriginalIndex = nil
        // Cancel restores the pre-edit state; no net change → no undo entry.
        discardPendingUndo()
        needsDisplay = true
        refreshCursorAtCurrentLocation()
    }

    private func previewRoughStyle(for rect: NSRect) -> RoughShapeStyle {
        RoughShapeStyle.make(
            seed: shapeRoughSeed ?? Self.fallbackShapePreviewSeed,
            rect: rect,
            lineWidth: currentLineWidth
        )
    }

    private func drawHoverHighlight(for annotation: Annotation, in context: CGContext) {
        if drawsHoverBody(for: annotation) {
            context.saveGState()
            context.setAlpha(0.96)
            context.setShadow(
                offset: .zero,
                blur: 5,
                color: EditCanvasView.hoverColor.withAlphaComponent(0.45).cgColor
            )
            annotation
                .withColor(EditCanvasView.hoverColor)
                .drawApplyingTransforms(in: context, bounds: bounds)
            context.restoreGState()
        } else {
            drawHoverFrame(for: annotation, in: context)
        }
    }

    private func drawsHoverBody(for annotation: Annotation) -> Bool {
        switch annotation {
        case let rect as RectAnnotation:
            return !rect.filled
        case let ellipse as EllipseAnnotation:
            return !ellipse.filled
        case is PenAnnotation,
             is MarkerAnnotation,
             is ArrowAnnotation,
             is LineAnnotation,
             is NumberAnnotation,
             is MagnifierAnnotation:
            return true
        default:
            return false
        }
    }

    private func drawHoverFrame(for annotation: Annotation, in context: CGContext) {
        let box = annotation.boundingRect.insetBy(
            dx: -EditCanvasView.hoverBoxPad,
            dy: -EditCanvasView.hoverBoxPad
        )
        guard box.width > 0, box.height > 0 else { return }

        let needsRotation = annotation.supportsRotation && annotation.rotation != 0
        context.saveGState()
        if needsRotation {
            let rect = annotation.boundingRect
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: annotation.rotation)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }

        let cornerRadius = min(7, max(3, min(box.width, box.height) * 0.18))
        let path = CGPath(
            roundedRect: box,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        context.setFillColor(EditCanvasView.hoverColor.withAlphaComponent(0.10).cgColor)
        context.addPath(path)
        context.fillPath()
        context.setStrokeColor(EditCanvasView.hoverColor.cgColor)
        context.setLineWidth(3)
        context.setLineJoin(.round)
        context.setShadow(
            offset: .zero,
            blur: 4,
            color: EditCanvasView.hoverColor.withAlphaComponent(0.35).cgColor
        )
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    private func applyHandleDrag(state: HandleDragState, currentMouse: NSPoint) {
        guard state.index < annotations.count else { return }
        let shiftPressed = NSEvent.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.shift)
        let baseImage = state.original is MosaicAnnotation
            ? resolveBaseImageForEditing()
            : nil
        let context = AnnotationHandleDragging.Context(
            canvasBounds: bounds,
            shiftPressed: shiftPressed,
            baseImage: baseImage
        )
        if let annotation = AnnotationHandleDragging.transformedAnnotation(
            from: state.original,
            handle: state.kind,
            currentMouse: currentMouse,
            startAngle: state.startAngle,
            startRotation: state.startRotation,
            context: context
        ) {
            annotations[state.index] = annotation
        }

        needsDisplay = true
    }

    // MARK: - Cursor

    /// Cursor shown while the magnifier tool is active and the pointer is
    /// over empty canvas — a loupe glyph with a dark halo so it reads on any
    /// background. The hotspot is the lens center, where a drag drops the
    /// lens. The drawing handler is resolution-independent, so the cursor
    /// stays crisp on Retina displays.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateHoverHighlight(at: point)
        updateCursor(at: point)
    }

    override func mouseEntered(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateHoverHighlight(at: point)
        updateCursor(at: point)
    }

    override func mouseExited(with event: NSEvent) {
        setHoveredAnnotationIndex(nil)
        // Let whatever's underneath manage its own cursor.
        NSCursor.arrow.set()
    }

    private func updateCursor(at point: NSPoint) {
        // Don't fight the text field's I-beam while editing.
        if activeTextField != nil { return }
        if activeTool == .eraser {
            EditCanvasCursors.eraserCursor.set()
            return
        }
        // Action buttons on the selection chrome: pointing finger.
        let chromeHit = selectedAnnotationForChrome.flatMap {
            AnnotationHitTesting.chromeHit(at: point, for: $0)
        }
        if case .action = chromeHit {
            NSCursor.pointingHand.set()
            return
        }
        // Drag handles (rotate / curve / number tip / magnifier source /
        // resize): resize grips get a directional cursor; the rest get an
        // open hand.
        if case .handle(let kind) = chromeHit {
            if case .resize(let anchor) = kind {
                switch anchor {
                case .topLeft: ResizeHandleCursor.setFrameResizeCursor(for: .topLeft)
                case .top: ResizeHandleCursor.setFrameResizeCursor(for: .top)
                case .topRight: ResizeHandleCursor.setFrameResizeCursor(for: .topRight)
                case .right: ResizeHandleCursor.setFrameResizeCursor(for: .right)
                case .bottomRight: ResizeHandleCursor.setFrameResizeCursor(for: .bottomRight)
                case .bottom: ResizeHandleCursor.setFrameResizeCursor(for: .bottom)
                case .bottomLeft: ResizeHandleCursor.setFrameResizeCursor(for: .bottomLeft)
                case .left: ResizeHandleCursor.setFrameResizeCursor(for: .left)
                }
            } else {
                NSCursor.openHand.set()
            }
            return
        }
        // Hovering over any draggable mark: open hand so the user knows it
        // can be picked up regardless of the active tool.
        if AnnotationHitTesting.topmostIndex(at: point, in: annotations) != nil {
            NSCursor.openHand.set()
            return
        }
        // Magnifier tool over empty canvas: a loupe cursor signals that a
        // drag here drops a lens.
        if activeTool == .magnifier {
            EditCanvasCursors.magnifierCursor.set()
            return
        }
        NSCursor.arrow.set()
    }

    /// Convert the global mouse location into view coords and refresh the
    /// cursor. Used after operations that change what's draggable (undo,
    /// commit, tool change) so the cursor doesn't lie until the next move.
    func refreshCursorAtCurrentLocation() {
        guard let window else { return }
        let mouseInScreen = NSEvent.mouseLocation
        let mouseInWindow = window.convertPoint(fromScreen: mouseInScreen)
        let local = convert(mouseInWindow, from: nil)
        guard bounds.contains(local) else {
            setHoveredAnnotationIndex(nil)
            return
        }
        updateHoverHighlight(at: local)
        updateCursor(at: local)
    }

    override func keyDown(with event: NSEvent) {
        if undoFromKeyboard(for: event) {
            return
        }
        if redoFromKeyboard(for: event) {
            return
        }
        if handleAnnotationClipboardShortcutFromKeyboard(for: event) {
            return
        }
        if nudgeSelectedAnnotationFromKeyboard(for: event) {
            return
        }
        if deleteSelectedAnnotationFromKeyboard(for: event) {
            return
        }
        super.keyDown(with: event)
    }

    private static func isUndoKey(_ event: NSEvent) -> Bool {
        commandShortcutCharacter(for: event) == "z"
    }

    private static func isRedoKey(_ event: NSEvent) -> Bool {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection(blockedModifiers).isEmpty else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == "z"
    }

    private static func commandShortcutCharacter(for event: NSEvent) -> String? {
        let activeModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(activeModifiers)
        guard modifiers == .command else { return nil }
        return event.charactersIgnoringModifiers?.lowercased()
    }

    private static func isSelectionDeleteKey(_ event: NSEvent) -> Bool {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection(blockedModifiers).isEmpty else { return false }
        return event.keyCode == 51 || event.keyCode == 117
    }

    private static func selectionNudgeDelta(for event: NSEvent) -> NSPoint? {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection(blockedModifiers).isEmpty else { return nil }

        let step: CGFloat = 1
        switch event.keyCode {
        case 123: return NSPoint(x: -step, y: 0) // Left Arrow
        case 124: return NSPoint(x: step, y: 0)  // Right Arrow
        case 125: return NSPoint(x: 0, y: -step) // Down Arrow
        case 126: return NSPoint(x: 0, y: step)  // Up Arrow
        default: return nil
        }
    }
}
