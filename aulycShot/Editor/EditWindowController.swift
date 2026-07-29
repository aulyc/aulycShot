import AppKit
import Carbon
import QuartzCore
import UniformTypeIdentifiers

class EditWindowController {
    static func startupTool(isPresetImage: Bool) -> EditTool? {
        isPresetImage ? nil : .rectangle
    }

    static func showsShapeStrokeStyleControl(for tool: EditTool) -> Bool {
        false
    }

    static func normalizedShapeStrokeStyle(
        _ strokeStyle: ShapeStrokeStyle,
        for tool: EditTool
    ) -> ShapeStrokeStyle {
        switch tool {
        case .rectangle, .ellipse:
            return .standard
        default:
            return strokeStyle
        }
    }

    static func showsArrowStyleControl(for tool: EditTool) -> Bool {
        false
    }

    static func normalizedArrowStyle(
        _ arrowStyle: ArrowStyle,
        for tool: EditTool
    ) -> ArrowStyle {
        tool == .arrow ? .line : arrowStyle
    }

    private var canvasView: EditCanvasView?
    private var canvasScrollView: EditorScrollView?
    private var selectionChromeOverlay: SelectionChromeOverlay?
    private weak var hostSelectionView: SelectionView?
    private var toolbarView: ToolbarView?
    /// Optional vertical toolbar on the left/right of the selection. Created
    /// only when the user has assigned tools to it in settings.
    private var sideToolbarView: ToolbarView?
    private var subToolbarView: NSView?
    private var qrCodeOverlayView: QRCodeChoiceOverlayView?
    private var qrCodeDetectionGeneration = 0
    private var captureRect: CGRect
    private var screen: NSScreen
    private var selectionRect: NSRect
    private var selectionViewRect: NSRect
    private let onComplete: (NSImage?) -> Void
    private let onRecordingSelection: ((NSRect, NSScreen) -> Void)?
    private let onRequestFocusReturn: (() -> Void)?
    private var activeTool: EditTool = .none

    /// True when the capture came from clicking a single window (not a free
    /// drag). Drives the rounded-corner + drop-shadow effect on the final
    /// output. Cleared by OverlayWindowController if the user resizes the
    /// selection, since the rect no longer matches the window.
    var isWindowCapture: Bool = false

    // Pre-captured screen snapshot (preserves transient menus/popups)
    private let preSnapshot: CGImage?

    /// Image-edit mode: when set, this image replaces the screen-capture
    /// pipeline as the editor's base image (no live capture, no preSnapshot
    /// crop). Also disables scroll capture, which is a screen-only concept.
    private let overrideBaseImage: NSImage?

    /// Single-window capture with the WindowServer's real alpha silhouette.
    /// Used as the base image and annotation clip mask for clicked-window
    /// captures so the final corners match the system window exactly.
    private let windowBaseImage: NSImage?

    // Scroll capture state
    private var scrollCapturer: ScrollCapturer?
    private var isScrollCapturing = false
    private var isScrollCaptureFinalizing = false
    private var scrollCaptureControlWindow: ScrollCaptureControlWindow?
    private var scrollPreviewWindow: ScrollPreviewWindow?
    /// Persistent finish hint shown inside the selection during scroll
    /// capture. Excluded from the capture so it never appears in
    /// the stitched long screenshot.
    private var scrollCaptureHintWindow: ScrollCaptureHintWindow?
    private var autoScroller: AutoScroller?
    private var manualScrollCaptureTimer: DispatchSourceTimer?
    /// Key monitor while aulycShot is deactivated for scroll capture, so any key
    /// stops scrolling and moves on to crop mode.
    private var scrollCaptureKeyMonitor: Any?
    private var scrollCaptureDiagnosticID: String?
    private var scrollCaptureModeName: String?

    // Crop mode state — shown between scroll capture and the editor so the
    // user can trim any content auto-scroll over-shot.
    private var isCropping = false
    private var scrollCropView: ScrollCropView?
    private var scrollCropControlWindow: ScrollCropControlWindow?

    private var isScrollCaptureBusy: Bool {
        isScrollCapturing || isScrollCaptureFinalizing
    }

    private var isLiveScreenCaptureSession: Bool {
        overrideBaseImage == nil && onRecordingSelection != nil
    }

    private var isScrollCaptureAllowed: Bool {
        isLiveScreenCaptureSession && !isWindowCapture
    }

    struct RestorableState {
        let canvasState: EditCanvasView.RestorableState
    }

    // Drawing properties
    private var currentColor: NSColor = EditorStyleDefaults.primaryColor
    private var currentLineWidth: CGFloat = EditorStyleDefaults.standardLineWidth
    private var currentArrowStyle: ArrowStyle = .line
    private var currentMosaicBlockSize: CGFloat = CGFloat(Defaults.mosaicBlockSize)
    private var currentFontSize: CGFloat = CGFloat(Defaults.lastTextFontSize)
    /// Whether new text annotations get a contrast outline.
    private var currentTextStroke: Bool = Defaults.lastTextStroke
    /// Whether new text annotations render as callout bubbles with an arrow handle.
    private var currentTextCallout: Bool = Defaults.lastTextCallout
    /// Whether new rectangle/ellipse annotations are filled.
    private var currentShapeFillMode: ShapeFillMode = Defaults.lastShapeFillMode
    private var currentShapeStrokeStyle: ShapeStrokeStyle = .standard
    /// Marker keeps its own color/size slot so toggling between pen and
    /// marker preserves each tool's last-used choice.
    private var currentMarkerColor: NSColor = EditorStyleDefaults.markerColor
    private var currentMarkerLineWidth: CGFloat = EditorStyleDefaults.markerLineWidth
    var isTextEditing: Bool {
        canvasView?.isTextEditing == true
    }

    init(
        captureRect: CGRect,
        screen: NSScreen,
        selectionRect: NSRect,
        selectionViewRect: NSRect,
        hostSelectionView: SelectionView,
        preSnapshot: CGImage? = nil,
        overrideBaseImage: NSImage? = nil,
        windowBaseImage: NSImage? = nil,
        isWindowCapture: Bool = false,
        onRecordingSelection: ((NSRect, NSScreen) -> Void)? = nil,
        onRequestFocusReturn: (() -> Void)? = nil,
        onComplete: @escaping (NSImage?) -> Void
    ) {
        self.captureRect = captureRect
        self.screen = screen
        self.selectionRect = selectionRect
        self.selectionViewRect = selectionViewRect
        self.hostSelectionView = hostSelectionView
        self.preSnapshot = preSnapshot
        self.overrideBaseImage = overrideBaseImage
        self.windowBaseImage = windowBaseImage
        self.isWindowCapture = isWindowCapture
        self.onRecordingSelection = onRecordingSelection
        self.onRequestFocusReturn = onRequestFocusReturn
        self.onComplete = onComplete
    }

