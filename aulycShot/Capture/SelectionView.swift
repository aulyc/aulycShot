import AppKit

@MainActor
protocol SelectionViewDelegate: AnyObject {
    func selectionDidStart()
    /// - Parameter isWindowSelection: true when the rect came from clicking a
    ///   detected window (no drag), so the editor can apply window-only
    ///   effects like rounded corners. False for free-drag / resize / preset.
    /// - Parameter windowID: the WindowServer id for clicked-window captures.
    ///   nil for free-drag / resize / preset selections.
    func selectionDidComplete(rect: NSRect, inView view: NSView, isWindowSelection: Bool, windowID: CGWindowID?)
    func selectionDidChange(rect: NSRect, inView view: NSView)
    func selectionMaskDidDoubleClick(inView view: NSView)
    func selectionDidDoubleClickInsideSelection(inView view: NSView)
}

extension SelectionViewDelegate {
    func selectionDidChange(rect: NSRect, inView view: NSView) {}
    func selectionMaskDidDoubleClick(inView view: NSView) {}
    func selectionDidDoubleClickInsideSelection(inView view: NSView) {}
}

enum CaptureSelectionChrome {
    static let accentColor = SettingsPalette.accent
    static let borderWidth: CGFloat = 2
    static let dashPattern: [CGFloat] = [6, 4]
    static let handleSize: CGFloat = 8
}

enum EditorCursorRoute: Equatable {
    case selectionHandle
    case selectionBorder
    case annotationTool
    case arrow
}

enum EditorCursorRoutingPolicy {
    static func route(
        selectionInteractionEnabled: Bool,
        selectionLocked: Bool,
        annotationToolActive: Bool,
        selectionRect: NSRect?,
        point: NSPoint,
        isOverSelectionHandle: Bool,
        isOverSelectionBorder: Bool = false
    ) -> EditorCursorRoute? {
        guard selectionLocked || !selectionInteractionEnabled else { return nil }
        guard let selectionRect else { return nil }

        if selectionInteractionEnabled && isOverSelectionHandle {
            return .selectionHandle
        }
        if selectionInteractionEnabled && isOverSelectionBorder {
            return .selectionBorder
        }
        if annotationToolActive && selectionRect.contains(point) {
            return .annotationTool
        }
        return .arrow
    }

    static func isSelectionBorderHit(
        point: NSPoint,
        rect: NSRect,
        hitSize: CGFloat
    ) -> Bool {
        guard hitSize > 0, rect.width > 0, rect.height > 0 else { return false }
        let outer = rect.insetBy(dx: -hitSize, dy: -hitSize)
        guard outer.contains(point) else { return false }
        guard rect.width > hitSize * 2, rect.height > hitSize * 2 else { return true }
        return !rect.insetBy(dx: hitSize, dy: hitSize).contains(point)
    }
}

@MainActor
class SelectionView: NSView {
    weak var delegate: SelectionViewDelegate?

    // MARK: - State

    private enum State {
        case idle
        case drawing
        case selected
    }

    private enum DragAction {
        case none
        case drawNew
        case move
        case resize(HandlePosition)
    }

