import AppKit
import Carbon
import QuartzCore
import UniformTypeIdentifiers

@MainActor
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

    /// Shows the stitched long screenshot scaled to fit inside the original
    /// capture selection, with a top/bottom crop overlay.
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

        guard let cropFrame = ScrollCropPresentationGeometry.cropFrame(
            selectionRect: selectionViewRect,
            hostBounds: hostSelectionView.bounds
        ) else {
            logScrollCapture("crop-mode-invalid-selection")
            finishCropFallback(with: image)
            return
        }

        isCropping = true
        activeTool = .none
        canvasView?.activeTool = .none
        toolbars.forEach { $0.updateSelection(tool: .none) }
        toolbars.forEach { $0.isHidden = true }
        selectionChromeOverlay?.isHidden = true
        hostSelectionView.cropPresentationActive = true
        updateEditorInteractionState()

        let cropView = ScrollCropView(frame: cropFrame, image: image)
        hostSelectionView.addSubview(cropView)
        scrollCropView = cropView

        showCropControl(anchoredTo: cropFrame, in: hostSelectionView)
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
        hostSelectionView?.cropPresentationActive = false
        scrollCropView?.removeFromSuperview()
        scrollCropView = nil
        scrollCropControlWindow?.dismiss()
        scrollCropControlWindow = nil
        selectionChromeOverlay?.isHidden = false
        toolbars.forEach { $0.isHidden = false }
        updateEditorInteractionState()
        bringEditorToFront()
    }

    private func showCropControl(anchoredTo cropFrame: NSRect, in hostView: NSView) {
        let controlWindow = ScrollCropControlWindow(
            onConfirm: { [weak self] in self?.confirmCrop() }
        )
        let frameInWindow = hostView.convert(cropFrame, to: nil)
        let frameOnScreen = hostView.window?.convertToScreen(frameInWindow) ?? screen.frame
        controlWindow.position(near: frameOnScreen, within: screen)
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
        hostSelectionView?.cropPresentationActive = false
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