    func show() {
        guard let hostSelectionView else {
            onComplete(nil)
            requestFocusReturn()
            return
        }

        let canvasSize = canvasContentSize(for: selectionViewRect.size)
        let scrollView = EditorScrollView(frame: selectionViewRect)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = canvasSize.height > selectionViewRect.height + 0.5
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false

        let canvas = EditCanvasView(frame: NSRect(origin: .zero, size: canvasSize))
        canvas.captureRect = captureRect
        canvas.captureScreen = screen
        canvas.preSnapshot = preSnapshot
        canvas.overrideBaseImage = overrideBaseImage
        canvas.windowBaseImage = windowBaseImage
        canvas.autoresizingMask = []
        canvas.onAnnotationSelected = { [weak self] annotation in
            self?.handleAnnotationSelectionChanged(annotation)
        }
        canvas.onMultiSelectionChanged = { [weak self] isMultiSelecting in
            if isMultiSelecting {
                self?.selectTool(.none)
            }
        }
        canvas.onHistoryStateChanged = { [weak self] canUndo, canRedo in
            self?.updateHistoryButtons(canUndo: canUndo, canRedo: canRedo)
        }
        scrollView.documentView = canvas
        scrollView.editorCanvasView = canvas
        scrollView.isInteractionEnabled = overrideBaseImage != nil

        self.canvasScrollView = scrollView
        self.canvasView = canvas
        hostSelectionView.refreshAnnotationCursor = { [weak canvas] in
            canvas?.refreshCursorAtCurrentLocation()
        }
        canvas.onCursorRefreshRequested = { [weak hostSelectionView] in
            hostSelectionView?.refreshEditorCursorAtCurrentMouseLocation()
        }
        hostSelectionView.addSubview(scrollView)
        resetCanvasScrollPosition()

        // Sits above `scrollView` so the selection border remains interactive
        // after the editor canvas takes ownership of the selection interior.
        // Handles resize, the border moves the selection, and all other hits
        // fall through to the canvas / SelectionView underneath.
        let overlay = SelectionChromeOverlay(frame: hostSelectionView.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.selectionView = hostSelectionView
        overlay.onMoveStart = { [weak self] in
            self?.canvasView?.commitActiveTextEditing()
        }
        overlay.update(rect: selectionViewRect)
        hostSelectionView.addSubview(overlay)
        self.selectionChromeOverlay = overlay

        showToolbar()
        if let startupTool = Self.startupTool(isPresetImage: overrideBaseImage != nil) {
            selectTool(startupTool)
        }
        updateHistoryButtons(canUndo: canvas.canUndo, canRedo: canvas.canRedo)
        bringEditorToFront()
    }

    private func showToolbar() {
        guard let hostSelectionView else { return }
        let layout = Defaults.toolbarLayout

        // Each toolbar exists only when the user has assigned tools to it.
        if !layout.primary.isEmpty {
            let tv = ToolbarView(items: layout.primary, orientation: .horizontal)
            wireToolbarCallbacks(tv)
            tv.frame = toolbarRect(in: hostSelectionView.bounds, size: tv.preferredSize)
            styleFloatingHUD(tv)
            self.toolbarView = tv
            hostSelectionView.addSubview(tv)
        }

        if !layout.side.isEmpty {
            let sv = ToolbarView(items: layout.side, orientation: .vertical)
            wireToolbarCallbacks(sv)
            sv.frame = sideToolbarRect(
                in: hostSelectionView.bounds,
                size: sv.preferredSize,
                avoiding: toolbarView?.frame
            )
            styleFloatingHUD(sv)
            self.sideToolbarView = sv
            hostSelectionView.addSubview(sv)
        }

        updateCaptureActionAvailability()
    }

    /// Injects the controller's action callbacks into a toolbar. Both the
    /// primary and the side toolbar share the same wiring — a tool behaves
    /// identically regardless of which bar it was dragged to.
    private func wireToolbarCallbacks(_ tv: ToolbarView) {
        tv.onToolSelected = { [weak self] tool in self?.selectTool(tool) }
        tv.onUndo = { [weak self] in _ = self?.canvasView?.undo() }
        tv.onRedo = { [weak self] in _ = self?.canvasView?.redo() }
        tv.onScrollCapture = { [weak self] in self?.toggleScrollCapture() }
        tv.onInsertImage = { [weak self] in self?.showInsertImageMenu() }
        tv.onQRCode = { [weak self] in self?.performQRCodeRecognition() }
        tv.onSave = { [weak self] in self?.save() }
        tv.onPin = { [weak self] in self?.pin() }
        tv.onRecord = { [weak self] in self?.record() }
        tv.onClose = { [weak self] in self?.close() }
        tv.onConfirm = { [weak self] in self?.confirm() }
    }

    /// Primary + side toolbars currently on screen.
    private var toolbars: [ToolbarView] {
        [toolbarView, sideToolbarView].compactMap { $0 }
    }

    private func updateHistoryButtons(canUndo: Bool, canRedo: Bool) {
        toolbars.forEach {
            $0.setUndoEnabled(canUndo)
            $0.setRedoEnabled(canRedo)
        }
    }

    private func updateCaptureActionAvailability() {
        let scrollCaptureEnabled = isScrollCaptureAllowed && !isScrollCaptureBusy && canvasView?.hasPreviewImage != true
        let recordingEnabled = isLiveScreenCaptureSession && !isScrollCaptureBusy
        toolbars.forEach {
            $0.setScrollCaptureEnabled(scrollCaptureEnabled)
            $0.setRecordingEnabled(recordingEnabled)
        }
    }

    /// Frame the option sub-toolbars (color/size and text) anchor
    /// against — the primary toolbar when it exists, otherwise the side
    /// toolbar, so options still appear if the user emptied the primary bar.
    private var subToolbarAnchorFrame: NSRect? {
        toolbarView?.frame ?? sideToolbarView?.frame
    }

    func updateLayout(selectionRect: NSRect, selectionViewRect: NSRect, captureRect: CGRect) {
        dismissQRCodeOverlay()
        self.selectionRect = selectionRect
        self.selectionViewRect = selectionViewRect
        self.captureRect = captureRect

        if !isWindowCapture {
            canvasView?.windowBaseImage = nil
        }

        let canvasSize = canvasContentSize(for: selectionViewRect.size)
        canvasView?.updateViewportSize(canvasSize)
        canvasView?.captureRect = captureRect
        canvasView?.captureScreen = screen

        canvasView?.needsDisplay = true
        updateCanvasFrame()

        updateCaptureActionAvailability()
        repositionFloatingChrome()
    }

    private func canvasContentSize(for viewportSize: NSSize) -> NSSize {
        guard
            let image = overrideBaseImage,
            image.size.width > 0,
            image.size.height > 0,
            viewportSize.width > 0
        else {
            return viewportSize
        }

        let scale = viewportSize.width / image.size.width
        return NSSize(
            width: viewportSize.width,
            height: max(1, floor(image.size.height * scale))
        )
    }

    private func selectTool(_ tool: EditTool) {
        dismissQRCodeOverlay()

        if tool != .none {
            canvasView?.clearMultiSelection()
        }
        activeTool = tool
        canvasView?.activeTool = tool
        normalizeShapeStrokeStyle(for: tool)
        normalizeArrowStyle(for: tool)
        pushCurrentStyleToCanvas()
        toolbars.forEach { $0.updateSelection(tool: tool) }
        updateEditorInteractionState()

        showSubToolbar(for: tool)

        // Restore focus to the overlay window after toolbar interaction so
        // keyboard input no longer falls through to the captured app.
        bringEditorToFront()
    }

    /// Selection in the canvas changed. When an annotation gets selected we
    /// switch to its matching tool and rebuild the sub-toolbar with the
    /// annotation's own values, so the user can adjust color / size /
    /// font-size of the selected mark without entering edit mode.
    private func handleAnnotationSelectionChanged(_ annotation: Annotation?) {
        guard let annotation else { return }
        guard let tool = tool(for: annotation), tool != .none else { return }

        seedCurrentValues(from: annotation)
        normalizeShapeStrokeStyle(for: tool)
        normalizeArrowStyle(for: tool)
        pushCurrentStyleToCanvas()

        if activeTool != tool {
            // selectTool rebuilds the sub-toolbar; the seeded values flow in.
            selectTool(tool)
        } else {
            // Same tool — rebuild the sub-toolbar to refresh displayed values.
            showSubToolbar(for: tool)
        }
    }

    private func pushCurrentStyleToCanvas() {
        canvasView?.currentColor = currentColor
        canvasView?.currentLineWidth = currentLineWidth
        canvasView?.currentArrowStyle = currentArrowStyle
        canvasView?.currentMosaicBlockSize = currentMosaicBlockSize
        canvasView?.currentFontSize = currentFontSize
        canvasView?.currentTextStroke = currentTextStroke
        canvasView?.currentTextCallout = currentTextCallout
        canvasView?.currentShapeFillMode = currentShapeFillMode
        canvasView?.currentShapeStrokeStyle = currentShapeStrokeStyle
        canvasView?.currentMarkerColor = currentMarkerColor
        canvasView?.currentMarkerLineWidth = currentMarkerLineWidth
    }

    private func tool(for annotation: Annotation) -> EditTool? {
        switch annotation {
        case is TextAnnotation: return .text
        case is RectAnnotation: return .rectangle
        case is EllipseAnnotation: return .ellipse
        case is ArrowAnnotation: return .arrow
        case is LineAnnotation: return .line
        case is PenAnnotation: return .pen
        case is MarkerAnnotation: return .marker
        case is MosaicAnnotation: return .mosaic
        case is MagnifierAnnotation: return .magnifier
        case is NumberAnnotation: return .numbered
        default: return nil
        }
    }

    /// Pull color / size / font-size off the annotation into the matching
    /// "current" slot so the next sub-toolbar rebuild reflects them and
    /// any new annotation created afterward inherits the same look.
    private func seedCurrentValues(from annotation: Annotation) {
        switch annotation {
        case let t as TextAnnotation:
            currentColor = t.color
            currentFontSize = t.fontSize
            currentTextStroke = t.hasStroke
            currentTextCallout = t.hasCallout
        case let p as PenAnnotation:
            currentColor = p.color
            currentLineWidth = p.lineWidth
        case let m as MarkerAnnotation:
            currentMarkerColor = m.color
            currentMarkerLineWidth = m.lineWidth
        case let mosaic as MosaicAnnotation:
            currentMosaicBlockSize = mosaic.blockSize
            canvasView?.currentMosaicBlockSize = mosaic.blockSize
        case let magnifier as MagnifierAnnotation:
            currentColor = magnifier.color
            currentLineWidth = magnifier.lineWidth
        case let r as RectAnnotation:
            currentColor = r.color
            currentLineWidth = r.lineWidth
            currentShapeFillMode = r.fillMode
            currentShapeStrokeStyle = Self.normalizedShapeStrokeStyle(r.strokeStyle, for: .rectangle)
        case let e as EllipseAnnotation:
            currentColor = e.color
            currentLineWidth = e.lineWidth
            currentShapeFillMode = e.fillMode
            currentShapeStrokeStyle = Self.normalizedShapeStrokeStyle(e.strokeStyle, for: .ellipse)
        case let a as ArrowAnnotation:
            currentColor = a.color
            currentLineWidth = a.lineWidth
            currentArrowStyle = Self.normalizedArrowStyle(a.style, for: .arrow)
            canvasView?.currentColor = a.color
            canvasView?.currentLineWidth = a.lineWidth
            canvasView?.currentArrowStyle = currentArrowStyle
        case let l as LineAnnotation:
            currentColor = l.color
            currentLineWidth = l.lineWidth
        case let n as NumberAnnotation:
            currentColor = n.color
        default:
            break
        }
    }

    private func normalizeShapeStrokeStyle(for tool: EditTool) {
        currentShapeStrokeStyle = Self.normalizedShapeStrokeStyle(
            currentShapeStrokeStyle,
            for: tool
        )
    }

    private func normalizeArrowStyle(for tool: EditTool) {
        currentArrowStyle = Self.normalizedArrowStyle(
            currentArrowStyle,
            for: tool
        )
    }

    private func showSubToolbar(for tool: EditTool) {
        subToolbarView?.removeFromSuperview()
        subToolbarView = nil

        switch tool {
        case .pen, .line:
            showColorSizeSubToolbar(
                sizes: EditorStyleDefaults.standardLineSizes,
                currentSize: currentLineWidth,
                onSize: { [weak self] size in
                    self?.setCurrentDrawingLineWidth(size)
                }
            )
        case .arrow:
            showColorSizeSubToolbar(
                sizes: EditorStyleDefaults.standardLineSizes,
                currentSize: currentLineWidth,
                onSize: { [weak self] size in
                    self?.setCurrentDrawingLineWidth(size)
                }
            )
        case .rectangle:
            showColorSizeSubToolbar(
                sizes: EditorStyleDefaults.standardLineSizes,
                currentSize: currentLineWidth,
                width: ColorSizeSubToolbar.preferredWidth(
                    sizes: EditorStyleDefaults.standardLineSizes,
                    showsShapeFillModes: true
                ),
                onSize: { [weak self] size in
                    self?.setCurrentDrawingLineWidth(size)
                },
                shapeFillMode: currentShapeFillMode,
                onShapeFillMode: { [weak self] mode in
                    self?.setShapeFillMode(mode)
                }
            )
        case .ellipse:
            showColorSizeSubToolbar(
                sizes: EditorStyleDefaults.standardLineSizes,
                currentSize: currentLineWidth,
                width: ColorSizeSubToolbar.preferredWidth(
                    sizes: EditorStyleDefaults.standardLineSizes,
                    showsShapeFillModes: true
                ),
                onSize: { [weak self] size in
                    self?.setCurrentDrawingLineWidth(size)
                },
                shapeFillMode: currentShapeFillMode,
                onShapeFillMode: { [weak self] mode in
                    self?.setShapeFillMode(mode)
                }
            )
        case .magnifier:
            showColorSizeSubToolbar(
                sizes: EditorStyleDefaults.standardLineSizes,
                currentSize: currentLineWidth,
                onSize: { [weak self] size in
                    self?.setCurrentDrawingLineWidth(size)
                }
            )
        case .marker:
            showColorSizeSubToolbar(
                sizes: EditorStyleDefaults.markerLineSizes,
                currentColor: currentMarkerColor,
                currentSize: currentMarkerLineWidth,
                sizeMaxValue: CGFloat(Defaults.markerLineWidthMax),
                onColor: { [weak self] color in
                    self?.setCurrentMarkerColor(color)
                },
                onSize: { [weak self] size in
                    self?.setCurrentMarkerLineWidth(size)
                }
            )
        case .text:
            showTextSubToolbar()
        case .numbered:
            showColorSizeSubToolbar(
                sizes: [],
                currentSize: 0,
                width: 200
            )
        case .mosaic:
            showMosaicSubToolbar()
        case .eraser:
            // The eraser has no sub-toolbar — drag over annotations to delete.
            break
        default:
            break
        }
    }

    private func showColorSizeSubToolbar(
        sizes: [CGFloat],
        currentColor: NSColor? = nil,
        currentSize: CGFloat,
        width: CGFloat? = nil,
        sizeMinValue: CGFloat = CGFloat(Defaults.editorLineWidthMin),
        sizeMaxValue: CGFloat = CGFloat(Defaults.editorLineWidthMax),
        onColor: ((NSColor) -> Void)? = nil,
        onSize: ((CGFloat) -> Void)? = nil,
        shapeFillMode: ShapeFillMode? = nil,
        onShapeFillMode: ((ShapeFillMode) -> Void)? = nil,
        shapeStrokeStyle: ShapeStrokeStyle? = nil,
        shapeStrokePreviewShape: ShapeStrokePreviewShape = .rectangle,
        onShapeStrokeStyle: ((ShapeStrokeStyle) -> Void)? = nil,
        arrowStyle: ArrowStyle? = nil,
        onArrowStyle: ((ArrowStyle) -> Void)? = nil
    ) {
        guard let hostSelectionView, let toolbarFrame = subToolbarAnchorFrame else { return }
        let resolvedWidth = width ?? ColorSizeSubToolbar.preferredWidth(
            sizes: sizes,
            showsShapeFillModes: shapeFillMode != nil,
            showsArrowStyles: arrowStyle != nil,
            showsShapeStrokeStyles: shapeStrokeStyle != nil,
            shapeStrokePreviewShape: shapeStrokePreviewShape
        )
        let subRect = subToolbarRect(
            width: resolvedWidth,
            height: 36,
            toolbarFrame: toolbarFrame,
            in: hostSelectionView.bounds
        )

        let resolvedColor = currentColor ?? self.currentColor
        let view = ColorSizeSubToolbar(
            frame: subRect,
            sizes: sizes,
            currentColor: resolvedColor,
            currentSize: currentSize,
            sizeMinValue: sizeMinValue,
            sizeMaxValue: sizeMaxValue,
            shapeFillMode: shapeFillMode,
            shapeStrokeStyle: shapeStrokeStyle,
            shapeStrokePreviewShape: shapeStrokePreviewShape,
            arrowStyle: arrowStyle
        )
        view.onColorChanged = { [weak self] color in
            if let onColor {
                onColor(color)
            } else {
                self?.setCurrentDrawingColor(color)
            }
            // Push the same color onto whatever annotation is currently
            // selected. With no selection this is a no-op, so the call is
            // safe to make from every tool's color path.
            self?.canvasView?.mutateSelectedAnnotationAtomic { $0.withColor(color) }
        }
        view.onSizeBegan = { [weak self] in
            self?.canvasView?.beginSelectionAdjustment()
        }
        view.onSizeChanged = { [weak self] size in
            onSize?(size)
            self?.canvasView?.mutateSelectedAnnotationLive { $0.withLineWidth(size) }
        }
        view.onSizeEnded = { [weak self] in
            self?.canvasView?.commitSelectionAdjustment()
        }
        view.onShapeFillModeChanged = onShapeFillMode
        view.onShapeStrokeStyleChanged = onShapeStrokeStyle
        view.onArrowStyleChanged = onArrowStyle
        styleFloatingHUD(view)
        hostSelectionView.addSubview(view)
        subToolbarView = view
    }

    private func showTextSubToolbar() {
        guard let hostSelectionView, let toolbarFrame = subToolbarAnchorFrame else { return }
        let subRect = subToolbarRect(
            width: TextSubToolbar.preferredWidth,
            height: 36,
            toolbarFrame: toolbarFrame,
            in: hostSelectionView.bounds
        )

        let view = TextSubToolbar(
            frame: subRect,
            currentColor: currentColor,
            currentFontSize: currentFontSize,
            strokeEnabled: currentTextStroke,
            calloutEnabled: currentTextCallout
        )
        view.onColorChanged = { [weak self] color in
            self?.setCurrentDrawingColor(color)
            self?.canvasView?.mutateSelectedAnnotationAtomic { $0.withColor(color) }
        }
        view.onStrokeChanged = { [weak self] enabled in
            self?.currentTextStroke = enabled
            self?.canvasView?.currentTextStroke = enabled
            Defaults.lastTextStroke = enabled
            // Apply to the selected text annotation, if any. Other annotation
            // types carry no outline, so the transform leaves them untouched.
            self?.canvasView?.mutateSelectedAnnotationAtomic { annotation in
                (annotation as? TextAnnotation)?.withStroke(enabled) ?? annotation
            }
        }
        view.onCalloutChanged = { [weak self] enabled in
            self?.currentTextCallout = enabled
            self?.canvasView?.currentTextCallout = enabled
            Defaults.lastTextCallout = enabled
            self?.canvasView?.mutateSelectedAnnotationAtomic { annotation in
                (annotation as? TextAnnotation)?.withCallout(enabled) ?? annotation
            }
        }
        view.onFontSizeBegan = { [weak self] in
            self?.canvasView?.beginSelectionAdjustment()
        }
        view.onFontSizeChanged = { [weak self] size in
            self?.currentFontSize = size
            self?.canvasView?.currentFontSize = size
            Defaults.lastTextFontSize = Double(size)
            self?.canvasView?.mutateSelectedAnnotationLive { $0.withFontSize(size) }
        }
        view.onFontSizeEnded = { [weak self] in
            self?.canvasView?.commitSelectionAdjustment()
        }
        styleFloatingHUD(view)
        hostSelectionView.addSubview(view)
        subToolbarView = view
    }

    private func showMosaicSubToolbar() {
        guard let hostSelectionView, let toolbarFrame = subToolbarAnchorFrame else { return }
        let subRect = subToolbarRect(
            width: MosaicSubToolbar.preferredWidth,
            height: 36,
            toolbarFrame: toolbarFrame,
            in: hostSelectionView.bounds
        )

        let view = MosaicSubToolbar(frame: subRect, currentBlockSize: currentMosaicBlockSize)
        view.onBlockSizeBegan = { [weak self] in
            self?.canvasView?.beginSelectionAdjustment()
        }
        view.onBlockSizeChanged = { [weak self] size in
            self?.currentMosaicBlockSize = size
            self?.canvasView?.currentMosaicBlockSize = size
            Defaults.mosaicBlockSize = Double(size)
            self?.canvasView?.mutateSelectedMosaicBlockSizeLive(size)
        }
        view.onBlockSizeEnded = { [weak self] in
            self?.canvasView?.commitSelectionAdjustment()
        }
        styleFloatingHUD(view)
        hostSelectionView.addSubview(view)
        subToolbarView = view
    }

    private func updateSubToolbarPosition() {
        guard
            let hostSelectionView,
            let subToolbarView,
            let toolbarFrame = subToolbarAnchorFrame
        else { return }

        subToolbarView.frame = subToolbarRect(
            width: subToolbarView.frame.width,
            height: subToolbarView.frame.height,
            toolbarFrame: toolbarFrame,
            in: hostSelectionView.bounds
        )
    }

    /// Reposition the main toolbar, option row, and selection chrome overlay
    /// against the current selection geometry.
    private func repositionFloatingChrome() {
        guard let hostSelectionView else { return }
        if let toolbarView {
            toolbarView.frame = toolbarRect(
                in: hostSelectionView.bounds,
                size: toolbarView.preferredSize
            )
        }
        if let sideToolbarView {
            sideToolbarView.frame = sideToolbarRect(
                in: hostSelectionView.bounds,
                size: sideToolbarView.preferredSize,
                avoiding: toolbarView?.frame
            )
        }
        updateSubToolbarPosition()
        selectionChromeOverlay?.update(rect: selectionViewRect)
    }

    private func updateCanvasFrame() {
        guard let canvasView, let canvasScrollView else { return }
        canvasScrollView.frame = selectionViewRect
        updateCanvasScrollAvailability()
        resetCanvasScrollPosition()
        canvasView.needsDisplay = true
    }

    private var isCanvasTallerThanViewport: Bool {
        guard let scrollView = canvasScrollView, let documentView = scrollView.documentView else {
            return false
        }
        return documentView.frame.height > scrollView.contentView.bounds.height + 0.5
    }

    private func updateCanvasScrollAvailability() {
        guard let scrollView = canvasScrollView, let documentView = scrollView.documentView else {
            return
        }
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = documentView.frame.height > scrollView.contentView.bounds.height + 0.5
    }

    private func resetCanvasScrollPosition() {
        guard let scrollView = canvasScrollView else { return }
        updateCanvasScrollAvailability()
        if isCanvasTallerThanViewport {
            scrollView.scrollToTop()
        } else {
            scrollView.contentView.setBoundsOrigin(.zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    // MARK: - Scroll Capture

    private func toggleScrollCapture() {
        // Scroll capture only makes sense for live screen content; in
        // image-edit mode or clicked-window captures there's nothing to scroll.
        guard isScrollCaptureAllowed else { return }
        guard !isScrollCaptureFinalizing else { return }
        if canvasView?.hasPreviewImage == true { return }
        if isScrollCapturing {
            stopScrollCapture(reason: "toolbar")
        } else {
            showScrollCaptureModeMenu()
        }
    }

    private enum ScrollCaptureMode {
        case automatic
        case manual

        var diagnosticName: String {
            switch self {
            case .automatic: return "automatic"
            case .manual: return "manual"
            }
        }
    }

    private func showScrollCaptureModeMenu() {
        canvasView?.commitActiveTextEditing()
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ClosureMenuItem(title: L10n.scrollCaptureAutoScroll) { [weak self] in
            DispatchQueue.main.async {
                self?.startScrollCapture(mode: .automatic)
            }
        })
        menu.addItem(ClosureMenuItem(title: L10n.scrollCaptureManualScroll) { [weak self] in
            DispatchQueue.main.async {
                self?.startScrollCapture(mode: .manual)
            }
        })
        popUpToolbarMenu(menu, anchoredTo: .scrollCapture)
    }

    private func startScrollCapture(mode: ScrollCaptureMode) {
        guard isScrollCaptureAllowed else { return }
        guard !isScrollCaptureBusy else { return }
        guard canvasView?.hasPreviewImage != true else { return }

        let diagnosticID = Self.makeScrollCaptureDiagnosticID()
        scrollCaptureDiagnosticID = diagnosticID
        scrollCaptureModeName = mode.diagnosticName
        logScrollCapture(
            "start-requested",
            metadata: scrollCaptureStartMetadata(mode: mode, diagnosticID: diagnosticID)
        )

        if mode == .automatic {
            // Automatic scroll posts synthetic events; without Accessibility
            // access aulycShot cannot move the target page.
            guard AutoScroller.isPermitted else {
                logScrollCapture("auto-scroll-permission-missing")
                scrollCaptureDiagnosticID = nil
                scrollCaptureModeName = nil
                AutoScroller.requestPermission()
                ToastWindow.show(message: L10n.autoScrollPermissionNeeded, on: screen)
                return
            }
        }

        isScrollCapturing = true
        activeTool = .none
        canvasView?.activeTool = .none
        toolbars.forEach { $0.updateSelection(tool: .none) }
        subToolbarView?.removeFromSuperview()
        subToolbarView = nil
        toolbars.forEach { $0.setScrollCaptureActive(true) }
        hostSelectionView?.scrollCaptureActive = true
        updateEditorInteractionState()
        // The first SCK capture runs synchronously on the main thread inside
        // ScrollCapturer.init, blocking the run loop on a semaphore. Without
        // forcing the view to redraw + commit here, the window backing store
        // still shows the pre-scroll-capture chrome (accent-blue dashed border and
        // corner handles), which would appear baked into the first frame and
        // get carried into the stitched output.
        hostSelectionView?.display()
        CATransaction.flush()

        // Show the persistent hint inside the selection *before* the capturer
        // takes its first (synchronous) frame, then exclude its window from the
        // capture so it never bleeds into the stitched long screenshot.
        let hintText = mode == .automatic ? L10n.scrollCaptureHint : L10n.scrollCaptureManualHint
        let hintWindow = ScrollCaptureHintWindow(text: hintText)
        hintWindow.present(in: selectionRect)
        scrollCaptureHintWindow = hintWindow

        logScrollCapture(
            "capturer-init-begin",
            metadata: ["hintWindow": hintWindow.windowNumber]
        )
        let capturer = ScrollCapturer(
            rect: captureRect,
            screen: screen,
            excludingWindowNumbers: [CGWindowID(max(0, hintWindow.windowNumber))],
            diagnosticID: diagnosticID
        )
        logScrollCapture("capturer-init-end")
        capturer.onPreviewUpdated = { [weak self] image in
            self?.updateScrollPreview(image)
        }
        scrollCapturer = capturer
        installScrollCaptureKeyMonitor()
        showScrollCaptureControl()
        toolbars.forEach { $0.isHidden = true }
        // The overlay stays click-through so scroll input reaches the page
        // underneath. Automatic mode drops the user's input through
        // AutoScroller's event tap; manual mode intentionally lets it pass.
        hostSelectionView?.window?.ignoresMouseEvents = true
        NSApp.deactivate()
        logScrollCapture("capture-loop-start")
        switch mode {
        case .automatic:
            startAutoScroll(capturer: capturer)
        case .manual:
            startManualScrollCapture(capturer: capturer)
        }
    }

    /// Runs constant-speed automatic scrolling over the capture region. The
    /// cursor is left unconstrained so the user can reach the stop button;
    /// the synthetic scroll events are aimed at the region by event location.
    private func startAutoScroll(capturer: ScrollCapturer) {
        // Scroll ~15% of the capture height per step. Smaller steps give
        // ~85% inter-frame overlap, which keeps the Vision-based
        // translational image registration well inside its reliable range
        // even on pages with repetitive content or imperfectly-detected
        // sticky elements. Larger steps caused visible content skips in
        // testing.
        let stepPoints = max(60, min(180, selectionRect.height * 0.15))
        let center = CGPoint(x: captureRect.midX, y: captureRect.midY)
        logScrollCapture(
            "auto-scroll-start",
            metadata: [
                "stepPoints": Self.diagnosticNumber(stepPoints),
                "center": Self.diagnosticPoint(center),
            ]
        )

        let scroller = AutoScroller(
            centerPoint: center,
            blockingRect: captureRect,
            stepPixels: Int(stepPoints),
            onKeyPressed: { [weak self] in
                guard let self, self.isScrollCapturing else { return }
                self.stopScrollCapture(reason: "auto-scroll-key")
            }
        )
        autoScroller = scroller
        scroller.start(
            captureStep: {
                switch capturer.captureSynchronously(expectedShiftPoints: stepPoints) {
                case .appended: return .progressed
                case .noNewContent: return .stalled
                case .atFrameLimit: return .finished
                }
            },
            onFinished: { [weak self] in
                guard let self, self.isScrollCapturing else { return }
                self.stopScrollCapture(reason: "auto-scroll-finished")
            }
        )
    }

    /// Samples the selected region while the user scrolls manually. Duplicate
    /// frames are ignored by `ScrollCapturer`, so steady polling gives the user
    /// a forgiving capture window without adding a second stitching path.
    private func startManualScrollCapture(capturer: ScrollCapturer) {
        logScrollCapture("manual-scroll-start")
        let timer = DispatchSource.makeTimerSource(
            queue: DispatchQueue(label: "aulycShot.manual-scroll-capture", qos: .userInitiated)
        )
        manualScrollCaptureTimer = timer
        timer.schedule(deadline: .now() + 0.25, repeating: 0.25, leeway: .milliseconds(80))
        timer.setEventHandler { [weak capturer] in
            _ = capturer?.captureSynchronously(expectedShiftPoints: 0)
        }
        timer.resume()
    }

    private func stopManualScrollCapture() {
        if manualScrollCaptureTimer != nil {
            logScrollCapture("manual-scroll-stop")
        }
        manualScrollCaptureTimer?.setEventHandler {}
        manualScrollCaptureTimer?.cancel()
        manualScrollCaptureTimer = nil
    }

    private func stopScrollCapture(reason: String = "unknown") {
        guard isScrollCapturing else {
            if isScrollCaptureFinalizing {
                logScrollCapture("stop-ignored-while-finalizing", metadata: ["reason": reason])
            }
            return
        }
        logScrollCapture("stop-requested", metadata: ["reason": reason])
        isScrollCapturing = false
        isScrollCaptureFinalizing = true
        autoScroller?.stop()
        autoScroller = nil
        stopManualScrollCapture()
        removeScrollCaptureKeyMonitor()
        let finishingCapturer = scrollCapturer
        finishingCapturer?.onPreviewUpdated = nil
        scrollCapturer = nil
        scrollCaptureControlWindow?.dismiss()
        scrollCaptureControlWindow = nil
        scrollPreviewWindow?.dismiss()
        scrollPreviewWindow = nil
        scrollCaptureHintWindow?.dismiss()
        scrollCaptureHintWindow = nil
        hostSelectionView?.window?.ignoresMouseEvents = false
        hostSelectionView?.scrollCaptureActive = false
        hostSelectionView?.needsDisplay = true
        toolbars.forEach { $0.setScrollCaptureActive(false) }
        updateEditorInteractionState()
        updateCaptureActionAvailability()

        logScrollCapture("stop-and-stitch-begin", metadata: ["reason": reason])
        guard let finishingCapturer else {
            finishScrollCapture(stitchedImage: nil, reason: reason)
            return
        }
        finishingCapturer.stopAndStitch { [weak self] stitchedImage in
            self?.finishScrollCapture(stitchedImage: stitchedImage, reason: reason)
        }
    }

    private func finishScrollCapture(stitchedImage: NSImage?, reason: String) {
        guard isScrollCaptureFinalizing else {
            logScrollCapture("stop-and-stitch-result-ignored", metadata: ["reason": reason])
            return
        }
        isScrollCaptureFinalizing = false

        guard let stitchedImage else {
            logScrollCapture("stop-and-stitch-empty", metadata: ["reason": reason])
            toolbars.forEach { $0.isHidden = false }
            updateEditorInteractionState()
            updateCaptureActionAvailability()
            bringEditorToFront()
            scrollCaptureDiagnosticID = nil
            scrollCaptureModeName = nil
            return
        }
        logScrollCapture(
            "stop-and-stitch-end",
            metadata: [
                "reason": reason,
                "imageSize": Self.diagnosticSize(stitchedImage.size),
            ]
        )

        // Auto-scroll often over-shoots the end of a page, so route the
        // stitched result through crop mode before handing it to the editor.
        enterCropMode(with: stitchedImage)
    }

    // MARK: - Crop Mode

    /// Shows the stitched long screenshot scaled to fit, with a top/bottom
    /// crop overlay. The editor stays hidden underneath until confirmed.
    private func enterCropMode(with image: NSImage) {
        logScrollCapture(
            "crop-mode-enter-begin",
            metadata: ["imageSize": Self.diagnosticSize(image.size)]
        )
        guard let hostSelectionView else {
            // Defensive: no host view means the editor was already torn down.
            logScrollCapture("crop-mode-missing-host")
            finishCropFallback(with: image)
            return
        }

        isCropping = true
        activeTool = .none
        canvasView?.activeTool = .none
        toolbars.forEach { $0.updateSelection(tool: .none) }
        toolbars.forEach { $0.isHidden = true }
        selectionChromeOverlay?.isHidden = true

        let cropView = ScrollCropView(frame: hostSelectionView.bounds, image: image)
        cropView.autoresizingMask = [.width, .height]
        hostSelectionView.addSubview(cropView)
        scrollCropView = cropView

        showCropControl()
        bringEditorToFront()
        ToastWindow.show(message: L10n.cropLongScreenshotHint, on: screen)
        logScrollCapture("crop-mode-enter-end")
    }

    /// Skips crop mode and drops the image straight into the editor — only
    /// used when there is no host view to host the crop overlay.
    private func finishCropFallback(with image: NSImage) {
        logScrollCapture(
            "crop-fallback",
            metadata: ["imageSize": Self.diagnosticSize(image.size)]
        )
        loadScrollCaptureImageIntoEditor(image)
        toolbars.forEach { $0.isHidden = false }
        bringEditorToFront()
        scrollCaptureDiagnosticID = nil
        scrollCaptureModeName = nil
    }

    private func confirmCrop() {
        guard isCropping, let cropView = scrollCropView else {
            exitCropMode()
            return
        }

        let cropped = cropView.croppedImage()
        logScrollCapture(
            "crop-confirm",
            metadata: ["croppedSize": Self.diagnosticSize(cropped.size)]
        )
        exitCropMode()
        loadScrollCaptureImageIntoEditor(cropped)
        scrollCaptureDiagnosticID = nil
        scrollCaptureModeName = nil
        ToastWindow.show(message: L10n.mergedLongScreenshot, on: screen)
    }

    private func loadScrollCaptureImageIntoEditor(_ image: NSImage) {
        logScrollCapture(
            "load-stitched-image",
            metadata: ["imageSize": Self.diagnosticSize(image.size)]
        )
        canvasView?.loadPreviewImage(image)
        hostSelectionView?.selectionSizeLabelOverride = Self.sizeLabelText(for: image.size)
        updateCanvasScrollAvailability()
        canvasScrollView?.scrollToTop()
        updateEditorInteractionState()
        updateCaptureActionAvailability()
    }

    private static func sizeLabelText(for size: NSSize) -> String? {
        guard size.width > 0, size.height > 0 else { return nil }
        return "\(Int(size.width.rounded())) x \(Int(size.height.rounded()))"
    }

    private static func makeScrollCaptureDiagnosticID() -> String {
        String(UUID().uuidString.prefix(8))
    }

    private func scrollCaptureStartMetadata(
        mode: ScrollCaptureMode,
        diagnosticID: String
    ) -> [String: Any] {
        var metadata = DiagnosticLog.systemSnapshot()
        metadata["session"] = diagnosticID
        metadata["mode"] = mode.diagnosticName
        metadata["captureRect"] = Self.diagnosticRect(captureRect)
        metadata["selectionRect"] = Self.diagnosticRect(selectionRect)
        metadata["selectionViewRect"] = Self.diagnosticRect(selectionViewRect)
        metadata["screenFrame"] = Self.diagnosticRect(screen.frame)
        metadata["screenVisibleFrame"] = Self.diagnosticRect(screen.visibleFrame)
        metadata["screenScale"] = Self.diagnosticNumber(screen.backingScaleFactor)
        metadata["screenName"] = screen.localizedName
        metadata["isWindowCapture"] = isWindowCapture
        metadata["hasPreSnapshot"] = preSnapshot != nil
        metadata["hasOverrideBaseImage"] = overrideBaseImage != nil
        return metadata
    }

    private func logScrollCapture(_ event: String, metadata: [String: Any] = [:]) {
        var fields = metadata
        if let scrollCaptureDiagnosticID {
            fields["session"] = scrollCaptureDiagnosticID
        }
        if let scrollCaptureModeName {
            fields["mode"] = scrollCaptureModeName
        }
        fields["isCapturing"] = isScrollCapturing
        fields["isFinalizing"] = isScrollCaptureFinalizing
        fields["isCropping"] = isCropping
        DiagnosticLog.log("scroll-stitch", event, metadata: fields)
    }

    private static func diagnosticRect(_ rect: CGRect) -> String {
        "x=\(diagnosticNumber(rect.origin.x)) y=\(diagnosticNumber(rect.origin.y)) w=\(diagnosticNumber(rect.width)) h=\(diagnosticNumber(rect.height))"
    }

    private static func diagnosticPoint(_ point: CGPoint) -> String {
        "x=\(diagnosticNumber(point.x)) y=\(diagnosticNumber(point.y))"
    }

    private static func diagnosticSize(_ size: NSSize) -> String {
        "w=\(diagnosticNumber(size.width)) h=\(diagnosticNumber(size.height))"
    }

    private static func diagnosticNumber(_ value: CGFloat) -> String {
        String(format: "%.1f", Double(value))
    }

    private func exitCropMode() {
        isCropping = false
        scrollCropView?.removeFromSuperview()
        scrollCropView = nil
        scrollCropControlWindow?.dismiss()
        scrollCropControlWindow = nil
        selectionChromeOverlay?.isHidden = false
        toolbars.forEach { $0.isHidden = false }
        bringEditorToFront()
    }

    private func showCropControl() {
        let controlWindow = ScrollCropControlWindow(
            onConfirm: { [weak self] in self?.confirmCrop() }
        )
        controlWindow.positionAtBottom(of: screen)
        scrollCropControlWindow = controlWindow
        controlWindow.orderFrontRegardless()
    }

    private func save() {
        canvasView?.commitActiveTextEditing()
        guard let finalImage = currentCompositeImage() else { return }
        let targetScreen = screen
        let focusReturn = onRequestFocusReturn
        let quality = Defaults.screenshotQuality

        tearDown()
        onComplete(nil)

        if quality.usesLossyCompression {
            ToastWindow.show(message: L10n.screenshotQualityCompressingSave, on: targetScreen, duration: 600)
        }

        ImageOutputEncoder.encodeAsync(image: finalImage, quality: quality) { result in
            if quality.usesLossyCompression {
                ToastWindow.dismiss()
            }

            switch result {
            case .failure:
                ToastWindow.show(message: L10n.screenshotCompressionFailed, on: targetScreen, duration: 3.0)
            case .success(let output):
                do {
                    let filename = OutputFilename.imageFileName(fileExtension: output.fileExtension)
                    let destination = try SaveDestination.uniqueFile(
                        in: Defaults.screenshotSaveDirectory,
                        fileName: filename
                    )
                    try output.data.write(to: destination, options: .atomic)
                    let directoryPath = SaveDestination.displayPath(destination.deletingLastPathComponent())
                    ToastWindow.showScreenshotSuccess(
                        message: L10n.screenshotSaved(to: directoryPath),
                        on: targetScreen
                    )
                } catch {
                    ToastWindow.show(
                        message: L10n.screenshotSaveFailed(error.localizedDescription),
                        on: targetScreen,
                        duration: 3.5
                    )
                }
            }

            focusReturn?()
        }
    }

    private func performQRCodeRecognition() {
        canvasView?.commitActiveTextEditing()
        dismissQRCodeOverlay()
        clearActiveToolForQRCodeRecognition()

        guard
            let canvasView,
            let hostSelectionView,
            let image = canvasView.resolveBaseImageForEditing() ?? currentCompositeImage(),
            let cgImage = image.cgImagePreservingBacking()
        else {
            ToastWindow.show(message: L10n.qrCodeNotFound, on: screen)
            return
        }

        qrCodeDetectionGeneration += 1
        let generation = qrCodeDetectionGeneration
        toolbars.forEach { $0.setActive(true, for: .qrCode) }

        DispatchQueue.global(qos: .userInitiated).async {
            let detections = QRCodeDetector.detect(in: cgImage)
            DispatchQueue.main.async { [weak self, weak canvasView, weak hostSelectionView] in
                guard let self,
                      let canvasView,
                      let hostSelectionView,
                      generation == self.qrCodeDetectionGeneration
                else { return }
                self.handleQRCodeDetections(
                    detections,
                    canvasView: canvasView,
                    hostSelectionView: hostSelectionView
                )
            }
        }
    }

    private func clearActiveToolForQRCodeRecognition() {
        activeTool = .none
        canvasView?.activeTool = .none
        canvasView?.clearMultiSelection()
        toolbars.forEach { $0.updateSelection(tool: .none) }
        subToolbarView?.removeFromSuperview()
        subToolbarView = nil
        updateEditorInteractionState()
        bringEditorToFront()
    }

    private func handleQRCodeDetections(
        _ detections: [QRCodeDetection],
        canvasView: EditCanvasView,
        hostSelectionView: SelectionView
    ) {
        guard !detections.isEmpty else {
            dismissQRCodeOverlay()
            ToastWindow.show(message: L10n.qrCodeNotFound, on: screen)
            return
        }

        guard detections.count > 1 else {
            copyQRCodePayload(detections[0].payload)
            return
        }

        let choices = detections.map { detection in
            let canvasRect = canvasRect(
                fromNormalizedBoundingBox: detection.normalizedBoundingBox,
                in: canvasView.bounds
            )
            return QRCodeChoice(
                payload: detection.payload,
                anchorRect: canvasView.convert(canvasRect, to: hostSelectionView)
            )
        }

        let overlay = QRCodeChoiceOverlayView(
            frame: hostSelectionView.bounds,
            choices: choices
        ) { [weak self] choice in
            self?.copyQRCodePayload(choice.payload)
        }
        qrCodeOverlayView?.removeFromSuperview()
        qrCodeOverlayView = overlay
        hostSelectionView.addSubview(overlay)
        toolbars.forEach { $0.setActive(true, for: .qrCode) }
        bringEditorToFront()
    }

    private func copyQRCodePayload(_ payload: String) {
        let targetScreen = screen
        ClipboardManager.copyToClipboard(text: payload)
        tearDown()
        onComplete(nil)
        ToastWindow.show(message: L10n.qrCodeCopied, on: targetScreen)
        requestFocusReturn()
    }

    private func dismissQRCodeOverlay() {
        qrCodeDetectionGeneration += 1
        qrCodeOverlayView?.removeFromSuperview()
        qrCodeOverlayView = nil
        toolbars.forEach { $0.setActive(false, for: .qrCode) }
    }

    private func canvasRect(fromNormalizedBoundingBox box: CGRect, in bounds: NSRect) -> NSRect {
        let standardized = box.standardized
        let minX = max(0, min(1, standardized.minX))
        let minY = max(0, min(1, standardized.minY))
        let maxX = max(0, min(1, standardized.maxX))
        let maxY = max(0, min(1, standardized.maxY))
        return NSRect(
            x: bounds.minX + minX * bounds.width,
            y: bounds.minY + minY * bounds.height,
            width: max(0, maxX - minX) * bounds.width,
            height: max(0, maxY - minY) * bounds.height
        )
    }

    private func pin() {
        canvasView?.commitActiveTextEditing()
        guard let finalImage = currentCompositeImage() else { return }

        PinLauncher.pin(image: finalImage, at: selectionRect.origin)

        tearDown()
        onComplete(nil) // Don't copy to clipboard for pin
    }

    private func record() {
        guard let onRecordingSelection else { return }
        canvasView?.commitActiveTextEditing()
        let rect = selectionRect
        let targetScreen = screen
        tearDown()
        onComplete(nil)
        onRecordingSelection(rect, targetScreen)
    }

    private func close() {
        tearDown()
        onComplete(nil)
        requestFocusReturn()
    }

    private func setShapeFillMode(_ mode: ShapeFillMode) {
        currentShapeFillMode = mode
        canvasView?.currentShapeFillMode = mode
        Defaults.lastShapeFillMode = mode
        canvasView?.mutateSelectedAnnotationAtomic { $0.withShapeFillMode(mode) }
    }

    private func setCurrentDrawingColor(_ color: NSColor) {
        currentColor = color
        canvasView?.currentColor = color
        if let hex = Self.hex(from: color) {
            Defaults.lastEditorColorHex = hex
        }
    }

    private func setCurrentDrawingLineWidth(_ size: CGFloat) {
        currentLineWidth = size
        canvasView?.currentLineWidth = size
        Defaults.lastEditorLineWidth = Double(size)
    }

    private func setCurrentMarkerColor(_ color: NSColor) {
        currentMarkerColor = color
        canvasView?.currentMarkerColor = color
        if let hex = Self.hex(from: color) {
            Defaults.lastMarkerColorHex = hex
        }
    }

    private func setCurrentMarkerLineWidth(_ size: CGFloat) {
        let clamped = min(max(size, CGFloat(Defaults.editorLineWidthMin)), CGFloat(Defaults.markerLineWidthMax))
        currentMarkerLineWidth = clamped
        canvasView?.currentMarkerLineWidth = clamped
        Defaults.lastMarkerLineWidth = Double(clamped)
    }

    private static func hex(from color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) else {
            return nil
        }
        let r = Int(round(max(0, min(1, rgb.redComponent)) * 255))
        let g = Int(round(max(0, min(1, rgb.greenComponent)) * 255))
        let b = Int(round(max(0, min(1, rgb.blueComponent)) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func showInsertImageMenu() {
        canvasView?.commitActiveTextEditing()
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ClosureMenuItem(title: L10n.insertImageFromClipboard) { [weak self] in
            self?.insertImageFromClipboard()
        })
        menu.addItem(ClosureMenuItem(title: L10n.insertImageFromFile) { [weak self] in
            self?.insertImageFromFile()
        })
        popUpToolbarMenu(menu, anchoredTo: .insertImage)
    }

    private func insertImageFromClipboard() {
        guard let image = ClipboardImageSource.currentImage() else {
            ToastWindow.show(message: L10n.insertImageNoClipboardImage, on: screen)
            bringEditorToFront()
            return
        }
        insertImage(image)
    }

    private func insertImageFromFile() {
        canvasView?.commitActiveTextEditing()
        let panel = NSOpenPanel()
        panel.title = L10n.insertImageChooseFile
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self, panel] response in
            guard
                response == .OK,
                let url = panel.url,
                let image = Self.loadImageForInsertion(from: url)
            else {
                self?.bringEditorToFront()
                return
            }
            self?.insertImage(image)
        }

        if let hostWindow = hostSelectionView?.window {
            panel.beginSheetModal(for: hostWindow, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func insertImage(_ image: NSImage) {
        selectTool(.none)
        _ = canvasView?.insertImage(image)
        bringEditorToFront()
    }

    private func popUpToolbarMenu(_ menu: NSMenu, anchoredTo itemID: ToolbarItemID) {
        guard let hostSelectionView else { return }
        let anchor = toolbarItemFrameInHost(for: itemID) ?? NSRect(
            x: hostSelectionView.bounds.midX,
            y: hostSelectionView.bounds.midY,
            width: 1,
            height: 1
        )
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: anchor.minX, y: anchor.maxY + 4),
            in: hostSelectionView
        )
        bringEditorToFront()
    }

    private func toolbarItemFrameInHost(for itemID: ToolbarItemID) -> NSRect? {
        guard let hostSelectionView else { return nil }
        for toolbar in toolbars {
            if let frame = toolbar.frame(for: itemID) {
                return toolbar.convert(frame, to: hostSelectionView)
            }
        }
        return nil
    }

    private static func loadImageForInsertion(from url: URL) -> NSImage? {
        if let data = try? Data(contentsOf: url),
           let rep = NSBitmapImageRep(data: data) {
            let pixelSize = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
            rep.size = pixelSize
            let image = NSImage(size: pixelSize)
            image.addRepresentation(rep)
            return image
        }
        return NSImage(contentsOf: url)
    }

    func confirmFromKeyboard() {
        // The screenshot-execution hotkey during auto-scroll stops scrolling
        // and moves to crop mode; during crop mode it confirms the crop. The
        // configured output action runs only after the user reaches the editor.
        if isScrollCaptureFinalizing {
            return
        }
        if isScrollCapturing {
            stopScrollCapture(reason: "confirm-hotkey")
            return
        }
        if isCropping {
            confirmCrop()
            return
        }
        confirm()
    }

    func confirmCropFromKeyboard(for event: NSEvent) -> Bool {
        guard isCropping else { return false }
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection(blockedModifiers).isEmpty else { return false }

        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            confirmCrop()
            return true
        default:
            return false
        }
    }

    func undoFromKeyboard(for event: NSEvent) -> Bool {
        guard !isScrollCaptureBusy, !isCropping else { return false }
        return canvasView?.undoFromKeyboard(for: event) ?? false
    }

    func redoFromKeyboard(for event: NSEvent) -> Bool {
        guard !isScrollCaptureBusy, !isCropping else { return false }
        return canvasView?.redoFromKeyboard(for: event) ?? false
    }

    func handleAnnotationClipboardShortcutFromKeyboard(for event: NSEvent) -> Bool {
        guard !isScrollCaptureBusy, !isCropping else { return false }
        return canvasView?.handleAnnotationClipboardShortcutFromKeyboard(for: event) ?? false
    }

    func nudgeSelectedAnnotationFromKeyboard(for event: NSEvent) -> Bool {
        guard !isScrollCaptureBusy, !isCropping else { return false }
        return canvasView?.nudgeSelectedAnnotationFromKeyboard(for: event) ?? false
    }

    func deleteSelectedAnnotationFromKeyboard(for event: NSEvent) -> Bool {
        guard !isScrollCaptureBusy, !isCropping else { return false }
        return canvasView?.deleteSelectedAnnotationFromKeyboard(for: event) ?? false
    }

    func handleEditorShortcutFromKeyboard(for event: NSEvent) -> Bool {
        guard !isScrollCaptureBusy, !isCropping else { return false }
        guard let shortcut = EditorKeyboardShortcut(event: event) else { return false }

        switch shortcut {
        case .select:
            selectTool(.none)
        case .tool(let tool):
            selectTool(tool)
        case .fill:
            return toggleShapeFillFromKeyboard()
        case .pin:
            pin()
        case .close:
            close()
        }
        return true
    }

    private func toggleShapeFillFromKeyboard() -> Bool {
        guard activeTool == .rectangle || activeTool == .ellipse else { return false }
        let nextMode: ShapeFillMode
        switch currentShapeFillMode {
        case .none:
            nextMode = .opaque
        case .opaque:
            nextMode = .translucent
        case .translucent:
            nextMode = .none
        }
        setShapeFillMode(nextMode)
        showSubToolbar(for: activeTool)
        return true
    }

    private func confirm() {
        canvasView?.commitActiveTextEditing()
        guard let finalImage = currentCompositeImage() else {
            tearDown()
            onComplete(nil)
            requestFocusReturn()
            return
        }
        tearDown()
        onComplete(finalImage)
        requestFocusReturn()
    }

    private func requestFocusReturn() {
        onRequestFocusReturn?()
    }

    func tearDown() {
        dismissQRCodeOverlay()
        if isScrollCapturing {
            logScrollCapture("teardown-while-capturing")
        }
        if isScrollCaptureFinalizing {
            logScrollCapture("teardown-while-finalizing")
        }
        if isCropping {
            logScrollCapture("teardown-while-cropping")
        }
        isScrollCapturing = false
        isScrollCaptureFinalizing = false
        autoScroller?.stop()
        autoScroller = nil
        stopManualScrollCapture()
        removeScrollCaptureKeyMonitor()
        scrollCapturer = nil
        isCropping = false
        scrollCropView?.removeFromSuperview()
        scrollCropView = nil
        scrollCropControlWindow?.dismiss()
        scrollCropControlWindow = nil
        scrollCaptureControlWindow?.dismiss()
        scrollCaptureControlWindow = nil
        scrollPreviewWindow?.dismiss()
        scrollPreviewWindow = nil
        scrollCaptureHintWindow?.dismiss()
        scrollCaptureHintWindow = nil
        hostSelectionView?.window?.ignoresMouseEvents = false
        canvasScrollView?.removeFromSuperview()
        canvasScrollView = nil
        canvasView = nil
        selectionChromeOverlay?.removeFromSuperview()
        selectionChromeOverlay = nil
        hostSelectionView?.refreshAnnotationCursor = nil
        hostSelectionView?.annotationToolActive = false
        hostSelectionView?.selectionInteractionEnabled = true
        hostSelectionView?.scrollCaptureActive = false
        toolbars.forEach { $0.isHidden = false; $0.removeFromSuperview() }
        scrollCaptureDiagnosticID = nil
        scrollCaptureModeName = nil
        toolbarView = nil
        sideToolbarView = nil
        subToolbarView?.removeFromSuperview()
        subToolbarView = nil
    }

    private func bringEditorToFront() {
        guard let hostWindow = hostSelectionView?.window else { return }
        hostWindow.collectionBehavior = []
        NSApp.activate(ignoringOtherApps: true)
        hostWindow.makeKeyAndOrderFront(nil)
        if activeTool == .none, canvasView?.hasPreviewImage != true {
            hostWindow.makeFirstResponder(hostSelectionView)
        } else {
            hostWindow.makeFirstResponder(canvasView)
        }
    }

    func restorableState() -> RestorableState? {
        guard let canvasView else { return nil }
        return RestorableState(canvasState: canvasView.restorableState())
    }

    func restoreState(_ state: RestorableState) {
        canvasView?.restoreState(state.canvasState)
        updateCanvasScrollAvailability()
        updateEditorInteractionState()
        updateHistoryButtons(canUndo: canvasView?.canUndo == true, canRedo: canvasView?.canRedo == true)
    }

    private func currentCompositeImage() -> NSImage? {
        var fallbackBaseImage: NSImage?
        if canvasView?.hasPreviewImage == true {
            fallbackBaseImage = nil
        } else if let overrideBaseImage {
            fallbackBaseImage = overrideBaseImage
        } else if isWindowCapture, let windowBaseImage {
            fallbackBaseImage = windowBaseImage
        } else if let snapshot = preSnapshot {
            fallbackBaseImage = ScreenCapturer.crop(from: snapshot, captureRect: captureRect, screen: screen)
        } else {
            fallbackBaseImage = ScreenCapturer.capture(rect: captureRect, screen: screen)
        }

        if canvasView?.hasPreviewImage != true {
            fallbackBaseImage = windowShapedBaseImage(from: fallbackBaseImage)
        }

        let annotationClipMask = isWindowCapture && canvasView?.hasPreviewImage != true
            ? fallbackBaseImage
            : nil

        return canvasView?.compositeImage(
            fallbackBaseImage: fallbackBaseImage,
            annotationClipMask: annotationClipMask
        )
    }

    private func windowShapedBaseImage(from image: NSImage?) -> NSImage? {
        guard let image else { return nil }
        guard isWindowCapture, canvasView?.hasPreviewImage != true else { return image }
        return windowBaseImage ?? WindowEffects.roundedCorners(image)
    }

    /// While scroll capture runs aulycShot is deactivated, so a local key monitor
    /// would not fire. In automatic mode the event tap in `AutoScroller` is
    /// the primary path; this global monitor also covers manual mode.
    private func installScrollCaptureKeyMonitor() {
        removeScrollCaptureKeyMonitor()
        scrollCaptureKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            guard let self, self.isScrollCapturing else { return }
            self.stopScrollCapture(reason: "global-key")
        }
    }

    private func removeScrollCaptureKeyMonitor() {
        if let scrollCaptureKeyMonitor {
            NSEvent.removeMonitor(scrollCaptureKeyMonitor)
            self.scrollCaptureKeyMonitor = nil
        }
    }

    private func updateScrollPreview(_ image: NSImage) {
        guard isScrollCapturing else {
            logScrollCapture("preview-ignored-after-stop")
            return
        }
        if scrollPreviewWindow == nil {
            scrollPreviewWindow = ScrollPreviewWindow()
        }
        scrollPreviewWindow?.updatePreview(image, anchorRect: selectionRect)
    }

    private func showScrollCaptureControl() {
        guard
            let hostSelectionView,
            let hostWindow = hostSelectionView.window,
            let scrollToolbar = toolbars.first(where: { $0.contains(.scrollCapture) }),
            let buttonFrame = scrollToolbar.scrollCaptureButtonFrame
        else {
            return
        }

        let frameInSelectionView = scrollToolbar.convert(buttonFrame, to: hostSelectionView)
        let frameInWindow = hostSelectionView.convert(frameInSelectionView, to: nil)
        let frameOnScreen = hostWindow.convertToScreen(frameInWindow)

        let controlWindow = ScrollCaptureControlWindow(buttonFrame: frameOnScreen) { [weak self] in
            self?.toggleScrollCapture()
        }
        scrollCaptureControlWindow = controlWindow
        controlWindow.orderFrontRegardless()
    }

    private func updateEditorInteractionState() {
        let hasPreview = canvasView?.hasPreviewImage == true
        let hasFixedImage = overrideBaseImage != nil
        let isBlocked = isScrollCaptureBusy || isCropping
        // Once the editor is up, the canvas owns clicks inside the selection
        // rect for the entire session — drawing tools, adjust-mode handles,
        // and dragging existing annotations all go through it. Selection
        // handles and the border remain interactive through
        // `selectionChromeOverlay`, which sits above the canvas and claims
        // only those narrow edge regions.
        hostSelectionView?.annotationToolActive = !isBlocked
        hostSelectionView?.selectionInteractionEnabled = !(isBlocked || hasPreview || hasFixedImage)
        canvasScrollView?.isInteractionEnabled = (activeTool != .none) || hasPreview || hasFixedImage
        hostSelectionView?.needsDisplay = true
    }

    private func toolbarRect(in bounds: NSRect, size: NSSize) -> NSRect {
        let width = size.width
        let height = size.height
        let margin: CGFloat = 8

        let referenceRect = selectionViewRect
        let x = clampedX(
            referenceRect.midX - width / 2,
            width: width,
            in: bounds,
            margin: margin
        )
        var y = referenceRect.minY - height - margin
        if y < margin {
            y = min(referenceRect.maxY + margin, bounds.maxY - height - margin)
        }
        y = max(margin, min(bounds.maxY - height - margin, y))

        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Frame for the vertical side toolbar. Prefers the right of the
    /// selection, flips to the left when there's no room, and stays
    /// vertically centered on the selection.
    ///
    /// `avoiding` is the primary toolbar's frame, when it exists. The two
    /// bars are positioned independently against their own preferred
    /// anchors, so for a small selection near a screen edge the side
    /// toolbar can dip into the horizontal bar's row. When that happens we
    /// slide the side toolbar clear of the primary toolbar's band.
    private func sideToolbarRect(
        in bounds: NSRect,
        size: NSSize,
        avoiding primaryFrame: NSRect? = nil
    ) -> NSRect {
        let width = size.width
        let height = size.height
        let margin: CGFloat = 8

        let referenceRect = selectionViewRect
        var x = referenceRect.maxX + margin
        if x + width > bounds.maxX - margin {
            x = referenceRect.minX - width - margin
        }
        x = max(margin, min(bounds.maxX - width - margin, x))

        var y = referenceRect.midY - height / 2
        y = max(margin, min(bounds.maxY - height - margin, y))

        var rect = NSRect(x: x, y: y, width: width, height: height)

        if let primary = primaryFrame, rect.intersects(primary) {
            // Try to sit fully above the primary toolbar's band; fall back
            // to below it when there isn't enough headroom.
            let above = primary.maxY + margin
            if above + height <= bounds.maxY - margin {
                rect.origin.y = above
            } else {
                rect.origin.y = max(margin, primary.minY - margin - height)
            }
        }

        return rect
    }

    private func subToolbarRect(
        width: CGFloat,
        height: CGFloat,
        toolbarFrame: NSRect,
        in bounds: NSRect
    ) -> NSRect {
        let margin: CGFloat = 8
        let x = clampedX(toolbarFrame.midX - width / 2, width: width, in: bounds, margin: margin)
        var y = toolbarFrame.minY - height - 4
        if y < margin {
            y = min(toolbarFrame.maxY + 4, bounds.maxY - height - margin)
        }
        y = max(margin, min(bounds.maxY - height - margin, y))

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func clampedX(_ proposedX: CGFloat, width: CGFloat, in bounds: NSRect, margin: CGFloat) -> CGFloat {
        max(margin, min(bounds.maxX - width - margin, proposedX))
    }

    private func styleFloatingHUD(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.25
        view.layer?.shadowRadius = 10
        view.layer?.shadowOffset = CGSize(width: 0, height: -2)
    }
}

private enum EditorKeyboardShortcut {
    case select
    case tool(EditTool)
    case fill
    case pin
    case close

    init?(event: NSEvent) {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection(blockedModifiers).isEmpty else { return nil }
        guard let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1 else {
            return nil
        }

        switch key {
        case "v": self = .select
        case "r": self = .tool(.rectangle)
        case "o": self = .tool(.ellipse)
        case "l": self = .tool(.line)
        case "a": self = .tool(.arrow)
        case "d": self = .tool(.pen)
        case "h": self = .tool(.marker)
        case "m": self = .tool(.mosaic)
        case "e": self = .tool(.eraser)
        case "f": self = .fill
        case "t": self = .tool(.text)
        case "n": self = .tool(.numbered)
        case "p": self = .pin
        case "x": self = .close
        default: return nil
        }
    }
}

// MARK: - Main Toolbar View

let accentGreen = NSColor(red: 0, green: 212.0/255.0, blue: 106.0/255.0, alpha: 1.0)

enum EditorOptionChrome {
    static let selectionColor = CaptureSelectionChrome.accentColor
    static let sliderTrackHeight: CGFloat = 2
    static let lineWidthValueBadgeDiameter: CGFloat = 22
    static let shapeFillSelectionBorderWidth: CGFloat = 2
    static let shapeFillSelectionDrawsBackground = false

    static func usesCircularWidthValueBadge(minValue: Double, maxValue: Double) -> Bool {
        minValue >= Defaults.editorLineWidthMin
            && maxValue <= Defaults.editorLineWidthMax
            && maxValue > minValue
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        target = self
        action = #selector(run)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}

private final class EditorScrollView: NSScrollView {
    weak var editorCanvasView: EditCanvasView?
    /// When `true`, every viewport click is captured by drawing tools or a
    /// long-screenshot preview. When `false` the scroll view
    /// only forwards clicks that the canvas itself claimed, so empty
    /// viewport clicks fall through to the SelectionView underneath where
    /// its resize handles live.
    var isInteractionEnabled = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        if isInteractionEnabled {
            return result
        }
        guard let canvas = editorCanvasView, let hit = result else { return nil }
        if hit === canvas || hit.isDescendant(of: canvas) {
            return hit
        }
        return nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func scrollToTop() {
        guard let documentView else { return }
        let topOffset = max(0, documentView.frame.height - contentView.bounds.height)
        contentView.scroll(to: NSPoint(x: 0, y: topOffset))
        reflectScrolledClipView(contentView)
    }
}

/// A row (horizontal) or column (vertical) of editor buttons built from a
/// `[ToolbarItemID]`. Both the primary toolbar and the side toolbar are
/// instances of this class — only `orientation` and the item list differ.
class ToolbarView: NSView {
    enum Orientation { case horizontal, vertical }

    /// Button run geometry. `preferredSize` derives the capsule size from
    /// these so the dark background always wraps the buttons exactly.
    static let buttonSize: CGFloat = 32
    static let buttonSpacing: CGFloat = 6
    /// Inset along the main axis at both ends of the run.
    static let endPadding: CGFloat = 15
    /// Inset on the cross axis — keeps a 44pt-thick capsule around 32pt buttons.
    static let crossPadding: CGFloat = 6

    let orientation: Orientation
    private let items: [ToolbarItemID]

    /// Size that fits the current items in the current orientation.
    var preferredSize: NSSize {
        let n = items.count
        let run = CGFloat(n) * Self.buttonSize
            + CGFloat(max(0, n - 1)) * Self.buttonSpacing
            + Self.endPadding * 2
        let thickness = Self.buttonSize + Self.crossPadding * 2
        switch orientation {
        case .horizontal: return NSSize(width: max(run, thickness), height: thickness)
        case .vertical:   return NSSize(width: thickness, height: max(run, thickness))
        }
    }

    var onToolSelected: ((EditTool) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onScrollCapture: (() -> Void)?
    var onInsertImage: (() -> Void)?
    var onQRCode: (() -> Void)?
    var onSave: (() -> Void)?
    var onPin: (() -> Void)?
    var onRecord: (() -> Void)?
    var onClose: (() -> Void)?
    var onConfirm: (() -> Void)?

    /// Every button keyed by its id — drives selection state, enable/disable,
    /// and frame lookups.
    private var buttons: [ToolbarItemID: NSView] = [:]
    /// Last tool the controller selected. Tracked so a second click on the
    /// already-selected tool button toggles back to "no tool" (adjust mode).
    private var currentTool: EditTool = .none

    init(items: [ToolbarItemID], orientation: Orientation) {
        self.items = items
        self.orientation = orientation
        super.init(frame: NSRect(origin: .zero, size: .zero))
        setFrameSize(preferredSize)
        setupButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func updateSelection(tool: EditTool) {
        currentTool = tool
        for (id, view) in buttons {
            guard id.kind == .toggleTool, let btn = view as? ToolButton else { continue }
            btn.isSelected = (id.editTool == tool)
        }
    }

    /// Sets the active highlight on a stateful button. No-op if this toolbar
    /// doesn't hold the item.
    func setActive(_ active: Bool, for id: ToolbarItemID) {
        (buttons[id] as? ToolButton)?.isSelected = active
    }

    /// Enables/disables a button and dims it when disabled.
    func setEnabled(_ enabled: Bool, for id: ToolbarItemID) {
        guard let btn = buttons[id] as? ToolButton else { return }
        btn.isEnabled = enabled
        btn.alphaValue = enabled ? 1.0 : 0.35
    }

    /// `true` if this toolbar holds the given item.
    func contains(_ id: ToolbarItemID) -> Bool { buttons[id] != nil }

    /// Frame of an item's button in this toolbar's coordinate space.
    func frame(for id: ToolbarItemID) -> NSRect? { buttons[id]?.frame }

    // Convenience wrappers so callers don't repeat the id literals.
    func setScrollCaptureActive(_ active: Bool) { setActive(active, for: .scrollCapture) }
    func setScrollCaptureEnabled(_ enabled: Bool) { setEnabled(enabled, for: .scrollCapture) }
    func setUndoEnabled(_ enabled: Bool) { setEnabled(enabled, for: .undo) }
    func setRedoEnabled(_ enabled: Bool) { setEnabled(enabled, for: .redo) }
    func setRecordingEnabled(_ enabled: Bool) {
        setEnabled(enabled, for: .record)
    }
    var scrollCaptureButtonFrame: NSRect? { frame(for: .scrollCapture) }

    private func setupButtons() {
        let size = Self.buttonSize
        let step = size + Self.buttonSpacing
        for (index, id) in items.enumerated() {
            let along = Self.endPadding + CGFloat(index) * step
            let frame: NSRect
            switch orientation {
            case .horizontal:
                frame = NSRect(x: along, y: Self.crossPadding, width: size, height: size)
            case .vertical:
                // AppKit y grows upward, so the first item sits at the top.
                let y = bounds.height - Self.endPadding - size - CGFloat(index) * step
                frame = NSRect(x: Self.crossPadding, y: y, width: size, height: size)
            }
            let view = makeButton(for: id, index: index, frame: frame)
            buttons[id] = view
            addSubview(view)
        }
    }

    private func makeButton(for id: ToolbarItemID, index: Int, frame: NSRect) -> NSView {
        let btn = ToolButton(
            frame: frame,
            image: id.toolbarIconImage(pointSize: 14),
            normalColor: id.normalColor,
            selectedColor: id.selectedColor
        )
        btn.hoverTip = id.tooltip
        btn.target = self
        btn.action = #selector(buttonTapped(_:))
        btn.tag = index
        return btn
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }

    @objc private func buttonTapped(_ sender: ToolButton) {
        guard sender.tag >= 0, sender.tag < items.count else { return }
        let id = items[sender.tag]
        switch id {
        case .rectangle, .ellipse, .arrow, .line, .pen, .marker, .mosaic, .eraser, .magnifier, .numbered, .text:
            guard let tool = id.editTool else { return }
            // Click an already-selected tool to deselect it and enter adjust
            // mode (no tool, but existing marks remain draggable).
            onToolSelected?(tool == currentTool ? .none : tool)
        case .insertImage:   onInsertImage?()
        case .undo:          onUndo?()
        case .redo:          onRedo?()
        case .scrollCapture: onScrollCapture?()
        case .qrCode:        onQRCode?()
        case .save:          onSave?()
        case .pin:           onPin?()
        case .record:        onRecord?()
        case .close:         onClose?()
        case .confirm:       onConfirm?()
        }
    }
}

// MARK: - Tool Button

class ToolButton: NSButton {
    var isSelected = false {
        didSet { needsDisplay = true }
    }

    /// Text shown by the dark hover tooltip. nil = no tip.
    var hoverTip: String?

    private let normalColor: NSColor
    private let selectedColor: NSColor
    private var hoverTrackingArea: NSTrackingArea?

    init(frame: NSRect, image: NSImage?, normalColor: NSColor, selectedColor: NSColor) {
        self.normalColor = normalColor
        self.selectedColor = selectedColor
        super.init(frame: frame)

        bezelStyle = .regularSquare
        isBordered = false
        setButtonType(.momentaryPushIn)

        self.image = image

        contentTintColor = normalColor
        wantsLayer = true
    }

    convenience init(
        frame: NSRect,
        symbolName: String,
        normalColor: NSColor,
        selectedColor: NSColor
    ) {
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        self.init(
            frame: frame,
            image: symbol?.withSymbolConfiguration(configuration),
            normalColor: normalColor,
            selectedColor: selectedColor
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverTrackingArea {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard let tip = hoverTip, let window else { return }
        let frameInWindow = convert(bounds, to: nil)
        let frameOnScreen = window.convertToScreen(frameInWindow)
        ToolTipWindow.show(text: tip, anchor: frameOnScreen, relativeTo: window)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        ToolTipWindow.hide()
    }

    override func mouseDown(with event: NSEvent) {
        ToolTipWindow.hide()
        super.mouseDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { ToolTipWindow.hide() }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            contentTintColor = selectedColor
            let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
            AdaptiveChrome.selectedFill.setFill()
            bgPath.fill()
        } else {
            contentTintColor = normalColor
        }
        super.draw(dirtyRect)
    }
}

/// Persistent "press any key to finish" hint shown centered near the top of
/// the selection during auto-scroll. It is its own window so it can be
/// excluded from the ScreenCaptureKit capture — otherwise it would be baked
/// into every stitched frame of the long screenshot.
private final class ScrollCaptureHintWindow: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private let horizontalPadding: CGFloat = 14
    private let verticalPadding: CGFloat = 8
    /// Gap between the selection's top edge and the hint pill.
    private let topInset: CGFloat = 12

    init(text: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver + 3
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = AdaptiveChromeSurfaceView(style: .floating, cornerRadius: 8)

        label.stringValue = text
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        container.addSubview(label)
        contentView = container
    }

    /// Size to the text and place top-center inside `selectionRect`
    /// (AppKit screen coordinates).
    func present(in selectionRect: NSRect) {
        label.sizeToFit()
        let textSize = label.frame.size
        let width = textSize.width + horizontalPadding * 2
        let height = textSize.height + verticalPadding * 2

        contentView?.frame = NSRect(x: 0, y: 0, width: width, height: height)
        label.setFrameOrigin(NSPoint(x: horizontalPadding, y: verticalPadding))

        let origin = NSPoint(
            x: selectionRect.midX - width / 2,
            y: selectionRect.maxY - topInset - height
        )
        setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
    }
}

private final class ScrollCaptureControlWindow: NSPanel {
    init(buttonFrame: NSRect, onTap: @escaping () -> Void) {
        let padding: CGFloat = 6
        let windowRect = NSRect(
            x: buttonFrame.minX - padding,
            y: buttonFrame.minY - padding,
            width: buttonFrame.width + padding * 2,
            height: buttonFrame.height + padding * 2
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver + 4
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = ScrollCaptureControlView(
            frame: NSRect(origin: .zero, size: windowRect.size),
            onTap: onTap
        )
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
    }
}

private final class ScrollCaptureControlView: NSView {
    private let onTap: () -> Void

    init(frame: NSRect, onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        let button = ToolButton(
            frame: bounds.insetBy(dx: 6, dy: 6),
            symbolName: "arrow.up.and.down.text.horizontal",
            normalColor: .labelColor,
            selectedColor: accentGreen
        )
        button.isSelected = true
        button.target = self
        button.action = #selector(buttonTapped)
        addSubview(button)
    }

    @objc private func buttonTapped() {
        onTap()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

// MARK: - Crop Mode Control Window

/// Floating confirm button shown during crop mode. Stays on screen
/// regardless of how far the user scrolls the long screenshot.
private final class ScrollCropControlWindow: NSPanel {
    private static let windowSize = NSSize(width: 56, height: 44)

    init(onConfirm: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver + 4
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = ScrollCropControlView(
            frame: NSRect(origin: .zero, size: Self.windowSize),
            onConfirm: onConfirm
        )
    }

    func positionAtBottom(of screen: NSScreen) {
        let size = frame.size
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.minY + 36
        ))
    }

    func dismiss() {
        orderOut(nil)
        contentView = nil
    }
}

private final class ScrollCropControlView: NSView {
    private let onConfirm: () -> Void

    init(frame: NSRect, onConfirm: @escaping () -> Void) {
        self.onConfirm = onConfirm
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        let button = ToolButton(
            frame: bounds.insetBy(dx: 6, dy: 6),
            symbolName: "checkmark",
            normalColor: accentGreen,
            selectedColor: accentGreen
        )
        button.hoverTip = L10n.tipScrollCropConfirm
        button.target = self
        button.action = #selector(confirmTapped)
        addSubview(button)
    }

    @objc private func confirmTapped() {
        onConfirm()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

// MARK: - Scroll Preview Window

private final class ScrollPreviewWindow: NSPanel {
    private let imageView = NSImageView()
    private let maxPreviewWidth: CGFloat = 120
    private let maxPreviewHeight: CGFloat = 400
    private let contentInset: CGFloat = 4

    init() {
        let initialRect = NSRect(
            x: 0,
            y: 0,
            width: maxPreviewWidth + contentInset * 2,
            height: maxPreviewHeight + contentInset * 2
        )
        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver + 3
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let containerRect = NSRect(origin: .zero, size: initialRect.size)
        let container = AdaptiveChromeSurfaceView(
            style: .floating,
            cornerRadius: 8,
            borderWidth: 0.5
        )
        container.frame = containerRect
        container.autoresizingMask = [.width, .height]

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignTop
        imageView.frame = containerRect.insetBy(dx: contentInset, dy: contentInset)
        imageView.autoresizingMask = [.width, .height]
        container.addSubview(imageView)

        contentView = container
    }

    func updatePreview(_ image: NSImage, anchorRect: NSRect) {
        imageView.image = image
        let windowW = maxPreviewWidth + contentInset * 2
        let windowH = maxPreviewHeight + contentInset * 2

        // Position to the right of selection, or left if no room
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        var x = anchorRect.maxX + 12
        if x + windowW > screenFrame.maxX {
            x = anchorRect.minX - windowW - 12
        }
        // Vertically align to top of selection
        let y = anchorRect.maxY - windowH

        setFrame(NSRect(x: x, y: y, width: windowW, height: windowH), display: true)

        if !isVisible {
            orderFrontRegardless()
        }
    }

    func dismiss() {
        orderOut(nil)
        imageView.image = nil
        contentView = nil
    }
}

// MARK: - Color + Size Sub-toolbar

private enum ShapeStrokePreviewShape {
    case rectangle
    case ellipse
}

private class ColorSizeSubToolbar: NSView {
    var currentColor: NSColor = EditorStyleDefaults.primaryColor
    var currentSize: CGFloat = 3.0
    var currentArrowStyle: ArrowStyle?
    var currentShapeFillMode: ShapeFillMode?
    var currentShapeStrokeStyle: ShapeStrokeStyle?
    var onColorChanged: ((NSColor) -> Void)?
    var onSizeBegan: (() -> Void)?
    var onSizeChanged: ((CGFloat) -> Void)?
    var onSizeEnded: (() -> Void)?
    var onArrowStyleChanged: ((ArrowStyle) -> Void)?
    var onShapeFillModeChanged: ((ShapeFillMode) -> Void)?
    var onShapeStrokeStyleChanged: ((ShapeStrokeStyle) -> Void)?

    private var sizeSlider: HUDSlider?
    private var colorButtons: [NSView] = []
    private var arrowStyleButtons: [ArrowStyleButtonView] = []
    private var shapeFillModeControl: ShapeFillModeSegmentedControl?
    private var shapeStrokeStyleButtons: [ShapeStrokeStyleButtonView] = []

    private let sizes: [CGFloat]
    private let sizeMinValue: CGFloat
    private let sizeMaxValue: CGFloat
    private let showsShapeFillModes: Bool
    private let showsShapeStrokeStyles: Bool
    private let shapeStrokePreviewShape: ShapeStrokePreviewShape
    private let colors: [NSColor] = EditorStyleDefaults.paletteColors

    private static let leadingPad: CGFloat = 12
    private static let sizeSliderWidth: CGFloat = 136
    private static let swatchSize: CGFloat = 18
    private static let swatchGap: CGFloat = 5
    private static let separatorGap: CGFloat = 6
    private static let arrowStyleGap: CGFloat = 8
    private static let arrowStyleButtonWidth: CGFloat = 27
    private static let arrowStyleButtonHeight: CGFloat = 20
    private static let arrowStyleButtonGap: CGFloat = 4
    private static let shapeButtonWidth: CGFloat = 27
    private static let shapeButtonHeight: CGFloat = 20
    private static let trailingPad: CGFloat = 12
    private static var baseColorCount: CGFloat { CGFloat(EditorStyleDefaults.paletteColors.count) }

    static func preferredWidth(
        sizes: [CGFloat],
        showsShapeFillModes: Bool,
        showsArrowStyles: Bool = false,
        showsShapeStrokeStyles: Bool = false,
        shapeStrokePreviewShape: ShapeStrokePreviewShape = .rectangle
    ) -> CGFloat {
        var x = leadingPad
        if !sizes.isEmpty {
            x += sizeSliderWidth
            x += 8 + 1 + 9
        }

        let colorCount = baseColorCount
        x += colorCount * swatchSize + max(colorCount - 1, 0) * swatchGap

        if showsArrowStyles {
            let styleCount = CGFloat(ArrowStyle.allCases.count)
            x += separatorGap + 1 + arrowStyleGap
            x += styleCount * arrowStyleButtonWidth + max(styleCount - 1, 0) * arrowStyleButtonGap
        }

        if showsShapeFillModes {
            x += separatorGap + 1 + arrowStyleGap
            x += ShapeFillModeSegmentedControl.preferredWidth()
        }

        if showsShapeStrokeStyles {
            let styleCount = CGFloat(shapeStrokeStyles(for: shapeStrokePreviewShape).count)
            x += separatorGap + 1 + arrowStyleGap
            x += styleCount * shapeButtonWidth + max(styleCount - 1, 0) * arrowStyleButtonGap
        }

        return ceil(x + trailingPad)
    }

    private static func shapeStrokeStyles(for previewShape: ShapeStrokePreviewShape) -> [ShapeStrokeStyle] {
        switch previewShape {
        case .rectangle:
            return ShapeStrokeStyle.allCases
        case .ellipse:
            return ShapeStrokeStyle.allCases.filter { $0 != .rounded }
        }
    }

    init(
        frame: NSRect,
        sizes: [CGFloat] = [2, 4, 6],
        currentColor: NSColor = .red,
        currentSize: CGFloat = 3.0,
        sizeMinValue: CGFloat = CGFloat(Defaults.editorLineWidthMin),
        sizeMaxValue: CGFloat = CGFloat(Defaults.editorLineWidthMax),
        shapeFillMode: ShapeFillMode? = nil,
        shapeStrokeStyle: ShapeStrokeStyle? = nil,
        shapeStrokePreviewShape: ShapeStrokePreviewShape = .rectangle,
        arrowStyle: ArrowStyle? = nil
    ) {
        self.sizes = sizes
        self.sizeMinValue = sizeMinValue
        self.sizeMaxValue = max(sizeMinValue, sizeMaxValue)
        self.currentColor = currentColor
        self.currentSize = min(max(currentSize, sizeMinValue), max(sizeMinValue, sizeMaxValue))
        self.currentShapeFillMode = shapeFillMode
        self.currentShapeStrokeStyle = shapeStrokeStyle
        self.currentArrowStyle = arrowStyle
        self.showsShapeFillModes = shapeFillMode != nil
        self.showsShapeStrokeStyles = shapeStrokeStyle != nil
        self.shapeStrokePreviewShape = shapeStrokePreviewShape
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        var x: CGFloat = 12
        let midY = bounds.midY

        if !sizes.isEmpty {
            let slider = HUDSlider(
                value: Double(currentSize),
                minValue: Double(sizeMinValue),
                maxValue: Double(sizeMaxValue),
                target: self,
                action: #selector(sizeSliderChanged(_:))
            )
            slider.isContinuous = true
            slider.frame = NSRect(
                x: x,
                y: midY - HUDSlider.preferredHeight / 2,
                width: Self.sizeSliderWidth,
                height: HUDSlider.preferredHeight
            )
            slider.onEditingBegan = { [weak self] in self?.onSizeBegan?() }
            slider.onEditingEnded = { [weak self] in self?.onSizeEnded?() }
            addSubview(slider)
            sizeSlider = slider
            x += Self.sizeSliderWidth
        }

        // Separator only when there's a size section to separate from.
        if !sizes.isEmpty {
            x += 8
            let sep = AdaptiveSeparatorView(frame: NSRect(x: x, y: 6, width: 1, height: bounds.height - 12))
            addSubview(sep)
            x += 9
        }

        // Color swatches.
        let swatchSize: CGFloat = ColorSizeSubToolbar.swatchSize
        for (i, color) in colors.enumerated() {
            let swatch = ColorSwatchView(
                frame: NSRect(x: x, y: midY - swatchSize/2, width: swatchSize, height: swatchSize),
                color: color,
                isSelected: colorsMatch(color, currentColor)
            )
            swatch.itemIndex = i
            let click = NSClickGestureRecognizer(target: self, action: #selector(colorTapped(_:)))
            swatch.addGestureRecognizer(click)
            addSubview(swatch)
            colorButtons.append(swatch)
            x += swatchSize + ColorSizeSubToolbar.swatchGap
        }

        var lastSectionRightEdge = x - ColorSizeSubToolbar.swatchGap

        if currentArrowStyle != nil {
            let styleSepX = lastSectionRightEdge + ColorSizeSubToolbar.separatorGap
            let styleSep = AdaptiveSeparatorView(frame: NSRect(x: styleSepX, y: 6, width: 1, height: bounds.height - 12))
            addSubview(styleSep)

            x = styleSepX + 1 + ColorSizeSubToolbar.arrowStyleGap
            for style in ArrowStyle.allCases {
                let button = ArrowStyleButtonView(
                    frame: NSRect(
                        x: x,
                        y: midY - ColorSizeSubToolbar.arrowStyleButtonHeight / 2,
                        width: ColorSizeSubToolbar.arrowStyleButtonWidth,
                        height: ColorSizeSubToolbar.arrowStyleButtonHeight
                    ),
                    style: style,
                    isSelected: currentArrowStyle == style
                )
                let click = NSClickGestureRecognizer(target: self, action: #selector(arrowStyleTapped(_:)))
                button.addGestureRecognizer(click)
                addSubview(button)
                arrowStyleButtons.append(button)
                x += ColorSizeSubToolbar.arrowStyleButtonWidth + ColorSizeSubToolbar.arrowStyleButtonGap
            }
            lastSectionRightEdge = x - ColorSizeSubToolbar.arrowStyleButtonGap
        }

        if showsShapeFillModes {
            let fillSepX = lastSectionRightEdge + ColorSizeSubToolbar.separatorGap
            let fillSep = AdaptiveSeparatorView(frame: NSRect(x: fillSepX, y: 6, width: 1, height: bounds.height - 12))
            addSubview(fillSep)

            x = fillSepX + 1 + ColorSizeSubToolbar.arrowStyleGap
            let controlWidth = ShapeFillModeSegmentedControl.preferredWidth()
            let control = ShapeFillModeSegmentedControl(
                frame: NSRect(
                    x: x,
                    y: midY - ShapeFillModeSegmentedControl.preferredHeight / 2,
                    width: controlWidth,
                    height: ShapeFillModeSegmentedControl.preferredHeight
                ),
                selectedMode: currentShapeFillMode ?? .none
            )
            control.onSelect = { [weak self] mode in
                self?.currentShapeFillMode = mode
                self?.onShapeFillModeChanged?(mode)
            }
            addSubview(control)
            shapeFillModeControl = control
            lastSectionRightEdge = control.frame.maxX
        }

        if showsShapeStrokeStyles {
            let styleSepX = lastSectionRightEdge + ColorSizeSubToolbar.separatorGap
            let styleSep = AdaptiveSeparatorView(frame: NSRect(x: styleSepX, y: 6, width: 1, height: bounds.height - 12))
            addSubview(styleSep)

            x = styleSepX + 1 + ColorSizeSubToolbar.arrowStyleGap
            for style in Self.shapeStrokeStyles(for: shapeStrokePreviewShape) {
                let button = ShapeStrokeStyleButtonView(
                    frame: NSRect(
                        x: x,
                        y: midY - ColorSizeSubToolbar.shapeButtonHeight / 2,
                        width: ColorSizeSubToolbar.shapeButtonWidth,
                        height: ColorSizeSubToolbar.shapeButtonHeight
                    ),
                    style: style,
                    previewShape: shapeStrokePreviewShape,
                    isSelected: currentShapeStrokeStyle == style
                )
                let click = NSClickGestureRecognizer(target: self, action: #selector(shapeStrokeStyleTapped(_:)))
                button.addGestureRecognizer(click)
                addSubview(button)
                shapeStrokeStyleButtons.append(button)
                x += ColorSizeSubToolbar.shapeButtonWidth + ColorSizeSubToolbar.arrowStyleButtonGap
            }
        }
    }

    @objc private func sizeSliderChanged(_ sender: HUDSlider) {
        currentSize = min(max(CGFloat(sender.doubleValue), sizeMinValue), sizeMaxValue)
        onSizeChanged?(currentSize)
    }

    @objc private func colorTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ColorSwatchView else { return }
        let index = view.itemIndex
        let paletteColors = colors
        guard index < paletteColors.count else { return }
        currentColor = paletteColors[index]
        onColorChanged?(currentColor)
        updateColorSelection()
    }

    @objc private func arrowStyleTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ArrowStyleButtonView else { return }
        currentArrowStyle = view.style
        onArrowStyleChanged?(view.style)
        updateArrowStyleSelection()
    }

    @objc private func shapeStrokeStyleTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ShapeStrokeStyleButtonView else { return }
        currentShapeStrokeStyle = view.style
        onShapeStrokeStyleChanged?(view.style)
        updateShapeStrokeStyleSelection()
    }

    private func updateColorSelection() {
        let paletteColors = colors
        for (i, view) in colorButtons.enumerated() where i < paletteColors.count {
            (view as? ColorSwatchView)?.isSelected = colorsMatch(paletteColors[i], currentColor)
        }
    }

    private func updateArrowStyleSelection() {
        for view in arrowStyleButtons {
            view.isSelected = view.style == currentArrowStyle
        }
    }

    private func updateShapeFillModeSelection() {
        shapeFillModeControl?.selectedMode = currentShapeFillMode ?? .none
    }

    private func updateShapeStrokeStyleSelection() {
        for view in shapeStrokeStyleButtons {
            view.isSelected = view.style == currentShapeStrokeStyle
        }
    }

    private func colorsMatch(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let ac = a.usingColorSpace(.deviceRGB), let bc = b.usingColorSpace(.deviceRGB) else { return false }
        return abs(ac.redComponent - bc.redComponent) < 0.01 &&
               abs(ac.greenComponent - bc.greenComponent) < 0.01 &&
               abs(ac.blueComponent - bc.blueComponent) < 0.01
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

// MARK: - Mosaic Sub-toolbar

private class MosaicSubToolbar: NSView {
    var currentBlockSize: CGFloat
    var onBlockSizeBegan: (() -> Void)?
    var onBlockSizeChanged: ((CGFloat) -> Void)?
    var onBlockSizeEnded: (() -> Void)?

    private var slider: HUDSlider!

    static let preferredWidth: CGFloat = 178
    private static let leadingPad: CGFloat = 12
    private static let sliderWidth: CGFloat = 154

    init(frame: NSRect, currentBlockSize: CGFloat) {
        self.currentBlockSize = Self.clampedBlockSize(currentBlockSize)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        let x = Self.leadingPad
        let midY = bounds.midY

        let s = HUDSlider(
            value: Double(currentBlockSize),
            minValue: Defaults.mosaicBlockSizeMin,
            maxValue: Defaults.mosaicBlockSizeMax,
            target: self,
            action: #selector(sliderChanged(_:))
        )
        s.isContinuous = true
        s.frame = NSRect(
            x: x,
            y: midY - HUDSlider.preferredHeight / 2,
            width: Self.sliderWidth,
            height: HUDSlider.preferredHeight
        )
        s.toolTip = L10n.mosaicGranularity
        s.onEditingBegan = { [weak self] in self?.onBlockSizeBegan?() }
        s.onEditingEnded = { [weak self] in self?.onBlockSizeEnded?() }
        addSubview(s)
        slider = s
    }

    @objc private func sliderChanged(_ sender: HUDSlider) {
        let clamped = Self.clampedBlockSize(CGFloat(sender.doubleValue))
        currentBlockSize = clamped
        onBlockSizeChanged?(clamped)
    }

    private static func clampedBlockSize(_ size: CGFloat) -> CGFloat {
        max(
            CGFloat(Defaults.mosaicBlockSizeMin),
            min(CGFloat(Defaults.mosaicBlockSizeMax), size)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

// MARK: - Text Sub-toolbar

/// Text-tool sub-toolbar — color swatches plus a 10–100 font-size slider.
private class TextSubToolbar: NSView {
    var currentColor: NSColor = .red
    var currentFontSize: CGFloat = CGFloat(Defaults.lastTextFontSize)
    var strokeEnabled: Bool = false
    var calloutEnabled: Bool = false
    var onColorChanged: ((NSColor) -> Void)?
    /// Fired when the user grabs the slider thumb (mouseDown phase).
    var onFontSizeBegan: (() -> Void)?
    /// Fired on every slider tick during a drag.
    var onFontSizeChanged: ((CGFloat) -> Void)?
    /// Fired when the user releases the slider (mouseUp phase).
    var onFontSizeEnded: (() -> Void)?
    /// Fired when the outline checkbox is toggled.
    var onStrokeChanged: ((Bool) -> Void)?
    /// Fired when the callout checkbox is toggled.
    var onCalloutChanged: ((Bool) -> Void)?

    private var colorButtons: [NSView] = []
    private var slider: HUDSlider!
    private var strokeCheckbox: HUDCheckboxButton!
    private var calloutCheckbox: HUDCheckboxButton!

    private let colors: [NSColor] = EditorStyleDefaults.paletteColors

    // Layout metrics, shared between `setup()` and `preferredWidth` so the
    // view is always wide enough for everything it lays out.
    private static let leadingPad: CGFloat = 12
    private static let sliderWidth: CGFloat = 150
    private static let swatchSize: CGFloat = 18
    private static let swatchGap: CGFloat = 5
    private static let separatorGap: CGFloat = 6
    private static let checkboxGap: CGFloat = 8
    private static let trailingPad: CGFloat = 12
    private static var baseColorCount: CGFloat { CGFloat(EditorStyleDefaults.paletteColors.count) }

    /// Right edge of the last color swatch — the swatch row's extent.
    private static var swatchRowEnd: CGFloat {
        let colorCount = baseColorCount
        return leadingPad + sliderWidth + 8 + 1 + 9
            + colorCount * swatchSize + max(colorCount - 1, 0) * swatchGap
    }

    private static func checkboxWidth(title: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        return 16 + 8 + textWidth
    }

    private static var strokeCheckboxWidth: CGFloat {
        checkboxWidth(title: L10n.textStrokeEffect)
    }

    private static var calloutCheckboxWidth: CGFloat {
        checkboxWidth(title: L10n.textCalloutEffect)
    }

    static var preferredWidth: CGFloat {
        swatchRowEnd
            + separatorGap + 1 + checkboxGap
            + strokeCheckboxWidth + checkboxGap + calloutCheckboxWidth
            + trailingPad
    }

    init(
        frame: NSRect,
        currentColor: NSColor,
        currentFontSize: CGFloat,
        strokeEnabled: Bool,
        calloutEnabled: Bool
    ) {
        self.currentColor = currentColor
        self.currentFontSize = currentFontSize
        self.strokeEnabled = strokeEnabled
        self.calloutEnabled = calloutEnabled
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setup() {
        var x: CGFloat = 12
        let midY = bounds.midY

        // Font-size slider.
        let s = HUDSlider(
            value: Double(currentFontSize),
            minValue: Defaults.textFontSizeMin,
            maxValue: Defaults.textFontSizeMax,
            target: self,
            action: #selector(sliderChanged(_:))
        )
        s.isContinuous = true
        s.frame = NSRect(
            x: x,
            y: midY - HUDSlider.preferredHeight / 2,
            width: TextSubToolbar.sliderWidth,
            height: HUDSlider.preferredHeight
        )
        s.onEditingBegan = { [weak self] in self?.onFontSizeBegan?() }
        s.onEditingEnded = { [weak self] in self?.onFontSizeEnded?() }
        addSubview(s)
        slider = s
        x += TextSubToolbar.sliderWidth + 8

        // Vertical separator between size controls and color swatches.
        let sep = AdaptiveSeparatorView(frame: NSRect(x: x, y: 6, width: 1, height: bounds.height - 12))
        addSubview(sep)
        x += 1 + 9

        // Color swatches.
        let swatchSize: CGFloat = TextSubToolbar.swatchSize
        for (i, color) in colors.enumerated() {
            let swatch = ColorSwatchView(
                frame: NSRect(x: x, y: midY - swatchSize / 2, width: swatchSize, height: swatchSize),
                color: color,
                isSelected: colorsMatch(color, currentColor)
            )
            swatch.itemIndex = i
            let click = NSClickGestureRecognizer(target: self, action: #selector(colorTapped(_:)))
            swatch.addGestureRecognizer(click)
            addSubview(swatch)
            colorButtons.append(swatch)
            x += swatchSize + TextSubToolbar.swatchGap
        }

        // Vertical separator between color swatches and the outline checkbox.
        let lastSwatchRightEdge = x - TextSubToolbar.swatchGap
        let strokeSepX = lastSwatchRightEdge + TextSubToolbar.separatorGap
        let strokeSep = AdaptiveSeparatorView(frame: NSRect(x: strokeSepX, y: 6, width: 1, height: bounds.height - 12))
        addSubview(strokeSep)

        // Outline checkbox.
        let checkboxHeight: CGFloat = 20
        let checkbox = HUDCheckboxButton(
            frame: NSRect(
                x: strokeSepX + 1 + TextSubToolbar.checkboxGap,
                y: midY - checkboxHeight / 2,
                width: TextSubToolbar.strokeCheckboxWidth,
                height: checkboxHeight
            ),
            title: L10n.textStrokeEffect,
            target: self,
            action: #selector(strokeCheckboxChanged(_:))
        )
        checkbox.state = strokeEnabled ? .on : .off
        addSubview(checkbox)
        strokeCheckbox = checkbox

        let calloutX = checkbox.frame.maxX + TextSubToolbar.checkboxGap
        let calloutCheckbox = HUDCheckboxButton(
            frame: NSRect(
                x: calloutX,
                y: midY - checkboxHeight / 2,
                width: TextSubToolbar.calloutCheckboxWidth,
                height: checkboxHeight
            ),
            title: L10n.textCalloutEffect,
            target: self,
            action: #selector(calloutCheckboxChanged(_:))
        )
        calloutCheckbox.state = calloutEnabled ? .on : .off
        addSubview(calloutCheckbox)
        self.calloutCheckbox = calloutCheckbox

    }

    @objc private func strokeCheckboxChanged(_ sender: HUDCheckboxButton) {
        strokeEnabled = sender.state == .on
        onStrokeChanged?(strokeEnabled)
    }

    @objc private func calloutCheckboxChanged(_ sender: HUDCheckboxButton) {
        calloutEnabled = sender.state == .on
        onCalloutChanged?(calloutEnabled)
    }

    @objc private func sliderChanged(_ sender: HUDSlider) {
        let raw = CGFloat(sender.doubleValue)
        let clamped = max(CGFloat(Defaults.textFontSizeMin), min(CGFloat(Defaults.textFontSizeMax), raw))

        currentFontSize = clamped
        onFontSizeChanged?(clamped)
    }

    @objc private func colorTapped(_ gesture: NSGestureRecognizer) {
        guard let view = gesture.view as? ColorSwatchView else { return }
        let index = view.itemIndex
        let paletteColors = colors
        guard index < paletteColors.count else { return }
        currentColor = paletteColors[index]
        onColorChanged?(currentColor)
        for (i, v) in colorButtons.enumerated() where i < paletteColors.count {
            (v as? ColorSwatchView)?.isSelected = colorsMatch(paletteColors[i], currentColor)
        }
    }

    private func colorsMatch(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let ac = a.usingColorSpace(.deviceRGB), let bc = b.usingColorSpace(.deviceRGB) else { return false }
        return abs(ac.redComponent - bc.redComponent) < 0.01 &&
               abs(ac.greenComponent - bc.greenComponent) < 0.01 &&
               abs(ac.blueComponent - bc.blueComponent) < 0.01
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        AdaptiveChrome.toolbarBackground.setFill()
        path.fill()
    }
}

private final class ArrowStyleButtonView: NSView {
    let style: ArrowStyle
    var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    init(frame: NSRect, style: ArrowStyle, isSelected: Bool) {
        self.style = style
        self.isSelected = isSelected
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color = isSelected ? EditorOptionChrome.selectionColor : NSColor.secondaryLabelColor
        color.setFill()
        color.setStroke()

        let start = NSPoint(x: bounds.minX + 3, y: bounds.midY)
        let end = NSPoint(x: bounds.maxX - 3, y: bounds.midY)

        switch style {
        case .tapered:
            let path = NSBezierPath()
            let headLength: CGFloat = 8
            let headHalf: CGFloat = 4.5
            let neckHalf: CGFloat = 2.3
            let tailHalf: CGFloat = 1.1
            let baseX = end.x - headLength
            let neckX = end.x - headLength * 0.7
            path.move(to: end)
            path.line(to: NSPoint(x: baseX, y: end.y + headHalf))
            path.line(to: NSPoint(x: neckX, y: end.y + neckHalf))
            path.line(to: NSPoint(x: start.x, y: start.y + tailHalf))
            path.line(to: NSPoint(x: start.x, y: start.y - tailHalf))
            path.line(to: NSPoint(x: neckX, y: end.y - neckHalf))
            path.line(to: NSPoint(x: baseX, y: end.y - headHalf))
            path.close()
            path.fill()

        case .doubleEnded:
            let headLength: CGFloat = 7.5
            let shaft = NSBezierPath()
            shaft.move(to: NSPoint(x: start.x + headLength, y: start.y))
            shaft.line(to: NSPoint(x: end.x - headLength, y: end.y))
            shaft.lineWidth = 2
            shaft.lineCapStyle = .round
            shaft.stroke()
            drawRoundedHead(tip: end, unitX: 1, length: headLength, width: 6)
            drawRoundedHead(tip: start, unitX: -1, length: headLength, width: 6)

        case .line:
            let headLength: CGFloat = 7.5
            let shaft = NSBezierPath()
            shaft.move(to: start)
            shaft.line(to: NSPoint(x: end.x - headLength, y: end.y))
            shaft.lineWidth = 2
            shaft.lineCapStyle = .round
            shaft.stroke()
            drawRoundedHead(tip: end, unitX: 1, length: headLength, width: 6)

        case .dotTail:
            let radius: CGFloat = 3.4
            let headLength: CGFloat = 7.5
            let shaft = NSBezierPath()
            shaft.move(to: start)
            shaft.line(to: NSPoint(x: end.x - headLength, y: end.y))
            shaft.lineWidth = 2
            shaft.lineCapStyle = .round
            shaft.stroke()
            NSBezierPath(ovalIn: NSRect(
                x: start.x - radius,
                y: start.y - radius,
                width: radius * 2,
                height: radius * 2
            )).fill()
            drawRoundedHead(tip: end, unitX: 1, length: headLength, width: 6)
        }
    }

    private func drawRoundedHead(tip: NSPoint, unitX: CGFloat, length: CGFloat, width: CGFloat) {
        let head = arrowHead(tip: tip, unitX: unitX, length: length, width: width)
        head.lineJoinStyle = .round
        head.lineWidth = 0.9
        head.fill()
        head.stroke()
    }

    private func arrowHead(tip: NSPoint, unitX: CGFloat, length: CGFloat, width: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let baseX = tip.x - unitX * length
        path.move(to: tip)
        path.line(to: NSPoint(x: baseX, y: tip.y + width / 2))
        path.line(to: NSPoint(x: baseX, y: tip.y - width / 2))
        path.close()
        return path
    }
}

// MARK: - Color Swatch View

private class ColorSwatchView: NSView {
    let color: NSColor
    var isSelected: Bool = false {
        didSet { needsDisplay = true }
    }
    var itemIndex: Int = 0

    init(frame: NSRect, color: NSColor, isSelected: Bool) {
        self.color = color
        self.isSelected = isSelected
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Draw color circle
        let inset: CGFloat = isSelected ? 1 : 2
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
        color.setFill()
        path.fill()

        if isSelected {
            // Draw green selection ring
            let ring = NSBezierPath(ovalIn: bounds)
            accentGreen.setStroke()
            ring.lineWidth = 2
            ring.stroke()
        }

        // Draw border for white/light colors
        if color == .white || color == NSColor(white: 0.5, alpha: 1.0) {
            let border = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
            NSColor.gray.withAlphaComponent(0.3).setStroke()
            border.lineWidth = 0.5
            border.stroke()
        }
    }

}

// MARK: - HUD Slider

final class HUDSlider: NSControl {
    var minValue: Double
    var maxValue: Double
    var onEditingBegan: (() -> Void)?
    var onEditingEnded: (() -> Void)?

    override var doubleValue: Double {
        get { value }
        set { setValue(newValue, notify: false) }
    }

    override var isEnabled: Bool {
        didSet {
            if !isEnabled {
                isDragging = false
            }
            needsDisplay = true
        }
    }

    private var value: Double
    private var isDragging = false {
        didSet { needsDisplay = true }
    }

    static let preferredHeight: CGFloat = 24
    private let standardKnobHeight: CGFloat = 20
    private let standardKnobMinWidth: CGFloat = 34
    private let knobHorizontalPadding: CGFloat = 12
    private let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)

    init(
        frame: NSRect = .zero,
        value: Double,
        minValue: Double,
        maxValue: Double,
        target: AnyObject?,
        action: Selector?
    ) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = min(max(value, minValue), maxValue)
        super.init(frame: frame)
        self.target = target
        self.action = action
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.preferredHeight)
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isEnabled }

    override func draw(_ dirtyRect: NSRect) {
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.35
        let trackRect = currentTrackRect
        let trackPath = NSBezierPath(
            roundedRect: trackRect,
            xRadius: EditorOptionChrome.sliderTrackHeight / 2,
            yRadius: EditorOptionChrome.sliderTrackHeight / 2
        )
        AdaptiveChrome.border.withAlphaComponent(0.9 * enabledAlpha).setFill()
        trackPath.fill()

        let knobCenterX = trackRect.minX + normalizedValue * trackRect.width

        let knobWidth = currentKnobWidth
        let knobRect = NSRect(
            x: knobCenterX - knobWidth / 2,
            y: floor(bounds.midY - knobHeight / 2),
            width: knobWidth,
            height: knobHeight
        )
        let knobPath = NSBezierPath(
            roundedRect: knobRect,
            xRadius: knobHeight / 2,
            yRadius: knobHeight / 2
        )
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24 * enabledAlpha)
        shadow.shadowBlurRadius = 2.5
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        NSColor.controlBackgroundColor.withAlphaComponent(enabledAlpha).setFill()
        knobPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        AdaptiveChrome.border.withAlphaComponent(enabledAlpha).setStroke()
        knobPath.lineWidth = 0.6
        knobPath.stroke()

        drawValue(in: knobRect, enabledAlpha: enabledAlpha)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        isDragging = true
        onEditingBegan?()
        updateValue(with: event, notify: true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        updateValue(with: event, notify: isContinuous)
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else {
            isDragging = false
            return
        }
        updateValue(with: event, notify: true)
        isDragging = false
        onEditingEnded?()
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        let fineStep = max((maxValue - minValue) / 100, 0.1)
        let coarseStep = max((maxValue - minValue) / 20, fineStep)
        let step = event.modifierFlags.contains(.shift) ? coarseStep : fineStep
        switch Int(event.keyCode) {
        case kVK_LeftArrow, kVK_DownArrow:
            onEditingBegan?()
            setValue(value - step, notify: true)
            onEditingEnded?()
        case kVK_RightArrow, kVK_UpArrow:
            onEditingBegan?()
            setValue(value + step, notify: true)
            onEditingEnded?()
        default:
            super.keyDown(with: event)
        }
    }

    private var normalizedValue: CGFloat {
        guard maxValue > minValue else { return 0 }
        return CGFloat((value - minValue) / (maxValue - minValue))
    }

    private var usesCircularWidthValueBadge: Bool {
        EditorOptionChrome.usesCircularWidthValueBadge(
            minValue: minValue,
            maxValue: maxValue
        )
    }

    private var knobHeight: CGFloat {
        usesCircularWidthValueBadge
            ? EditorOptionChrome.lineWidthValueBadgeDiameter
            : standardKnobHeight
    }

    private var currentKnobWidth: CGFloat {
        if usesCircularWidthValueBadge {
            return EditorOptionChrome.lineWidthValueBadgeDiameter
        }
        let samples = [
            displayText(for: minValue),
            displayText(for: maxValue),
            displayText(for: value),
        ]
        let maxWidth = samples
            .map { ceil(($0 as NSString).size(withAttributes: [.font: valueFont]).width) }
            .max() ?? 0
        return max(standardKnobMinWidth, maxWidth + knobHorizontalPadding)
    }

    private var currentTrackRect: NSRect {
        let knobWidth = currentKnobWidth
        return NSRect(
            x: knobWidth / 2,
            y: floor(bounds.midY - EditorOptionChrome.sliderTrackHeight / 2),
            width: max(1, bounds.width - knobWidth),
            height: EditorOptionChrome.sliderTrackHeight
        )
    }

    private func updateValue(with event: NSEvent, notify: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        let trackRect = currentTrackRect
        let normalized = max(0, min(1, (point.x - trackRect.minX) / trackRect.width))
        setValue(minValue + Double(normalized) * (maxValue - minValue), notify: notify)
    }

    private func setValue(_ newValue: Double, notify: Bool) {
        value = min(max(newValue, minValue), maxValue)
        needsDisplay = true
        if notify, let action {
            sendAction(action, to: target)
        }
    }

    private func drawValue(in rect: NSRect, enabledAlpha: CGFloat) {
        let text = displayText(for: value)
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: valueFont,
                .foregroundColor: NSColor.labelColor.withAlphaComponent(enabledAlpha),
            ]
        )
        let textSize = attributed.size()
        let textRect = NSRect(
            x: floor(rect.midX - textSize.width / 2),
            y: floor(rect.midY - textSize.height / 2),
            width: ceil(textSize.width),
            height: ceil(textSize.height)
        )
        attributed.draw(in: textRect)
    }

    private func displayText(for rawValue: Double) -> String {
        "\(Int(rawValue.rounded()))"
    }
}

private final class ShapeFillModeSegmentedControl: NSView {
    static let preferredHeight: CGFloat = 24
    private static let minSegmentWidth: CGFloat = 54
    private static let segmentHorizontalPadding: CGFloat = 18
    private static let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private static let modes = ShapeFillMode.allCases

    var selectedMode: ShapeFillMode {
        didSet { needsDisplay = true }
    }
    var onSelect: ((ShapeFillMode) -> Void)?

    init(frame: NSRect, selectedMode: ShapeFillMode) {
        self.selectedMode = selectedMode
        super.init(frame: frame)
        toolTip = "\(L10n.shapeFillEffect) (F)"
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func preferredWidth() -> CGFloat {
        segmentWidths().reduce(0, +)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let mode = mode(atX: point.x) else { return }
        selectedMode = mode
        onSelect?(mode)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let background = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        AdaptiveChrome.cardBackground.setFill()
        background.fill()

        let widths = Self.segmentWidths()
        var x = rect.minX
        for (index, mode) in Self.modes.enumerated() {
            let width = widths[index]
            let segmentRect = NSRect(x: x, y: rect.minY, width: width, height: rect.height)
            if mode == selectedMode {
                let selected = NSBezierPath(
                    roundedRect: segmentRect.insetBy(dx: 1, dy: 1),
                    xRadius: 6,
                    yRadius: 6
                )
                if EditorOptionChrome.shapeFillSelectionDrawsBackground {
                    EditorOptionChrome.selectionColor.setFill()
                    selected.fill()
                }
                EditorOptionChrome.selectionColor.setStroke()
                selected.lineWidth = EditorOptionChrome.shapeFillSelectionBorderWidth
                selected.stroke()
            } else if index > 0 {
                AdaptiveChrome.separator.setStroke()
                let sep = NSBezierPath()
                sep.move(to: NSPoint(x: x, y: rect.minY + 4))
                sep.line(to: NSPoint(x: x, y: rect.maxY - 4))
                sep.lineWidth = 1
                sep.stroke()
            }
            drawTitle(for: mode, in: segmentRect)
            x += width
        }

        AdaptiveChrome.border.setStroke()
        background.lineWidth = 1
        background.stroke()
    }

    private static func segmentWidths() -> [CGFloat] {
        modes.map { mode in
            let textWidth = ceil((title(for: mode) as NSString).size(withAttributes: [.font: font]).width)
            return max(minSegmentWidth, textWidth + segmentHorizontalPadding)
        }
    }

    private static func title(for mode: ShapeFillMode) -> String {
        switch mode {
        case .none: return L10n.shapeFillNone
        case .opaque: return L10n.shapeFillOpaque
        case .translucent: return L10n.shapeFillTranslucent
        }
    }

    private func mode(atX targetX: CGFloat) -> ShapeFillMode? {
        let widths = Self.segmentWidths()
        var x: CGFloat = 0
        for (index, width) in widths.enumerated() {
            if targetX >= x && targetX <= x + width {
                return Self.modes[index]
            }
            x += width
        }
        return nil
    }

    private func drawTitle(for mode: ShapeFillMode, in rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.font,
            .foregroundColor: NSColor.labelColor,
        ]
        let title = Self.title(for: mode) as NSString
        let size = title.size(withAttributes: attributes)
        let point = NSPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        title.draw(at: point, withAttributes: attributes)
    }
}

private final class ShapeStrokeStyleButtonView: NSView {
    let style: ShapeStrokeStyle
    let previewShape: ShapeStrokePreviewShape
    var isSelected: Bool {
        didSet { needsDisplay = true }
    }

    init(frame: NSRect, style: ShapeStrokeStyle, previewShape: ShapeStrokePreviewShape, isSelected: Bool) {
        self.style = style
        self.previewShape = previewShape
        self.isSelected = isSelected
        super.init(frame: frame)
        switch style {
        case .standard:
            toolTip = L10n.shapeStyleStandard
        case .rounded:
            toolTip = L10n.shapeStyleRounded
        case .handDrawn:
            toolTip = L10n.shapeStyleHandDrawn
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color = isSelected ? EditorOptionChrome.selectionColor : NSColor.secondaryLabelColor

        if isSelected {
            let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 7, yRadius: 7)
            EditorOptionChrome.selectionColor.withAlphaComponent(0.12).setFill()
            bg.fill()
        }

        switch style {
        case .standard:
            drawStandardIcon(color: color)
        case .rounded:
            switch previewShape {
            case .rectangle:
                drawRoundedRectangleIcon(color: color)
            case .ellipse:
                drawStandardIcon(color: color)
            }
        case .handDrawn:
            switch previewShape {
            case .rectangle:
                drawHandDrawnRectangleIcon(color: color)
            case .ellipse:
                drawHandDrawnCircleIcon(color: color)
            }
        }
    }

    private func drawStandardIcon(color: NSColor) {
        color.setStroke()
        switch previewShape {
        case .rectangle:
            let rect = bounds.insetBy(dx: 6, dy: 4.5)
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1.9
            path.stroke()
        case .ellipse:
            let side = min(bounds.width, bounds.height) - 8
            let rect = NSRect(
                x: bounds.midX - side / 2,
                y: bounds.midY - side / 2,
                width: side,
                height: side
            )
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = 1.9
            path.stroke()
        }
    }

    private func drawRoundedRectangleIcon(color: NSColor) {
        color.setStroke()
        let rect = bounds.insetBy(dx: 6, dy: 4.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4.3, yRadius: 4.3)
        path.lineWidth = 1.9
        path.stroke()
    }

    private func drawHandDrawnRectangleIcon(color: NSColor) {
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

        let outerRect = bounds.insetBy(dx: 4.4, dy: 3.4)
        let innerRect = NSRect(
            x: outerRect.minX + 4.2,
            y: outerRect.minY + 3.2,
            width: outerRect.width - 7.4,
            height: outerRect.height - 5.5
        )
        let outerRadius: CGFloat = 5.2
        let innerRadius: CGFloat = 2.6
        let outer = NSBezierPath(roundedRect: outerRect, xRadius: outerRadius, yRadius: outerRadius)
        let inner = NSBezierPath(roundedRect: innerRect, xRadius: innerRadius, yRadius: innerRadius)
        fillHandDrawnPreviewRing(outer: outer, inner: inner, color: color)
    }

    private func drawHandDrawnCircleIcon(color: NSColor) {
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

        let outerRect = NSRect(
            x: bounds.midX - 9.4,
            y: bounds.midY - 6.9,
            width: 18.8,
            height: 13.8
        )
        let innerRect = NSRect(
            x: outerRect.minX + 3.0,
            y: outerRect.minY + 2.35,
            width: outerRect.width - 5.7,
            height: outerRect.height - 5.25
        )
        let outer = NSBezierPath(ovalIn: outerRect)
        let inner = NSBezierPath(ovalIn: innerRect)
        fillHandDrawnPreviewRing(outer: outer, inner: inner, color: color)
    }

    private func fillHandDrawnPreviewRing(outer: NSBezierPath, inner: NSBezierPath, color: NSColor) {
        let shape = NSBezierPath()
        shape.append(outer)
        shape.append(inner)
        shape.windingRule = .evenOdd
        color.setFill()
        shape.fill()
    }
}

// MARK: - HUD Checkbox

private final class HUDCheckboxButton: NSButton {
    private let label: String
    private let labelFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private let boxSize: CGFloat = 16

    init(frame: NSRect, title: String, target: AnyObject?, action: Selector?) {
        self.label = title
        super.init(frame: frame)
        self.title = ""
        self.target = target
        self.action = action
        setButtonType(.toggle)
        bezelStyle = .regularSquare
        isBordered = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.35
        let boxRect = NSRect(
            x: 0,
            y: floor(bounds.midY - boxSize / 2),
            width: boxSize,
            height: boxSize
        )
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)

        if state == .on {
            EditorOptionChrome.selectionColor.withAlphaComponent(enabledAlpha).setFill()
        } else {
            AdaptiveChrome.subtleFill
                .withAlphaComponent((isHighlighted ? 1.0 : 0.72) * enabledAlpha)
                .setFill()
        }
        boxPath.fill()

        AdaptiveChrome.border.withAlphaComponent(enabledAlpha).setStroke()
        boxPath.lineWidth = 1
        boxPath.stroke()

        if state == .on {
            let check = NSBezierPath()
            check.move(to: NSPoint(x: boxRect.minX + 4.0, y: boxRect.midY + 0.5))
            check.line(to: NSPoint(x: boxRect.minX + 7.0, y: boxRect.midY + 3.5))
            check.line(to: NSPoint(x: boxRect.maxX - 3.5, y: boxRect.midY - 4.0))
            check.lineWidth = 2
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSColor(white: 0.08, alpha: enabledAlpha).setStroke()
            check.stroke()
        }

        let attributed = NSAttributedString(
            string: label,
            attributes: [
                .font: labelFont,
                .foregroundColor: NSColor.labelColor.withAlphaComponent(enabledAlpha),
            ]
        )
        let textSize = attributed.size()
        let textRect = NSRect(
            x: boxRect.maxX + 8,
            y: floor(bounds.midY - textSize.height / 2),
            width: max(0, bounds.width - boxRect.maxX - 8),
            height: ceil(textSize.height)
        )
        attributed.draw(in: textRect)
    }
}

// MARK: - Selection Chrome Overlay

/// Sits above the editor's `canvasScrollView` so the selection remains
/// adjustable while the canvas owns its interior. Handle hits resize, border
/// hits move the whole selection, and every other hit falls through.
final class SelectionChromeOverlay: NSView {
    weak var selectionView: SelectionView?
    var onMoveStart: (() -> Void)?

    private(set) var selectionRectInView: NSRect = .zero

    private let handleHitSize: CGFloat = 12
    private let borderHitSize: CGFloat = 7

    private enum DragAction {
        case none
        case move
        case resize(SelectionView.HandlePosition)
    }

    private var dragAction: DragAction = .none
    private var dragStartPoint: NSPoint = .zero
    private var dragOriginalRect: NSRect = .zero

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func update(rect: NSRect) {
        selectionRectInView = rect
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let selectionView, selectionView.selectionInteractionEnabled else { return nil }
        // `point` is in the superview's coordinate space.
        let local = convert(point, from: superview)
        let handle = SelectionView.hitTestHandle(
            point: local,
            rect: selectionRectInView,
            hitSize: handleHitSize
        )
        return handle != nil || Self.isBorderHit(
            point: local,
            rect: selectionRectInView,
            hitSize: borderHitSize
        ) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let selectionView, selectionView.selectionInteractionEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        dragOriginalRect = selectionView.currentSelectionRect ?? selectionRectInView
        if let handle = SelectionView.hitTestHandle(
            point: point,
            rect: selectionRectInView,
            hitSize: handleHitSize
        ) {
            dragAction = .resize(handle)
            SelectionView.setCursorForHandle(handle)
        } else if Self.isBorderHit(
            point: point,
            rect: selectionRectInView,
            hitSize: borderHitSize
        ) {
            dragAction = .move
            dragStartPoint = point
            onMoveStart?()
            NSCursor.closedHand.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let selectionView else { return }
        let point = convert(event.locationInWindow, from: nil)
        switch dragAction {
        case .none:
            return
        case .move:
            selectionView.moveByExternalDrag(
                deltaFromOriginal: CGSize(
                    width: point.x - dragStartPoint.x,
                    height: point.y - dragStartPoint.y
                ),
                originalRect: dragOriginalRect
            )
        case let .resize(handle):
            selectionView.resizeByExternalDrag(
                handle: handle,
                originalRect: dragOriginalRect,
                currentPoint: point
            )
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let selectionView else {
            dragAction = .none
            return
        }
        let completedAction = dragAction
        switch completedAction {
        case .none:
            break
        case .move:
            selectionView.finalizeExternalDrag()
        case .resize:
            selectionView.finalizeExternalResize()
        }
        dragAction = .none

        switch completedAction {
        case let .resize(handle):
            SelectionView.setCursorForHandle(handle)
        case .move:
            NSCursor.openHand.set()
        case .none:
            break
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let selectionView, selectionView.selectionInteractionEnabled else { return }
        let point = convert(event.locationInWindow, from: nil)
        if let handle = SelectionView.hitTestHandle(
            point: point,
            rect: selectionRectInView,
            hitSize: handleHitSize
        ) {
            SelectionView.setCursorForHandle(handle)
        } else if Self.isBorderHit(
            point: point,
            rect: selectionRectInView,
            hitSize: borderHitSize
        ) {
            NSCursor.openHand.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if case .none = dragAction {
            NSCursor.arrow.set()
        }
    }

    static func isBorderHit(point: NSPoint, rect: NSRect, hitSize: CGFloat) -> Bool {
        EditorCursorRoutingPolicy.isSelectionBorderHit(
            point: point,
            rect: rect,
            hitSize: hitSize
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

}