    enum HandlePosition: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        case topCenter, bottomCenter, leftCenter, rightCenter
    }

    private var state: State = .idle
    private var dragAction: DragAction = .none
    private var selectionOrigin: NSPoint = .zero
    private var selectionRect: NSRect?
    private var dragStart: NSPoint = .zero
    private var dragOriginalRect: NSRect = .zero

    // Whether annotation tools are active (pass mouse events through to canvas)
    var annotationToolActive = false
    var refreshAnnotationCursor: (() -> Void)?

    // When true, clicking outside selection won't start a new selection
    var selectionLocked = false

    // Scroll capture mode: update border styling while the controller manages event routing.
    var scrollCaptureActive = false

    // Crop mode is hosted by the same full-screen overlay window, but must not
    // keep painting that window's frozen desktop snapshot and dimming mask.
    // The crop view itself remains confined to the original selection.
    var cropPresentationActive = false {
        didSet { needsDisplay = true }
    }

    // When false, the selection frame becomes a fixed viewport.
    var selectionInteractionEnabled = true
    var aspectRatio: CGFloat? = nil
    var selectionSizeLabelOverride: String? {
        didSet { needsDisplay = true }
    }

    // MARK: - Pre-captured Snapshot

    /// Full-screen snapshot taken before overlays appear, preserving transient menus/popups.
    var backgroundSnapshot: NSImage?

    // MARK: - Smart Selection

    /// Set by OverlayWindowController so the view can resolve element, window,
    /// and screen candidates under the cursor.
    var windowDetector: WindowDetector?

    private var hoverState = SmartSelectionHoverState()
    /// Visible candidate rect, clipped to this display's overlay bounds.
    private var hoverCandidateRect: NSRect?
    /// Full candidate rect. Windows may extend beyond the current display.
    private var hoverCandidateFullRect: NSRect?
    private var lastHoverCGPoint: CGPoint?

    /// Pending smart candidate — confirmed on mouseUp if no significant drag occurs.
    private var pendingCandidate: SmartSelectionCandidate?
    private var pendingCandidateRect: NSRect?
    private let windowClickThreshold: CGFloat = 4

    // MARK: - Constants

    private let accentColor = CaptureSelectionChrome.accentColor
    private let handleSize = CaptureSelectionChrome.handleSize
    private let handleHitSize: CGFloat = 12
    private let selectionBorderHitSize: CGFloat = 7
    private let borderWidth = CaptureSelectionChrome.borderWidth
    private let dashPattern = CaptureSelectionChrome.dashPattern
    private let dimmingOverlayAlpha: CGFloat = 0.45

    // MARK: - Public

    var currentSelectionRect: NSRect? { selectionRect }

    func refreshHoverAtCurrentMouseLocation() {
        guard state == .idle, !selectionLocked else { return }
        updateSmartSelectionHover(screenPoint: NSEvent.mouseLocation)
    }

    @discardableResult
    func cycleSmartSelectionCandidate(reverse: Bool) -> Bool {
        guard state == .idle,
              !selectionLocked,
              !hoverState.isEmpty
        else { return false }

        hoverState.cycle(reverse: reverse)
        applyCurrentHoverCandidate()
        return true
    }

    func updateSelectionRect(_ rect: NSRect) {
        selectionRect = rect
        state = .selected
        needsDisplay = true
    }

    /// Re-evaluates the editor cursor for a known point in this view. Keeping
    /// this path shared with `mouseMoved` prevents tool activation from
    /// bypassing the screenshot boundary.
    @discardableResult
    func refreshEditorCursor(at point: NSPoint) -> EditorCursorRoute? {
        let selectedRect = state == .selected ? selectionRect : nil
        let hoveredHandle = selectedRect.flatMap { hitTestHandle(point: point, rect: $0) }
        let isOverSelectionBorder = selectedRect.map {
            EditorCursorRoutingPolicy.isSelectionBorderHit(
                point: point,
                rect: $0,
                hitSize: selectionBorderHitSize
            )
        } ?? false

        guard let route = EditorCursorRoutingPolicy.route(
            selectionInteractionEnabled: selectionInteractionEnabled,
            selectionLocked: selectionLocked,
            annotationToolActive: annotationToolActive,
            selectionRect: selectedRect,
            point: point,
            isOverSelectionHandle: hoveredHandle != nil,
            isOverSelectionBorder: isOverSelectionBorder
        ) else {
            return nil
        }

        switch route {
        case .selectionHandle:
            if let hoveredHandle {
                SelectionView.setCursorForHandle(hoveredHandle)
            } else {
                NSCursor.arrow.set()
            }
        case .selectionBorder:
            NSCursor.openHand.set()
        case .annotationTool:
            if let refreshAnnotationCursor {
                refreshAnnotationCursor()
            } else {
                NSCursor.arrow.set()
            }
        case .arrow:
            NSCursor.arrow.set()
        }
        return route
    }

    func refreshEditorCursorAtCurrentMouseLocation() {
        guard let window else {
            NSCursor.arrow.set()
            return
        }
        let pointInWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let point = convert(pointInWindow, from: nil)
        guard bounds.contains(point) else {
            NSCursor.arrow.set()
            return
        }
        if refreshEditorCursor(at: point) == nil {
            NSCursor.arrow.set()
        }
    }

    /// Translate the selection rect by `delta` from the supplied
    /// `originalRect` and notify the delegate. Used by the editor's selection
    /// border overlay, which captures the rect at mouseDown and forwards
    /// cumulative deltas while the user drags. Mirrors the clamping done by
    /// the pre-editor in-rect `.move` gesture so the selection stays on screen.
    func moveByExternalDrag(deltaFromOriginal delta: CGSize, originalRect: NSRect) {
        var newRect = originalRect.offsetBy(dx: delta.width, dy: delta.height)
        newRect.origin.x = max(0, min(bounds.width - newRect.width, newRect.origin.x))
        newRect.origin.y = max(0, min(bounds.height - newRect.height, newRect.origin.y))
        selectionRect = newRect
        state = .selected
        delegate?.selectionDidChange(rect: newRect, inView: self)
        needsDisplay = true
    }

    /// Mirror of `mouseUp`'s `.move` finalize: notify the delegate that the
    /// selection rect's final position is committed.
    func finalizeExternalDrag() {
        if let rect = selectionRect {
            delegate?.selectionDidComplete(rect: rect, inView: self, isWindowSelection: false, windowID: nil)
        }
    }

    /// Resize the selection rect using a handle drag driven by an overlay
    /// (e.g. `SelectionChromeOverlay`) rather than the SelectionView's own
    /// mouse handling. Mirrors `mouseDragged`'s `.resize` branch.
    func resizeByExternalDrag(handle: HandlePosition, originalRect: NSRect, currentPoint: NSPoint) {
        let newRect = SelectionView.resizedRect(
            from: originalRect,
            handle: handle,
            currentPoint: currentPoint,
            aspectRatio: aspectRatio,
            bounds: bounds
        )
        selectionRect = newRect
        state = .selected
        delegate?.selectionDidChange(rect: newRect, inView: self)
        needsDisplay = true
    }

    /// Mirror of `mouseUp`'s `.resize` finalize.
    func finalizeExternalResize() {
        if let rect = selectionRect {
            delegate?.selectionDidComplete(rect: rect, inView: self, isWindowSelection: false, windowID: nil)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if shouldConfirmFromSelectionDoubleClick(event: event, point: point) {
            dragAction = .none
            delegate?.selectionDidDoubleClickInsideSelection(inView: self)
            return
        }
        if shouldSuspendFromMaskDoubleClick(event: event, point: point) {
            dragAction = .none
            delegate?.selectionMaskDidDoubleClick(inView: self)
            return
        }

        guard selectionInteractionEnabled else {
            dragAction = .none
            return
        }

        // On a highlighted smart candidate: defer confirmation until mouseUp.
        // If the user drags past the threshold, fall through to free-form drawing.
        if state == .idle,
           let candidate = currentHoverCandidate,
           let hoverRect = hoverCandidateRect {
            pendingCandidate = candidate
            pendingCandidateRect = hoverCandidateFullRect ?? hoverRect
            clearHover()
            selectionOrigin = point
            dragStart = point
            selectionRect = NSRect(origin: point, size: .zero)
            state = .drawing
            dragAction = .drawNew
            delegate?.selectionDidStart()
            needsDisplay = true
            return
        }

        if let rect = selectionRect, state == .selected {
            // Check control points first
            if let handle = hitTestHandle(point: point, rect: rect) {
                dragAction = .resize(handle)
                dragStart = point
                dragOriginalRect = rect
                return
            }
            // Check inside selection for move
            if rect.contains(point) {
                if annotationToolActive {
                    // Let canvas handle it
                    return
                }
                dragAction = .move
                dragStart = point
                dragOriginalRect = rect
                return
            }
            // Click outside selection — if locked (editor active), ignore
            if selectionLocked {
                dragAction = .none
                return
            }
        }

        // Start drawing new selection
        pendingCandidate = nil
        pendingCandidateRect = nil
        selectionOrigin = point
        selectionRect = NSRect(origin: point, size: .zero)
        state = .drawing
        dragAction = .drawNew
        delegate?.selectionDidStart()
        needsDisplay = true
    }

    private func shouldSuspendFromMaskDoubleClick(event: NSEvent, point: NSPoint) -> Bool {
        guard event.clickCount >= 2,
              state == .selected,
              selectionLocked,
              let rect = selectionRect
        else { return false }
        return !rect.contains(point)
    }

    private func shouldConfirmFromSelectionDoubleClick(event: NSEvent, point: NSPoint) -> Bool {
        guard event.clickCount >= 2,
              state == .selected,
              selectionLocked,
              selectionInteractionEnabled,
              let rect = selectionRect
        else { return false }
        return rect.contains(point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard selectionInteractionEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)

        switch dragAction {
        case .drawNew:
            // If still within click threshold, keep the pending smart candidate alive
            if pendingCandidateRect != nil {
                let dx = abs(point.x - dragStart.x)
                let dy = abs(point.y - dragStart.y)
                if dx < windowClickThreshold && dy < windowClickThreshold {
                    return  // no visual update yet — wait for more movement or mouseUp
                }
                // Drag exceeded threshold → discard smart snap, proceed with free draw
                pendingCandidate = nil
                pendingCandidateRect = nil
            }
            NSCursor.crosshair.set()
            selectionRect = SelectionView.dragRect(
                from: selectionOrigin,
                to: point,
                aspectRatio: aspectRatio,
                bounds: bounds
            )
            needsDisplay = true

        case .move:
            NSCursor.closedHand.set()
            guard let _ = selectionRect else { return }
            let dx = point.x - dragStart.x
            let dy = point.y - dragStart.y
            var newRect = dragOriginalRect.offsetBy(dx: dx, dy: dy)
            // Clamp to view bounds
            newRect.origin.x = max(0, min(bounds.width - newRect.width, newRect.origin.x))
            newRect.origin.y = max(0, min(bounds.height - newRect.height, newRect.origin.y))
            selectionRect = newRect
            delegate?.selectionDidChange(rect: newRect, inView: self)
            needsDisplay = true

        case .resize(let handle):
            let newRect = SelectionView.resizedRect(
                from: dragOriginalRect,
                handle: handle,
                currentPoint: point,
                aspectRatio: aspectRatio,
                bounds: bounds
            )
            selectionRect = newRect
            delegate?.selectionDidChange(rect: newRect, inView: self)
            needsDisplay = true

        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard selectionInteractionEnabled else {
            dragAction = .none
            return
        }

        switch dragAction {
        case .drawNew:
            // Click without drag → confirm the pending smart candidate
            if let candidateRect = pendingCandidateRect,
               let candidate = pendingCandidate {
                pendingCandidate = nil
                pendingCandidateRect = nil
                selectionRect = candidateRect
                state = .selected
                dragAction = .none
                delegate?.selectionDidComplete(
                    rect: candidateRect,
                    inView: self,
                    isWindowSelection: candidate.isWindowSelection,
                    windowID: candidate.windowID
                )
                needsDisplay = true
                return
            }
            guard let rect = selectionRect, rect.width >= 5, rect.height >= 5 else {
                selectionRect = nil
                state = .idle
                dragAction = .none
                needsDisplay = true
                return
            }
            state = .selected
            delegate?.selectionDidComplete(rect: rect, inView: self, isWindowSelection: false, windowID: nil)
            needsDisplay = true

        case .move, .resize:
            if let rect = selectionRect {
                delegate?.selectionDidComplete(rect: rect, inView: self, isWindowSelection: false, windowID: nil)
            }
            needsDisplay = true

        case .none:
            break
        }

        dragAction = .none
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if refreshEditorCursor(at: point) != nil {
            return
        }

        guard selectionInteractionEnabled else {
            NSCursor.arrow.set()
            return
        }

        // In idle state, resolve smart candidates under the cursor for hover highlight
        if state == .idle && !selectionLocked {
            updateSmartSelectionHover(with: event)
            return
        }

        guard state == .selected, let rect = selectionRect else {
            if !selectionLocked {
                NSCursor.crosshair.set()
            }
            return
        }

        if let handle = hitTestHandle(point: point, rect: rect) {
            SelectionView.setCursorForHandle(handle)
        } else if rect.contains(point) {
            if annotationToolActive {
                NSCursor.crosshair.set()
            } else {
                NSCursor.openHand.set()
            }
        } else {
            NSCursor.crosshair.set()
        }
    }

    // MARK: - Smart Selection Hover

    private var currentHoverCandidate: SmartSelectionCandidate? {
        hoverState.currentCandidate
    }

    private func updateSmartSelectionHover(with event: NSEvent) {
        guard let win = self.window else {
            clearHover()
            NSCursor.crosshair.set()
            return
        }

        // Convert view point → screen point
        let viewPoint = convert(event.locationInWindow, from: nil)
        let windowPoint = convert(viewPoint, to: nil)
        let screenPoint = win.convertPoint(toScreen: windowPoint)
        updateSmartSelectionHover(screenPoint: screenPoint)
    }

    private func updateSmartSelectionHover(screenPoint: NSPoint) {
        guard let detector = windowDetector,
              let win = self.window,
              let screen = win.screen,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else {
            clearHover()
            NSCursor.crosshair.set()
            return
        }

        // Convert screen point → CG point
        let primaryHeight = NSScreen.screens[0].frame.height
        let cgPoint = CGPoint(x: screenPoint.x, y: primaryHeight - screenPoint.y)
        let pointerMoved = lastHoverCGPoint != cgPoint
        if pointerMoved {
            hoverState.resetManualCycle()
        }
        let screenFrame = CGDisplayBounds(displayID)
        var baseCandidates = detector.baseCandidates(
            at: cgPoint,
            screenFrame: screenFrame,
            displayID: displayID
        )
        if let previous = currentHoverCandidate,
           case .element = previous.kind,
           previous.frame.contains(cgPoint) {
            baseCandidates.insert(previous, at: 0)
        }
        lastHoverCGPoint = cgPoint
        applyHoverCandidates(baseCandidates, preservingCurrent: !pointerMoved)

        guard !baseCandidates.isEmpty else {
            clearHover()
            NSCursor.crosshair.set()
            return
        }

        detector.requestCandidates(
            at: cgPoint,
            screenFrame: screenFrame,
            displayID: displayID
        ) { [weak self] candidates in
            guard let self,
                  self.state == .idle,
                  !self.selectionLocked,
                  self.lastHoverCGPoint == cgPoint
            else { return }
            self.applyHoverCandidates(
                candidates,
                preservingCurrent: self.hoverState.hasManuallyCycledCandidate
            )
        }
    }

    private func applyHoverCandidates(
        _ candidates: [SmartSelectionCandidate],
        preservingCurrent: Bool
    ) {
        guard !candidates.isEmpty else {
            clearHover()
            NSCursor.crosshair.set()
            return
        }

        hoverState.replaceCandidates(candidates, preservingCurrent: preservingCurrent)
        applyCurrentHoverCandidate()
        NSCursor.pointingHand.set()
    }

    private func applyCurrentHoverCandidate() {
        guard let candidate = currentHoverCandidate,
              let screen = window?.screen else {
            clearHover()
            return
        }

        let primaryHeight = NSScreen.screens[0].frame.height
        let appKitY = primaryHeight - candidate.frame.origin.y - candidate.frame.height
        let viewRect = NSRect(
            x: candidate.frame.origin.x - screen.frame.origin.x,
            y: appKitY - screen.frame.origin.y,
            width: candidate.frame.width,
            height: candidate.frame.height
        )
        let clamped = viewRect.intersection(bounds)
        guard !clamped.isNull, clamped.width > 1, clamped.height > 1 else {
            clearHover()
            return
        }

        if hoverCandidateRect != clamped || hoverCandidateFullRect != viewRect {
            hoverCandidateRect = clamped
            hoverCandidateFullRect = viewRect
            needsDisplay = true
        }
    }

    private func clearHover() {
        if hoverCandidateRect != nil || !hoverState.isEmpty {
            hoverState.clear()
            hoverCandidateRect = nil
            hoverCandidateFullRect = nil
            lastHoverCGPoint = nil
            needsDisplay = true
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // A long-screenshot crop should read as a panel over the live desktop,
        // not as a newly opened full-screen interface. Clear the transparent
        // overlay outside the selection; ScrollCropView paints only its own
        // selection-sized frame above this view.
        if cropPresentationActive {
            context.clear(bounds)
            return
        }

        // Draw pre-captured screen snapshot as background so transient
        // menus/popups remain visible even after they dismiss.
        // Skip during scroll capture so live scrolling content shows through.
        if let snapshot = backgroundSnapshot, !scrollCaptureActive {
            snapshot.draw(in: bounds)
        }

        // Hover highlight for smart selection (idle state, before any click)
        if state == .idle, let hoverRect = hoverCandidateRect {
            // Dark overlay with cutout (even-odd fill preserves snapshot underneath)
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addRect(hoverRect)
            context.setFillColor(NSColor.black.withAlphaComponent(dimmingOverlayAlpha).cgColor)
            context.addPath(path)
            context.fillPath(using: .evenOdd)
            // Solid accent border
            context.setStrokeColor(accentColor.cgColor)
            let hoverLineWidth = borderWidth + 1
            context.setLineWidth(hoverLineWidth)
            if let hoverBorderRect = SmartSelectionPolicy.hoverBorderRect(
                candidateRect: hoverRect,
                drawableBounds: bounds,
                lineWidth: hoverLineWidth
            ) {
                context.stroke(hoverBorderRect)
            }
            // Size label
            SelectionView.drawSizeLabel(context: context, rect: hoverRect)
            return
        }

        // In idle state with no selection, just show the snapshot (already drawn above)
        guard let rect = selectionRect, (state == .drawing || state == .selected),
              rect.width > 0 || rect.height > 0 else {
            return
        }

        // Dark overlay with cutout (even-odd fill preserves snapshot underneath).
        // During scroll capture, enlarge the cutout by 0.5pt so anti-aliasing
        // at the cutout edge falls outside the captured rect instead of
        // darkening its first pixel — otherwise every frame's bottom edge
        // leaves a gray line at each stitch seam.
        let path = CGMutablePath()
        path.addRect(bounds)
        let cutoutRect = scrollCaptureActive ? rect.insetBy(dx: -0.5, dy: -0.5) : rect
        path.addRect(cutoutRect)
        context.setFillColor(NSColor.black.withAlphaComponent(dimmingOverlayAlpha).cgColor)
        context.addPath(path)
        context.fillPath(using: .evenOdd)

        // Draw border — solid red during scroll capture, accent-blue dashed otherwise
        if scrollCaptureActive {
            // ScreenCaptureKit sees the overlay panel, so any stroke pixels
            // inside `rect` bleed into every captured frame and produce thin
            // red lines at the left/right edges and at each stitch seam.
            // Inset enough that the stroke (and its anti-aliased fringe) sits
            // entirely outside the captured rect.
            let strokeWidth: CGFloat = borderWidth + 1
            let outerInset = -(strokeWidth / 2 + 1)
            context.setStrokeColor(NSColor.systemRed.cgColor)
            context.setLineWidth(strokeWidth)
            context.stroke(rect.insetBy(dx: outerInset, dy: outerInset))
        } else {
            context.setStrokeColor(accentColor.cgColor)
            context.setLineWidth(borderWidth)
            context.setLineDash(phase: 0, lengths: dashPattern)
            context.stroke(rect.insetBy(dx: -1, dy: -1))
            context.setLineDash(phase: 0, lengths: [])
        }

        if state == .selected && selectionInteractionEnabled {
            // Draw 8 control handles
            drawHandles(context: context, rect: rect)
            // Draw size label
            SelectionView.drawSizeLabel(context: context, rect: rect)
        } else if state == .selected, let selectionSizeLabelOverride {
            SelectionView.drawSizeLabel(context: context, rect: rect, text: selectionSizeLabelOverride)
        }
    }

    private func drawHandles(context: CGContext, rect: NSRect) {
        let positions = SelectionView.handlePositions(for: rect)
        for pos in positions {
            let handleRect = NSRect(
                x: pos.x - handleSize / 2,
                y: pos.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            context.setFillColor(accentColor.cgColor)
            context.fillEllipse(in: handleRect)
        }
    }

    static func drawSizeLabel(context: CGContext, rect: NSRect, text: String? = nil) {
        let text = text ?? "\(Int(rect.width)) x \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ]
        let size = text.size(withAttributes: attrs)
        // Position above the top-left corner of selection
        let labelX = rect.origin.x
        let labelY = rect.origin.y + rect.height + 4  // Above top edge (AppKit coords: y increases upward)
        let labelRect = NSRect(x: labelX, y: labelY, width: size.width + 8, height: size.height + 4)

        // Draw background
        context.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        let bgPath = CGPath(roundedRect: labelRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        context.addPath(bgPath)
        context.fillPath()

        // Draw text
        let textOrigin = NSPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2)
        text.draw(at: textOrigin, withAttributes: attrs)
    }

    // MARK: - Handle Positions

    static func handlePositions(for rect: NSRect) -> [NSPoint] {
        let minX = rect.minX, midX = rect.midX, maxX = rect.maxX
        let minY = rect.minY, midY = rect.midY, maxY = rect.maxY
        return [
            NSPoint(x: minX, y: maxY),  // topLeft
            NSPoint(x: maxX, y: maxY),  // topRight
            NSPoint(x: minX, y: minY),  // bottomLeft
            NSPoint(x: maxX, y: minY),  // bottomRight
            NSPoint(x: midX, y: maxY),  // topCenter
            NSPoint(x: midX, y: minY),  // bottomCenter
            NSPoint(x: minX, y: midY),  // leftCenter
            NSPoint(x: maxX, y: midY),  // rightCenter
        ]
    }

    static func hitTestHandle(point: NSPoint, rect: NSRect, hitSize: CGFloat) -> HandlePosition? {
        let positions = handlePositions(for: rect)
        let handles = HandlePosition.allCases
        for (i, pos) in positions.enumerated() {
            let hitRect = NSRect(
                x: pos.x - hitSize / 2,
                y: pos.y - hitSize / 2,
                width: hitSize,
                height: hitSize
            )
            if hitRect.contains(point) {
                return handles[i]
            }
        }
        return nil
    }

    private func hitTestHandle(point: NSPoint, rect: NSRect) -> HandlePosition? {
        SelectionView.hitTestHandle(point: point, rect: rect, hitSize: handleHitSize)
    }

    // MARK: - Resize Logic

    private static func dragRect(from origin: NSPoint, to point: NSPoint, aspectRatio: CGFloat?, bounds: NSRect) -> NSRect {
        guard let ratio = normalizedAspectRatio(aspectRatio) else {
            let x = min(origin.x, point.x)
            let y = min(origin.y, point.y)
            let width = abs(point.x - origin.x)
            let height = abs(point.y - origin.y)
            return NSRect(x: x, y: y, width: width, height: height)
        }

        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let unconstrainedWidth = abs(dx)
        let unconstrainedHeight = abs(dy)
        let constrainedWidth = max(unconstrainedWidth, unconstrainedHeight * ratio)
        let constrainedHeight = constrainedWidth / ratio
        let maxWidth = dx < 0 ? origin.x - bounds.minX : bounds.maxX - origin.x
        let maxHeight = dy < 0 ? origin.y - bounds.minY : bounds.maxY - origin.y
        let size = fittedAspectSize(
            CGSize(width: constrainedWidth, height: constrainedHeight),
            aspectRatio: ratio,
            maximumWidth: maxWidth,
            maximumHeight: maxHeight
        )
        let signedWidth = dx < 0 ? -size.width : size.width
        let signedHeight = dy < 0 ? -size.height : size.height
        let maxX = origin.x + signedWidth
        let maxY = origin.y + signedHeight

        return NSRect(
            x: min(origin.x, maxX),
            y: min(origin.y, maxY),
            width: abs(signedWidth),
            height: abs(signedHeight)
        )
    }

    static func resizedRect(
        from original: NSRect,
        handle: HandlePosition,
        currentPoint: NSPoint,
        aspectRatio: CGFloat? = nil,
        bounds: NSRect
    ) -> NSRect {
        let minimumSize: CGFloat = 5
        var minX = original.minX
        var minY = original.minY
        var maxX = original.maxX
        var maxY = original.maxY

        switch handle {
        case .topLeft:
            minX = min(currentPoint.x, maxX - minimumSize)
            maxY = max(currentPoint.y, minY + minimumSize)
        case .topRight:
            maxX = max(currentPoint.x, minX + minimumSize)
            maxY = max(currentPoint.y, minY + minimumSize)
        case .bottomLeft:
            minX = min(currentPoint.x, maxX - minimumSize)
            minY = min(currentPoint.y, maxY - minimumSize)
        case .bottomRight:
            maxX = max(currentPoint.x, minX + minimumSize)
            minY = min(currentPoint.y, maxY - minimumSize)
        case .topCenter:
            maxY = max(currentPoint.y, minY + minimumSize)
        case .bottomCenter:
            minY = min(currentPoint.y, maxY - minimumSize)
        case .leftCenter:
            minX = min(currentPoint.x, maxX - minimumSize)
        case .rightCenter:
            maxX = max(currentPoint.x, minX + minimumSize)
        }

        let unconstrained = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard let ratio = normalizedAspectRatio(aspectRatio) else { return unconstrained }
        return aspectLockedRect(
            from: unconstrained,
            original: original,
            handle: handle,
            aspectRatio: ratio,
            minimumSize: minimumSize,
            bounds: bounds
        )
    }

    private static func normalizedAspectRatio(_ aspectRatio: CGFloat?) -> CGFloat? {
        guard let aspectRatio, aspectRatio > 0, aspectRatio.isFinite else { return nil }
        return aspectRatio
    }

    private static func aspectLockedRect(
        from unconstrained: NSRect,
        original: NSRect,
        handle: HandlePosition,
        aspectRatio: CGFloat,
        minimumSize: CGFloat,
        bounds: NSRect
    ) -> NSRect {
        switch handle {
        case .topLeft:
            let size = fittedAspectSize(
                aspectSize(
                    fittingWidth: unconstrained.width,
                    height: unconstrained.height,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: original.maxX - bounds.minX,
                maximumHeight: bounds.maxY - original.minY
            )
            return NSRect(x: original.maxX - size.width, y: original.minY, width: size.width, height: size.height)
        case .topRight:
            let size = fittedAspectSize(
                aspectSize(
                    fittingWidth: unconstrained.width,
                    height: unconstrained.height,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: bounds.maxX - original.minX,
                maximumHeight: bounds.maxY - original.minY
            )
            return NSRect(x: original.minX, y: original.minY, width: size.width, height: size.height)
        case .bottomLeft:
            let size = fittedAspectSize(
                aspectSize(
                    fittingWidth: unconstrained.width,
                    height: unconstrained.height,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: original.maxX - bounds.minX,
                maximumHeight: original.maxY - bounds.minY
            )
            return NSRect(x: original.maxX - size.width, y: original.maxY - size.height, width: size.width, height: size.height)
        case .bottomRight:
            let size = fittedAspectSize(
                aspectSize(
                    fittingWidth: unconstrained.width,
                    height: unconstrained.height,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: bounds.maxX - original.minX,
                maximumHeight: original.maxY - bounds.minY
            )
            return NSRect(x: original.minX, y: original.maxY - size.height, width: size.width, height: size.height)
        case .topCenter:
            let size = fittedAspectSize(
                aspectSize(
                    fromHeight: unconstrained.height,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: symmetricMaximumLength(around: original.midX, lowerBound: bounds.minX, upperBound: bounds.maxX),
                maximumHeight: bounds.maxY - original.minY
            )
            return NSRect(x: original.midX - size.width / 2, y: original.minY, width: size.width, height: size.height)
        case .bottomCenter:
            let size = fittedAspectSize(
                aspectSize(
                    fromHeight: unconstrained.height,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: symmetricMaximumLength(around: original.midX, lowerBound: bounds.minX, upperBound: bounds.maxX),
                maximumHeight: original.maxY - bounds.minY
            )
            return NSRect(x: original.midX - size.width / 2, y: original.maxY - size.height, width: size.width, height: size.height)
        case .leftCenter:
            let size = fittedAspectSize(
                aspectSize(
                    fromWidth: unconstrained.width,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: original.maxX - bounds.minX,
                maximumHeight: symmetricMaximumLength(around: original.midY, lowerBound: bounds.minY, upperBound: bounds.maxY)
            )
            return NSRect(x: original.maxX - size.width, y: original.midY - size.height / 2, width: size.width, height: size.height)
        case .rightCenter:
            let size = fittedAspectSize(
                aspectSize(
                    fromWidth: unconstrained.width,
                    aspectRatio: aspectRatio,
                    minimumSize: minimumSize
                ),
                aspectRatio: aspectRatio,
                maximumWidth: bounds.maxX - original.minX,
                maximumHeight: symmetricMaximumLength(around: original.midY, lowerBound: bounds.minY, upperBound: bounds.maxY)
            )
            return NSRect(x: original.minX, y: original.midY - size.height / 2, width: size.width, height: size.height)
        }
    }

    private static func fittedAspectSize(
        _ size: CGSize,
        aspectRatio: CGFloat,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> CGSize {
        let width = min(size.width, max(0, maximumWidth), max(0, maximumHeight) * aspectRatio)
        return CGSize(width: width, height: width / aspectRatio)
    }

    private static func symmetricMaximumLength(around center: CGFloat, lowerBound: CGFloat, upperBound: CGFloat) -> CGFloat {
        2 * max(0, min(center - lowerBound, upperBound - center))
    }

    private static func aspectSize(
        fittingWidth width: CGFloat,
        height: CGFloat,
        aspectRatio: CGFloat,
        minimumSize: CGFloat
    ) -> CGSize {
        var constrainedWidth = max(width, height * aspectRatio, minimumSize)
        var constrainedHeight = constrainedWidth / aspectRatio
        if constrainedHeight < minimumSize {
            constrainedHeight = minimumSize
            constrainedWidth = constrainedHeight * aspectRatio
        }
        return CGSize(width: constrainedWidth, height: constrainedHeight)
    }

    private static func aspectSize(
        fromHeight height: CGFloat,
        aspectRatio: CGFloat,
        minimumSize: CGFloat
    ) -> CGSize {
        var constrainedHeight = max(height, minimumSize)
        var constrainedWidth = constrainedHeight * aspectRatio
        if constrainedWidth < minimumSize {
            constrainedWidth = minimumSize
            constrainedHeight = constrainedWidth / aspectRatio
        }
        return CGSize(width: constrainedWidth, height: constrainedHeight)
    }

    private static func aspectSize(
        fromWidth width: CGFloat,
        aspectRatio: CGFloat,
        minimumSize: CGFloat
    ) -> CGSize {
        var constrainedWidth = max(width, minimumSize)
        var constrainedHeight = constrainedWidth / aspectRatio
        if constrainedHeight < minimumSize {
            constrainedHeight = minimumSize
            constrainedWidth = constrainedHeight * aspectRatio
        }
        return CGSize(width: constrainedWidth, height: constrainedHeight)
    }

    // MARK: - Cursor

    static func setCursorForHandle(_ handle: HandlePosition) {
        switch handle {
        case .topLeft:
            ResizeHandleCursor.setFrameResizeCursor(for: .topLeft)
        case .topRight:
            ResizeHandleCursor.setFrameResizeCursor(for: .topRight)
        case .bottomLeft:
            ResizeHandleCursor.setFrameResizeCursor(for: .bottomLeft)
        case .bottomRight:
            ResizeHandleCursor.setFrameResizeCursor(for: .bottomRight)
        case .topCenter:
            ResizeHandleCursor.setFrameResizeCursor(for: .top)
        case .bottomCenter:
            ResizeHandleCursor.setFrameResizeCursor(for: .bottom)
        case .leftCenter:
            ResizeHandleCursor.setFrameResizeCursor(for: .left)
        case .rightCenter:
            ResizeHandleCursor.setFrameResizeCursor(for: .right)
        }
    }

    // MARK: - Configuration

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
}
