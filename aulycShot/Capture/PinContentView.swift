import AppKit

// MARK: - Pin Content View (zoomable image with floating controls)

/// Builds a small bitmap once so continuous zoom redraws do not repeatedly
/// resample the full-resolution source image on the main thread.
private enum PinInteractivePreviewRenderer {
    private static let queue = DispatchQueue(
        label: "aulycShot.pin.interactive-preview",
        qos: .userInitiated
    )

    @MainActor
    static func makePreview(
        from source: CGImage,
        completion: @escaping @MainActor @Sendable (CGImage?) -> Void
    ) {
        let longestEdge = max(source.width, source.height)
        guard longestEdge > PinZoom.interactivePreviewMaxPixelDimension else {
            completion(source)
            return
        }

        let scale = CGFloat(PinZoom.interactivePreviewMaxPixelDimension) / CGFloat(longestEdge)
        let width = max(1, Int((CGFloat(source.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(source.height) * scale).rounded()))

        queue.async {
            let colorSpace = previewColorSpace(for: source)
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            context.interpolationQuality = .low
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let preview = context.makeImage()
            DispatchQueue.main.async { completion(preview) }
        }
    }

    private static func previewColorSpace(for source: CGImage) -> CGColorSpace {
        guard let sourceColorSpace = source.colorSpace,
              sourceColorSpace.model == .rgb
        else {
            return CGColorSpaceCreateDeviceRGB()
        }

        guard CGColorSpaceUsesExtendedRange(sourceColorSpace) else {
            return sourceColorSpace
        }

        if sourceColorSpace.name == CGColorSpace.extendedDisplayP3 ||
           sourceColorSpace.name == CGColorSpace.extendedLinearDisplayP3 {
            return CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        }
        return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }
}

@MainActor
final class PinContentView: NSView {
    var image: NSImage? {
        didSet {
            prepareInteractivePreview(for: image)
            zoomScale = 1.0
            panOffset = .zero
            needsDisplay = true
            needsLayout = true
            updateImageInteractionGeometry()
        }
    }
    weak var pinWindow: PinWindow?

    private let baseImageSize: NSSize
    private let toolbar = PinToolbarView()
    private let navigator = PinNavigatorView()
    private var zoomScale: CGFloat = 1.0 {
        didSet {
            toolbar.zoomScale = zoomScale
            updateNavigatorViewport()
            if !canShowNavigator {
                hideNavigator(animated: true)
            }
            needsDisplay = true
        }
    }
    private var panOffset: NSPoint = .zero {
        didSet {
            updateNavigatorViewport()
            needsDisplay = true
        }
    }
    private var panStartPoint: NSPoint?
    private var panStartOffset: NSPoint = .zero
    private var interactivePreviewImage: NSImage?
    private var interactivePreviewGeneration = UUID()
    private var interactiveZoomEndTimer: Timer?
    private var viewportAnimationTimer: Timer?
    private var viewportAnimationGeneration = UUID()
    private var viewportAnimationTargetGeometry: PinViewportGeometry?
    private var toolbarHostResizeGeneration = UUID()
    private var isToolbarHostResizePending = false
    private var isToolbarHostResizeReady = false
    private var interactiveZoomStartScale: CGFloat?
    private var interactiveZoomStartUsesExpanded: Bool?
    private var interactiveZoomNeedsViewportAnimation = false
    private var isZoomingInteractively = false {
        didSet {
            guard isZoomingInteractively != oldValue else { return }
            needsDisplay = true
        }
    }
    private var isViewportAnimating = false {
        didSet {
            guard isViewportAnimating != oldValue else { return }
            needsDisplay = true
        }
    }
    private var usesLowResolutionPreview: Bool {
        isZoomingInteractively || isViewportAnimating
    }
    private var imageTrackingArea: NSTrackingArea?
    private var isToolbarVisible = false
    private var isNavigatorVisible = false
    private var isNavigatorFrameValid = false
    private var isNavigatorSuppressedUntilMouseExit = false
    private var wasMouseInNavigatorActivationRegion = false
    private var isMouseInNavigatorRegion = false
    private var lastNavigatorPointerPoint: NSPoint?
    private var navigatorNavigationBlockedUntil: Date?
    private var navigatorIdleTimer: Timer?
    private var navigatorEntryTimer: Timer?
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        baseImageSize = frame.size
        super.init(frame: frame)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            interactiveZoomEndTimer?.invalidate()
            viewportAnimationTimer?.invalidate()
            navigatorIdleTimer?.invalidate()
            navigatorEntryTimer?.invalidate()
        }
    }

    private func setupToolbar() {
        toolbar.alphaValue = 0
        toolbar.isHidden = true
        navigator.alphaValue = 0
        navigator.isHidden = true

        toolbar.onEdit = { [weak self] in
            self?.editPinnedImage()
        }
        toolbar.onMoveMouseDown = { [weak self] event in
            guard self?.usesLowResolutionPreview == false else { return }
            self?.pinWindow?.performDrag(with: event)
        }
        toolbar.onZoomOut = { [weak self] in
            self?.adjustZoom(by: -PinZoom.buttonStep)
        }
        toolbar.onZoomIn = { [weak self] in
            self?.adjustZoom(by: PinZoom.buttonStep)
        }
        toolbar.onResetZoom = { [weak self] in
            self?.resetZoomTo100Percent()
        }
        toolbar.onClose = { [weak self] in
            self?.pinWindow?.dismiss()
        }
        navigator.onFocusChanged = { [weak self] unitPoint in
            self?.focusImage(at: unitPoint)
        }
        navigator.onPointerActivity = { [weak self] point in
            self?.registerNavigatorPointerActivity(at: point) == true
        }
        navigator.onPointerExited = { [weak self] in
            self?.handleNavigatorPointerExit()
        }
        addSubview(navigator)
        addSubview(toolbar)
    }

    private func editPinnedImage() {
        guard let image,
              let pinWindow,
              let appDelegate = NSApp.delegate as? AppDelegate
        else {
            return
        }

        let imageForEditing = image.copy() as? NSImage ?? image
        appDelegate.handlePinnedImageEditRequest(imageForEditing) {
            pinWindow.dismiss()
        }
    }

    private func prepareInteractivePreview(for image: NSImage?) {
        let generation = UUID()
        interactivePreviewGeneration = generation
        interactivePreviewImage = nil
        navigator.image = image

        guard let image,
              let source = image.cgImagePreservingBacking()
        else { return }

        let logicalSize = image.size
        PinInteractivePreviewRenderer.makePreview(from: source) { [weak self] preview in
            guard let self,
                  self.interactivePreviewGeneration == generation,
                  let preview
            else { return }

            let previewImage = NSImage(cgImage: preview, size: logicalSize)
            self.interactivePreviewImage = previewImage
            self.navigator.image = previewImage
            if self.usesLowResolutionPreview {
                self.needsDisplay = true
            }
        }
    }

    private func beginInteractiveZoom() {
        interactiveZoomEndTimer?.invalidate()
        interactiveZoomEndTimer = nil
        guard !isZoomingInteractively else { return }

        interactiveZoomStartScale = zoomScale
        interactiveZoomStartUsesExpanded = PinZoom.usesExpandedViewport(at: zoomScale)
        isZoomingInteractively = true
        interactiveZoomNeedsViewportAnimation = cancelViewportAnimation()
    }

    private func scheduleInteractiveZoomEnd() {
        interactiveZoomEndTimer?.invalidate()
        let timer = Timer(timeInterval: PinZoom.interactivePreviewEndDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finishInteractiveZoom()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        interactiveZoomEndTimer = timer
    }

    private func finishInteractiveZoom() {
        interactiveZoomEndTimer?.invalidate()
        interactiveZoomEndTimer = nil
        guard isZoomingInteractively else { return }

        let finalUsesExpanded = PinZoom.usesExpandedViewport(at: zoomScale)
        let shouldAnimateCollapsedZoomIn = shouldAnimateViewportForCollapsedZoomIn(
            from: interactiveZoomStartScale,
            to: zoomScale
        )
        interactiveZoomStartScale = nil
        let shouldAnimateViewport = interactiveZoomNeedsViewportAnimation ||
            interactiveZoomStartUsesExpanded.map { $0 != finalUsesExpanded } == true ||
            shouldAnimateCollapsedZoomIn
        interactiveZoomStartUsesExpanded = nil
        interactiveZoomNeedsViewportAnimation = false

        let didStartAnimation = commitInteractiveWindowSize(animated: shouldAnimateViewport)
        isZoomingInteractively = false
        guard !didStartAnimation else { return }

        finishViewportUpdate()
    }

    private func finishViewportUpdate() {
        reconcileToolbarHostSizeIfNeeded()
        updateImageInteractionGeometry()
        needsDisplay = true
        window?.displayIfNeeded()
    }

    /// Keeps the window surface fixed while events are arriving, then applies
    /// the final viewport once. The target size always wins; image position is
    /// preserved as far as the display and pan limits allow.
    @discardableResult
    private func commitInteractiveWindowSize(animated: Bool) -> Bool {
        guard window != nil else {
            let targetSize = windowSize(for: zoomScale)
            setFrameSize(targetSize)
            panOffset = clampedPanOffset(
                panOffset,
                scale: zoomScale,
                viewportSize: targetSize,
                allowsEmptyViewportSpace: allowsToolbarHostPadding(at: zoomScale)
            )
            return false
        }

        guard let geometry = targetViewportGeometry(for: zoomScale) else { return false }
        return applyViewportGeometry(geometry, animated: animated)
    }

    private func targetViewportGeometry(
        for scale: CGFloat,
        on preferredScreen: NSScreen? = nil,
        allowsEmptyViewportSpace: Bool? = nil
    ) -> PinViewportGeometry? {
        guard let window else { return nil }

        let targetScreen = preferredScreen ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
        let targetSize = windowSize(for: scale, on: targetScreen)
        let shouldAllowEmptyViewportSpace = allowsEmptyViewportSpace ??
            allowsToolbarHostPadding(at: scale)
        return PinZoom.viewportGeometry(
            currentFrame: window.frame,
            currentPanOffset: panOffset,
            targetSize: targetSize,
            baseImageSize: baseImageSize,
            scale: scale,
            constraintFrame: targetScreen.map { windowConstraintFrame(for: scale, on: $0) },
            allowsEmptyViewportSpace: shouldAllowEmptyViewportSpace
        )
    }

    @discardableResult
    private func applyViewportGeometry(_ geometry: PinViewportGeometry, animated: Bool) -> Bool {
        guard let window else { return false }

        let currentFrame = window.frame
        let frameDidChange = abs(geometry.frame.width - currentFrame.width) > 0.5 ||
            abs(geometry.frame.height - currentFrame.height) > 0.5 ||
            abs(geometry.frame.minX - currentFrame.minX) > 0.5 ||
            abs(geometry.frame.minY - currentFrame.minY) > 0.5
        let panDidChange = abs(geometry.panOffset.x - panOffset.x) > 0.5 ||
            abs(geometry.panOffset.y - panOffset.y) > 0.5

        guard frameDidChange || panDidChange else {
            window.setFrame(geometry.frame, display: false, animate: false)
            panOffset = geometry.panOffset
            return false
        }
        if animated,
           frameDidChange,
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            startViewportAnimation(to: geometry, in: window)
            return true
        }

        window.setFrame(geometry.frame, display: false, animate: false)
        panOffset = geometry.panOffset
        return false
    }

    private func startViewportAnimation(to geometry: PinViewportGeometry, in window: NSWindow) {
        viewportAnimationTimer?.invalidate()
        let generation = UUID()
        viewportAnimationGeneration = generation
        viewportAnimationTargetGeometry = geometry

        let startFrame = window.frame
        let startPanOffset = panOffset
        let startTime = ProcessInfo.processInfo.systemUptime
        isViewportAnimating = true

        let timer = Timer(
            timeInterval: PinZoom.viewportAnimationFrameInterval,
            repeats: true
        ) { [weak self, weak window] timer in
            let shouldInvalidate = MainActor.assumeIsolated {
                guard let self,
                      let window,
                      self.viewportAnimationGeneration == generation
                else {
                    return true
                }

                let elapsed = ProcessInfo.processInfo.systemUptime - startTime
                let progress = min(max(elapsed / PinZoom.viewportTransitionDuration, 0), 1)
                if progress >= 1 {
                    self.viewportAnimationTimer = nil
                    self.viewportAnimationTargetGeometry = nil
                    self.panOffset = geometry.panOffset
                    window.setFrame(geometry.frame, display: false, animate: false)
                    self.isViewportAnimating = false
                    self.finishViewportUpdate()
                    return true
                }

                let easedProgress = progress * progress * (3 - 2 * progress)
                self.panOffset = Self.interpolate(
                    from: startPanOffset,
                    to: geometry.panOffset,
                    progress: easedProgress
                )
                window.setFrame(
                    Self.interpolate(
                        from: startFrame,
                        to: geometry.frame,
                        progress: easedProgress
                    ),
                    display: false,
                    animate: false
                )
                self.needsLayout = true
                self.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
                return false
            }
            if shouldInvalidate {
                timer.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        viewportAnimationTimer = timer
    }

    @discardableResult
    private func cancelViewportAnimation() -> Bool {
        guard let viewportAnimationTimer else { return false }

        viewportAnimationTimer.invalidate()
        self.viewportAnimationTimer = nil
        viewportAnimationGeneration = UUID()
        viewportAnimationTargetGeometry = nil
        isViewportAnimating = false
        return true
    }

    private func finishViewportAnimationImmediately() {
        guard let geometry = viewportAnimationTargetGeometry,
              let window
        else {
            cancelViewportAnimation()
            return
        }

        viewportAnimationTimer?.invalidate()
        viewportAnimationTimer = nil
        viewportAnimationGeneration = UUID()
        viewportAnimationTargetGeometry = nil
        panOffset = geometry.panOffset
        window.setFrame(geometry.frame, display: false, animate: false)
        isViewportAnimating = false
        finishViewportUpdate()
    }

    private static func interpolate(
        from start: CGFloat,
        to end: CGFloat,
        progress: Double
    ) -> CGFloat {
        start + (end - start) * CGFloat(progress)
    }

    private static func interpolate(
        from start: NSPoint,
        to end: NSPoint,
        progress: Double
    ) -> NSPoint {
        NSPoint(
            x: interpolate(from: start.x, to: end.x, progress: progress),
            y: interpolate(from: start.y, to: end.y, progress: progress)
        )
    }

    private static func interpolate(
        from start: NSRect,
        to end: NSRect,
        progress: Double
    ) -> NSRect {
        NSRect(
            x: interpolate(from: start.minX, to: end.minX, progress: progress),
            y: interpolate(from: start.minY, to: end.minY, progress: progress),
            width: interpolate(from: start.width, to: end.width, progress: progress),
            height: interpolate(from: start.height, to: end.height, progress: progress)
        )
    }

    override func layout() {
        super.layout()
        updateToolbarFrame()
        updateNavigatorFrame()
        updateNavigatorViewport()
        updateImageTrackingArea()
        refreshToolbarVisibility(animated: false)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateImageTrackingArea()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshToolbarVisibility(animated: false)
    }

    private func updateToolbarFrame() {
        let toolbarWidth = min(PinToolbarView.preferredWidth, max(PinToolbarView.minimumWidth, bounds.width - 12))
        let toolbarHeight = PinToolbarView.preferredHeight
        let imageFrame = imageRect()
        let margin: CGFloat = 6
        let proposedX = imageFrame.minX + PinZoom.toolbarInset
        let proposedY = imageFrame.maxY - toolbarHeight - PinZoom.toolbarInset
        let maxX = max(margin, bounds.width - toolbarWidth - margin)
        let maxY = max(margin, bounds.height - toolbarHeight - margin)

        toolbar.frame = NSRect(
            x: min(max(proposedX, margin), maxX),
            y: min(max(proposedY, margin), maxY),
            width: toolbarWidth,
            height: toolbarHeight
        )
    }

    private func updateNavigatorFrame() {
        let size = navigatorSize()
        guard size.width > 0, size.height > 0 else {
            isNavigatorFrameValid = false
            hideNavigator(animated: true)
            return
        }

        isNavigatorFrameValid = true
        let margin: CGFloat = 6
        let proposedX = PinZoom.toolbarInset
        let proposedY = bounds.height - PinToolbarView.preferredHeight -
            PinZoom.toolbarInset - PinZoom.navigatorGap - size.height
        let maxX = max(margin, bounds.width - size.width - margin)
        let maxY = max(margin, bounds.height - size.height - margin)

        navigator.frame = NSRect(
            x: min(max(proposedX, margin), maxX),
            y: min(max(proposedY, margin), maxY),
            width: size.width,
            height: size.height
        )
    }

    private func navigatorSize() -> NSSize {
        guard baseImageSize.width > 0, baseImageSize.height > 0 else { return .zero }

        let margin: CGFloat = 6
        let aspect = baseImageSize.width / baseImageSize.height
        let widthLimit = max(48, min(PinNavigatorView.maxWidth, bounds.width - margin * 2))
        let availableHeightBelowToolbar = toolbar.frame.minY - PinZoom.navigatorGap - margin
        let heightLimit = max(36, min(PinNavigatorView.maxHeight, availableHeightBelowToolbar))

        var width = min(widthLimit, max(PinNavigatorView.minWidth, bounds.width * 0.18))
        var height = width / aspect
        if height > heightLimit {
            height = heightLimit
            width = height * aspect
        }
        if width > widthLimit {
            width = widthLimit
            height = width / aspect
        }

        guard width >= 48, height >= 36 else { return .zero }
        return NSSize(width: floor(width), height: floor(height))
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 7: // X — close and clear the originating source.
            pinWindow?.dismissClearingSource()
        case 53: // Esc — close only.
            pinWindow?.dismiss()
        default:
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard !usesLowResolutionPreview else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard !toolbarInteractiveRect().contains(point) else { return }
        guard !navigatorInteractiveRect().contains(point) else { return }
        guard imageHoverRect().contains(point) else { return }

        if event.clickCount >= 2 {
            pinWindow?.dismiss()
            return
        }

        if canPanImage {
            panStartPoint = point
            panStartOffset = panOffset
            return
        }

        pinWindow?.performDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard canPanImage, let start = panStartPoint else { return }

        let point = convert(event.locationInWindow, from: nil)
        let proposed = NSPoint(
            x: panStartOffset.x + point.x - start.x,
            y: panStartOffset.y + point.y - start.y
        )
        panOffset = clampedPanOffset(
            proposed,
            scale: zoomScale,
            allowsEmptyViewportSpace: allowsEmptyViewportSpaceWhileUpdating(at: zoomScale)
        )
        updateImageInteractionGeometry()
    }

    override func mouseUp(with event: NSEvent) {
        panStartPoint = nil
    }

    override func scrollWheel(with event: NSEvent) {
        let shouldFinish = shouldFinishInteractiveZoom(for: event, includesMomentum: true)
        let delta = event.scrollingDeltaY
        guard delta != 0 else {
            if shouldFinish {
                finishInteractiveZoom()
            } else if isZoomingInteractively, event.phase.contains(.ended) {
                scheduleInteractiveZoomEnd()
            } else if isZoomingInteractively,
                      event.phase.contains(.stationary) ||
                      event.momentumPhase.contains(.began) ||
                      event.momentumPhase.contains(.changed) {
                beginInteractiveZoom()
            }
            super.scrollWheel(with: event)
            return
        }

        let normalizedDelta = event.hasPreciseScrollingDeltas ? delta : delta * 10
        let factor = pow(1 + PinZoom.wheelSensitivity, normalizedDelta)
        let proposedScale = zoomScale * factor
        if zoomScaleWillChange(to: proposedScale) {
            beginInteractiveZoom()
            zoomAtEventLocation(proposedScale, event: event)
            if event.phase.isEmpty, event.momentumPhase.isEmpty {
                scheduleInteractiveZoomEnd()
            } else if event.phase.contains(.ended) {
                scheduleInteractiveZoomEnd()
            }
        } else if isZoomingInteractively, event.phase.contains(.stationary) {
            beginInteractiveZoom()
        }
        if shouldFinish {
            finishInteractiveZoom()
        }
    }

    override func magnify(with event: NSEvent) {
        let shouldFinish = shouldFinishInteractiveZoom(for: event, includesMomentum: false)
        let factor = max(0.1, 1 + event.magnification)
        let proposedScale = zoomScale * factor
        if zoomScaleWillChange(to: proposedScale) {
            beginInteractiveZoom()
            zoomAtEventLocation(proposedScale, event: event)
            if event.phase.isEmpty {
                scheduleInteractiveZoomEnd()
            }
        } else if isZoomingInteractively, event.phase.contains(.stationary) {
            beginInteractiveZoom()
        }
        if shouldFinish {
            finishInteractiveZoom()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        let context = NSGraphicsContext.current
        let oldInterpolation = context?.imageInterpolation
        context?.imageInterpolation = usesLowResolutionPreview ? .low : .high
        let displayImage = usesLowResolutionPreview ? (interactivePreviewImage ?? image) : image
        displayImage.draw(in: imageRect())
        if let oldInterpolation {
            context?.imageInterpolation = oldInterpolation
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateToolbarVisibility(for: event, animated: true)
        updateNavigatorActivation(for: event, animated: true)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateToolbarVisibility(for: event, animated: true)
        updateNavigatorActivation(for: event, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateToolbarVisibility(for: event, animated: true)
        updateNavigatorActivation(for: event, animated: true)
    }

    private func adjustZoom(by delta: CGFloat) {
        setZoom(zoomScale + delta)
    }

    private func resetZoomTo100Percent() {
        guard zoomScale != 1 || isZoomingInteractively || isViewportAnimating else { return }

        interactiveZoomEndTimer?.invalidate()
        interactiveZoomEndTimer = nil
        let wasExpanded = PinZoom.usesExpandedViewport(at: zoomScale)
        let shouldAnimateCollapsedZoomIn = shouldAnimateViewportForCollapsedZoomIn(
            from: zoomScale,
            to: 1
        )
        let interruptedViewportAnimation = cancelViewportAnimation()
        let shouldAnimateViewport = wasExpanded ||
            interruptedViewportAnimation ||
            shouldAnimateCollapsedZoomIn
        interactiveZoomStartScale = nil
        interactiveZoomStartUsesExpanded = nil
        interactiveZoomNeedsViewportAnimation = false
        let currentFrame = window?.frame
        let currentAnchorFrame: NSRect?
        if let currentFrame,
           allowsToolbarHostPadding(at: zoomScale) {
            let visibleImageRect = imageHoverRect()
            currentAnchorFrame = visibleImageRect.isEmpty ? currentFrame : visibleImageRect.offsetBy(
                dx: currentFrame.minX,
                dy: currentFrame.minY
            )
        } else {
            currentAnchorFrame = currentFrame
        }
        isZoomingInteractively = false
        zoomScale = 1
        panOffset = .zero

        if let window,
           let currentAnchorFrame {
            let targetScreen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
            let resetSize = windowSize(for: 1, on: targetScreen)
            let resetImageSize = scaledImageSize(for: 1)
            let imageScreenMinX = currentAnchorFrame.midX - resetImageSize.width / 2
            let imageScreenMaxY = currentAnchorFrame.maxY
            var resetFrame = NSRect(
                x: imageScreenMinX,
                y: imageScreenMaxY - resetSize.height,
                width: resetSize.width,
                height: resetSize.height
            )
            if let targetScreen {
                resetFrame = clampedWindowFrame(
                    resetFrame,
                    to: windowConstraintFrame(for: 1, on: targetScreen)
                )
            }
            let resetPanOffset = clampedPanOffset(
                NSPoint(
                    x: imageScreenMinX - resetFrame.minX,
                    y: imageScreenMaxY - resetFrame.maxY
                ),
                scale: 1,
                viewportSize: resetSize,
                allowsEmptyViewportSpace: isToolbarVisible
            )
            let didStartAnimation = applyViewportGeometry(
                PinViewportGeometry(frame: resetFrame, panOffset: resetPanOffset),
                animated: shouldAnimateViewport
            )
            guard !didStartAnimation else { return }
        } else {
            setFrameSize(windowSize(for: 1))
            panOffset = .zero
        }

        finishViewportUpdate()
    }

    private func shouldAnimateViewportForCollapsedZoomIn(
        from startScale: CGFloat?,
        to endScale: CGFloat
    ) -> Bool {
        guard let startScale else { return false }
        return endScale > startScale + 0.001 &&
            !PinZoom.usesExpandedViewport(at: endScale)
    }

    private func zoomScaleWillChange(to proposedScale: CGFloat) -> Bool {
        let clampedScale = PinZoom.clampedScale(proposedScale)
        return abs(clampedScale - zoomScale) > 0.001
    }

    private func shouldFinishInteractiveZoom(
        for event: NSEvent,
        includesMomentum: Bool
    ) -> Bool {
        let gestureEnded = event.phase.contains(.ended) || event.phase.contains(.cancelled)
        guard includesMomentum else { return gestureEnded }

        let momentumEnded = event.momentumPhase.contains(.ended) ||
            event.momentumPhase.contains(.cancelled)
        return momentumEnded || event.phase.contains(.cancelled)
    }

    private func zoomAtEventLocation(_ proposedScale: CGFloat, event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let unitPoint = imageUnitPoint(for: point) else {
            setZoom(proposedScale)
            return
        }

        setZoom(proposedScale, focusing: unitPoint, at: point)
    }

    private func setZoom(
        _ proposedScale: CGFloat,
        focusing unitPoint: NSPoint? = nil,
        at focusPoint: NSPoint? = nil
    ) {
        let newScale = PinZoom.clampedScale(proposedScale)
        let didChangeScale = abs(newScale - zoomScale) > 0.001
        guard didChangeScale || unitPoint != nil else { return }

        let previousScale = zoomScale
        let previousUsesExpanded = PinZoom.usesExpandedViewport(at: zoomScale)
        let interruptedViewportAnimation = didChangeScale && !isZoomingInteractively
            ? cancelViewportAnimation()
            : false
        let shouldRevealNavigator = didChangeScale &&
            zoomScale < PinZoom.navigatorScaleThreshold &&
            newScale >= PinZoom.navigatorScaleThreshold
        if didChangeScale {
            zoomScale = newScale
        }
        if didChangeScale, !isZoomingInteractively, unitPoint == nil {
            panOffset = clampedPanOffset(
                panOffset,
                scale: newScale,
                allowsEmptyViewportSpace: allowsToolbarHostPadding(at: newScale)
            )
        }
        let shouldAnimateViewport = didChangeScale &&
            !isZoomingInteractively &&
            unitPoint == nil &&
            (interruptedViewportAnimation ||
                previousUsesExpanded != PinZoom.usesExpandedViewport(at: newScale) ||
                shouldAnimateViewportForCollapsedZoomIn(
                    from: previousScale,
                    to: newScale
                ))
        let didStartViewportAnimation = shouldAnimateViewport &&
            targetViewportGeometry(for: newScale).map {
                applyViewportGeometry($0, animated: true)
            } == true
        let focusPointAdjustment = didChangeScale &&
            !isZoomingInteractively &&
            !didStartViewportAnimation
            ? resizeWindowKeepingTopLeft(for: newScale)
            : .zero
        if didStartViewportAnimation {
            // Frame and pan animate together so the image anchor stays stable.
        } else if let unitPoint, newScale > 1 || isZoomingInteractively {
            panOffset = focusedPanOffset(
                on: unitPoint,
                scale: newScale,
                at: adjustedFocusPoint(
                    focusPoint,
                    by: focusPointAdjustment
                )
            )
        } else {
            panOffset = clampedPanOffset(
                panOffset,
                scale: newScale,
                allowsEmptyViewportSpace: allowsEmptyViewportSpaceWhileUpdating(at: newScale)
            )
        }
        updateImageInteractionGeometry()
        if shouldRevealNavigator {
            isNavigatorSuppressedUntilMouseExit = false
            showNavigator(animated: true)
            updateNavigatorActivationAtCurrentMouse(animated: true)
        }
    }

    private func focusImage(at unitPoint: NSPoint) {
        finishViewportAnimationImmediately()
        guard isNavigatorVisible,
              !isNavigatorSuppressedUntilMouseExit,
              !isNavigatorNavigationBlocked,
              zoomScale >= PinZoom.navigatorScaleThreshold
        else { return }

        let imageSize = scaledImageSize(for: zoomScale)
        panOffset = focusedPanOffset(on: unitPoint, scale: zoomScale, imageSize: imageSize)
        updateImageInteractionGeometry()
    }

    private func imageUnitPoint(for point: NSPoint) -> NSPoint? {
        let frame = imageRect()
        guard frame.width > 0,
              frame.height > 0,
              frame.contains(point)
        else { return nil }

        return NSPoint(
            x: min(max((point.x - frame.minX) / frame.width, 0), 1),
            y: min(max((point.y - frame.minY) / frame.height, 0), 1)
        )
    }

    private func focusedPanOffset(
        on unitPoint: NSPoint,
        scale: CGFloat,
        imageSize: NSSize? = nil,
        at focusPoint: NSPoint? = nil
    ) -> NSPoint {
        if let imageSize {
            let targetPoint = focusPoint ?? NSPoint(x: bounds.midX, y: bounds.midY)
            let imagePoint = NSPoint(
                x: min(max(unitPoint.x, 0), 1) * imageSize.width,
                y: min(max(unitPoint.y, 0), 1) * imageSize.height
            )
            return clampedPanOffset(
                NSPoint(
                    x: targetPoint.x - imagePoint.x,
                    y: targetPoint.y - imagePoint.y - bounds.height + imageSize.height
                ),
                scale: scale,
                allowsEmptyViewportSpace: allowsEmptyViewportSpaceWhileUpdating(at: scale)
            )
        }
        return PinZoom.focusedPanOffset(
            on: unitPoint,
            scale: scale,
            baseImageSize: baseImageSize,
            viewportSize: bounds.size,
            focusPoint: focusPoint,
            allowsEmptyViewportSpace: allowsEmptyViewportSpaceWhileUpdating(at: scale)
        )
    }

    private func adjustedFocusPoint(
        _ point: NSPoint?,
        by windowOriginDelta: NSPoint
    ) -> NSPoint? {
        PinZoom.adjustedFocusPoint(point, by: windowOriginDelta)
    }

    private func imageRect() -> NSRect {
        let size = scaledImageSize(for: zoomScale)
        return NSRect(
            x: panOffset.x,
            y: bounds.height - size.height + panOffset.y,
            width: size.width,
            height: size.height
        )
    }

    private func scaledImageSize(for scale: CGFloat) -> NSSize {
        PinZoom.scaledImageSize(baseImageSize: baseImageSize, scale: scale)
    }

    private func windowSize(for scale: CGFloat, on preferredScreen: NSScreen? = nil) -> NSSize {
        let screen = preferredScreen ?? window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        return PinZoom.windowSize(
            baseImageSize: baseImageSize,
            scale: scale,
            screenFrame: screen?.frame,
            visibleFrame: screen?.visibleFrame,
            toolbarVisible: isToolbarVisible,
            toolbarMinimumSize: NSSize(
                width: PinToolbarView.minimumWidth + 12,
                height: PinToolbarView.preferredHeight + PinZoom.toolbarInset * 2
            )
        )
    }

    private func windowConstraintFrame(for scale: CGFloat, on screen: NSScreen) -> NSRect {
        PinZoom.windowConstraintFrame(for: scale, visibleFrame: screen.visibleFrame)
    }

    private func clampedWindowFrame(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        PinZoom.clampedWindowFrame(frame, to: visibleFrame)
    }

    private func clampedPanOffset(
        _ offset: NSPoint,
        scale: CGFloat,
        viewportSize: NSSize? = nil,
        allowsEmptyViewportSpace: Bool = false
    ) -> NSPoint {
        PinZoom.clampedPanOffset(
            offset,
            baseImageSize: baseImageSize,
            scale: scale,
            viewportSize: viewportSize ?? bounds.size,
            allowsEmptyViewportSpace: allowsEmptyViewportSpace
        )
    }

    private func allowsToolbarHostPadding(at scale: CGFloat) -> Bool {
        (isToolbarVisible || isToolbarHostResizePending) &&
            !PinZoom.usesExpandedViewport(at: scale)
    }

    private func allowsEmptyViewportSpaceWhileUpdating(at scale: CGFloat) -> Bool {
        isZoomingInteractively || allowsToolbarHostPadding(at: scale)
    }

    private var canPanImage: Bool {
        let imageSize = scaledImageSize(for: zoomScale)
        return imageSize.width > bounds.width + 0.5 ||
            imageSize.height > bounds.height + 0.5
    }

    /// Resizes from the top-left and returns the local-coordinate adjustment
    /// needed to keep a screen-space zoom focus stable.
    @discardableResult
    private func resizeWindowKeepingTopLeft(for scale: CGFloat) -> NSPoint {
        guard let window else {
            let targetSize = windowSize(for: scale)
            setFrameSize(targetSize)
            return .zero
        }

        if allowsToolbarHostPadding(at: scale),
           let geometry = targetViewportGeometry(
               for: scale,
               allowsEmptyViewportSpace: isToolbarVisible
           ) {
            let currentFrame = window.frame
            applyViewportGeometry(geometry, animated: false)
            return NSPoint(
                x: currentFrame.minX - geometry.frame.minX,
                y: currentFrame.minY - geometry.frame.minY
            )
        }

        let targetSize = windowSize(for: scale, on: window.screen)
        let currentFrame = window.frame
        var targetFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )
        if let screen = window.screen {
            targetFrame = clampedWindowFrame(
                targetFrame,
                to: windowConstraintFrame(for: scale, on: screen)
            )
        }

        guard abs(targetFrame.width - currentFrame.width) > 0.5 ||
              abs(targetFrame.height - currentFrame.height) > 0.5
        else { return .zero }

        window.setFrame(targetFrame, display: !isZoomingInteractively, animate: false)
        return NSPoint(
            x: currentFrame.minX - targetFrame.minX,
            y: currentFrame.minY - targetFrame.minY
        )
    }

    private func imageHoverRect() -> NSRect {
        guard image != nil else { return .zero }
        let rect = imageRect().intersection(bounds)
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return .zero }
        return rect
    }

    private func toolbarTrackingRect() -> NSRect {
        let imageRect = imageHoverRect()
        guard imageRect.width > 0, imageRect.height > 0 else { return .zero }
        guard toolbar.frame.width > 0, toolbar.frame.height > 0 else { return imageRect }
        return imageRect.union(toolbarRetentionRect())
    }

    private func toolbarRetentionRect() -> NSRect {
        toolbar.frame
            .insetBy(dx: -PinZoom.toolbarInset, dy: -PinZoom.toolbarInset)
            .intersection(bounds)
    }

    private func shouldShowToolbar(at point: NSPoint) -> Bool {
        imageHoverRect().contains(point) ||
            (isToolbarVisible && toolbarRetentionRect().contains(point))
    }

    private func updateImageInteractionGeometry() {
        updateToolbarFrame()
        updateNavigatorFrame()
        updateNavigatorViewport()
        updateImageTrackingArea()
        refreshToolbarVisibility(animated: true)
    }

    private func updateNavigatorViewport() {
        navigator.viewportRect = normalizedVisibleImageRect()
    }

    private var canShowNavigator: Bool {
        zoomScale >= PinZoom.navigatorScaleThreshold &&
            image != nil &&
            isNavigatorFrameValid &&
            navigator.frame.width > 0 &&
            navigator.frame.height > 0
    }

    private func normalizedVisibleImageRect() -> NSRect {
        let imageFrame = imageRect()
        let visible = imageFrame.intersection(bounds)
        guard !visible.isNull,
              imageFrame.width > 0,
              imageFrame.height > 0
        else { return .zero }

        return NSRect(
            x: min(max((visible.minX - imageFrame.minX) / imageFrame.width, 0), 1),
            y: min(max((visible.minY - imageFrame.minY) / imageFrame.height, 0), 1),
            width: min(max(visible.width / imageFrame.width, 0), 1),
            height: min(max(visible.height / imageFrame.height, 0), 1)
        )
    }

    private func navigatorInteractiveRect() -> NSRect {
        guard isNavigatorVisible,
              zoomScale >= PinZoom.navigatorScaleThreshold,
              navigator.frame.width > 0,
              navigator.frame.height > 0
        else { return .zero }
        return navigator.frame
    }

    private func toolbarInteractiveRect() -> NSRect {
        guard !toolbar.isHidden,
              toolbar.frame.width > 0,
              toolbar.frame.height > 0
        else { return .zero }
        return toolbar.frame
    }

    private func navigatorActivationRect() -> NSRect {
        guard canShowNavigator else { return .zero }
        return navigator.frame
    }

    private func updateImageTrackingArea() {
        if let imageTrackingArea {
            removeTrackingArea(imageTrackingArea)
            self.imageTrackingArea = nil
        }

        let rect = toolbarTrackingRect()
        guard rect.width > 0, rect.height > 0 else {
            setToolbarVisible(false, animated: false)
            return
        }

        let area = NSTrackingArea(
            rect: rect,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        imageTrackingArea = area
    }

    private func updateToolbarVisibility(for event: NSEvent, animated: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        setToolbarVisible(shouldShowToolbar(at: point), animated: animated)
    }

    private func updateNavigatorActivation(for event: NSEvent, animated: Bool) {
        updateNavigatorActivation(at: convert(event.locationInWindow, from: nil), animated: animated)
    }

    private func updateNavigatorActivationAtCurrentMouse(animated: Bool) {
        guard let window else { return }
        updateNavigatorActivation(at: convert(window.mouseLocationOutsideOfEventStream, from: nil), animated: animated)
    }

    private func currentMousePointInView() -> NSPoint? {
        guard let window else { return nil }
        return convert(window.mouseLocationOutsideOfEventStream, from: nil)
    }

    private var isCurrentMouseInsideNavigatorActivationRegion: Bool {
        guard canShowNavigator, let point = currentMousePointInView() else { return false }
        return navigatorActivationRect().contains(point)
    }

    private func updateNavigatorActivation(at point: NSPoint, animated: Bool) {
        guard canShowNavigator else {
            isNavigatorSuppressedUntilMouseExit = false
            lastNavigatorPointerPoint = nil
            wasMouseInNavigatorActivationRegion = false
            hideNavigator(animated: animated)
            return
        }

        let inside = navigatorActivationRect().contains(point)
        if !inside {
            isNavigatorSuppressedUntilMouseExit = false
            navigatorNavigationBlockedUntil = nil
            lastNavigatorPointerPoint = nil
        }
        defer { wasMouseInNavigatorActivationRegion = inside }

        if isNavigatorSuppressedUntilMouseExit {
            if !inside, wasMouseInNavigatorActivationRegion {
                handleNavigatorPointerExit()
            }
            return
        }

        if inside {
            if !wasMouseInNavigatorActivationRegion {
                showNavigator(animated: animated)
                beginNavigatorHover(at: point)
                return
            }
            guard isNavigatorVisible else { return }

            guard registerNavigatorPointerActivity(at: point) else { return }
            if let unitPoint = navigator.unitPoint(forPointInSuperview: point) {
                focusImage(at: unitPoint)
            }
        } else if wasMouseInNavigatorActivationRegion {
            handleNavigatorPointerExit()
        }
    }

    private func refreshToolbarVisibility(animated: Bool) {
        guard let window else {
            setToolbarVisible(false, animated: false)
            return
        }

        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        setToolbarVisible(shouldShowToolbar(at: point), animated: animated)
    }

    private func setToolbarVisible(_ visible: Bool, animated: Bool) {
        guard visible != isToolbarVisible else { return }
        isToolbarVisible = visible
        setFloatingControl(
            toolbar,
            visible: visible,
            animated: animated,
            shouldRemainVisible: { [weak self] in self?.isToolbarVisible == true }
        )
        scheduleWindowResizeForToolbarVisibility(visible, afterFade: animated && !visible)
    }

    private func scheduleWindowResizeForToolbarVisibility(
        _ visible: Bool,
        afterFade: Bool
    ) {
        guard !PinZoom.usesExpandedViewport(at: zoomScale) else { return }

        let generation = UUID()
        toolbarHostResizeGeneration = generation
        isToolbarHostResizePending = true
        isToolbarHostResizeReady = !afterFade
        let delay = afterFade ? PinZoom.toolbarAnimationDuration : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  self.toolbarHostResizeGeneration == generation,
                  self.isToolbarVisible == visible
            else { return }

            self.isToolbarHostResizeReady = true
            self.finishViewportUpdate()
        }
    }

    private func reconcileToolbarHostSizeIfNeeded() {
        guard isToolbarHostResizePending,
              isToolbarHostResizeReady,
              !usesLowResolutionPreview
        else { return }

        if PinZoom.usesExpandedViewport(at: zoomScale) {
            isToolbarHostResizePending = false
            isToolbarHostResizeReady = false
            return
        }

        guard let geometry = targetViewportGeometry(
            for: zoomScale,
            allowsEmptyViewportSpace: isToolbarVisible
        ) else { return }

        isToolbarHostResizePending = false
        isToolbarHostResizeReady = false
        applyViewportGeometry(geometry, animated: false)
    }

    private func showNavigator(animated _: Bool) {
        guard canShowNavigator else { return }
        navigatorEntryTimer?.invalidate()
        scheduleNavigatorEntryTimeout()
        guard !isNavigatorVisible else { return }

        isNavigatorVisible = true
        setFloatingControl(
            navigator,
            visible: true,
            animated: true,
            shouldRemainVisible: { [weak self] in self?.isNavigatorVisible == true }
        )
    }

    private func hideNavigator(animated _: Bool) {
        hideNavigator(animated: true, suppressUntilMouseExit: false)
    }

    private func hideNavigator(animated _: Bool, suppressUntilMouseExit: Bool) {
        navigatorIdleTimer?.invalidate()
        navigatorEntryTimer?.invalidate()
        isMouseInNavigatorRegion = false
        isNavigatorSuppressedUntilMouseExit = suppressUntilMouseExit
        navigatorNavigationBlockedUntil = nil
        lastNavigatorPointerPoint = nil
        wasMouseInNavigatorActivationRegion = suppressUntilMouseExit
        guard isNavigatorVisible || !navigator.isHidden else { return }

        isNavigatorVisible = false
        setFloatingControl(
            navigator,
            visible: false,
            animated: true,
            shouldRemainVisible: { [weak self] in self?.isNavigatorVisible == true }
        )
    }

    private func beginNavigatorHover(at point: NSPoint) {
        guard isNavigatorVisible else { return }
        isMouseInNavigatorRegion = true
        wasMouseInNavigatorActivationRegion = true
        navigatorNavigationBlockedUntil = Date().addingTimeInterval(PinZoom.navigatorActivationDelay)
        lastNavigatorPointerPoint = point
        navigatorEntryTimer?.invalidate()
        scheduleNavigatorIdleHide()
    }

    @discardableResult
    private func registerNavigatorPointerActivity(at point: NSPoint? = nil) -> Bool {
        guard isNavigatorVisible else { return false }
        isMouseInNavigatorRegion = true
        wasMouseInNavigatorActivationRegion = true
        navigatorEntryTimer?.invalidate()

        if let point {
            let didMove = navigatorPointerDidMove(to: point)
            guard didMove || navigatorIdleTimer == nil else { return false }
        }
        scheduleNavigatorIdleHide()
        return !isNavigatorNavigationBlocked
    }

    private func handleNavigatorPointerExit() {
        if isNavigatorSuppressedUntilMouseExit,
           isCurrentMouseInsideNavigatorActivationRegion {
            isMouseInNavigatorRegion = false
            navigatorIdleTimer?.invalidate()
            return
        }

        isMouseInNavigatorRegion = false
        isNavigatorSuppressedUntilMouseExit = false
        navigatorNavigationBlockedUntil = nil
        wasMouseInNavigatorActivationRegion = false
        lastNavigatorPointerPoint = nil
        navigatorIdleTimer?.invalidate()
        guard isNavigatorVisible else { return }
        scheduleNavigatorEntryTimeout()
    }

    private func navigatorPointerDidMove(to point: NSPoint) -> Bool {
        defer { lastNavigatorPointerPoint = point }
        guard let previous = lastNavigatorPointerPoint else { return true }

        return abs(previous.x - point.x) > 0.5 || abs(previous.y - point.y) > 0.5
    }

    private var isNavigatorNavigationBlocked: Bool {
        guard let blockedUntil = navigatorNavigationBlockedUntil else { return false }
        guard Date() < blockedUntil else {
            navigatorNavigationBlockedUntil = nil
            return false
        }
        return true
    }

    private func scheduleNavigatorIdleHide() {
        navigatorIdleTimer?.invalidate()
        let timer = Timer(timeInterval: PinZoom.navigatorIdleHideDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isMouseInNavigatorRegion else { return }
                self.hideNavigator(animated: true, suppressUntilMouseExit: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        navigatorIdleTimer = timer
    }

    private func scheduleNavigatorEntryTimeout() {
        navigatorEntryTimer?.invalidate()
        let timer = Timer(timeInterval: PinZoom.navigatorEntryTimeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isNavigatorVisible, !self.isMouseInNavigatorRegion else { return }
                self.hideNavigator(animated: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        navigatorEntryTimer = timer
    }

    private func setFloatingControl(
        _ view: NSView,
        visible: Bool,
        animated: Bool,
        shouldRemainVisible: @escaping @MainActor @Sendable () -> Bool
    ) {
        if visible {
            view.isHidden = false
        }

        let finish: @MainActor @Sendable () -> Void = { [weak view] in
            guard let view else { return }
            if !shouldRemainVisible() {
                view.isHidden = true
            }
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = PinZoom.toolbarAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                view.animator().alphaValue = visible ? 1 : 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    finish()
                }
            }
        } else {
            view.alphaValue = visible ? 1 : 0
            finish()
        }
    }
}
