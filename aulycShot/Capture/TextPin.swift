import AppKit

// MARK: - Text Pin

enum TextPinDebugLog {
    /// Serializes process-reset state and file writes through one lock.
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var didResetForProcess = false
    }

    private static let state = State()
    private static let directoryName = "aulycShot"
    private static let fileName = "text-pin-layout.log"
    private static let maxLogBytes = 4_000_000
    private static let trimToBytes = 2_500_000

    static var logURL: URL? {
        guard let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return logs
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func resetForProcessIfNeeded() {
        state.lock.lock()
        let shouldReset = !state.didResetForProcess
        if shouldReset {
            state.didResetForProcess = true
            if let url = logURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        state.lock.unlock()

        if shouldReset {
            log("session-start", metadata: [
                "logPath": logURL?.path ?? "nil",
                "system": DiagnosticLog.systemSnapshot(),
            ])
        }
    }

    static func log(
        _ event: String,
        metadata: [String: Any] = [:],
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard let data = makeLine(
            event: event,
            metadata: metadata,
            file: String(describing: file),
            line: line
        ).data(using: .utf8) else {
            return
        }

        state.lock.lock()
        defer { state.lock.unlock() }
        append(data)
    }

    static func textMetadata(_ text: String) -> [String: Any] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        let blankLines = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
        let lineStats = lines.prefix(20).enumerated().map { index, line in
            let trimmedCount = line.trimmingCharacters(in: .whitespaces).count
            let trailingSpaces = line.reversed().prefix { $0 == " " || $0 == "\t" }.count
            return "\(index):len\(line.count):trim\(trimmedCount):trail\(trailingSpaces)"
        }.joined(separator: ",")
        return [
            "textLength": normalized.count,
            "utf16Length": normalized.utf16.count,
            "lineCount": lines.count,
            "blankLineCount": blankLines,
            "leadingNewlineCount": prefixCount(in: normalized, matching: "\n"),
            "trailingNewlineCount": suffixCount(in: normalized, matching: "\n"),
            "trailingWhitespaceCount": normalized.reversed().prefix { $0.isWhitespace }.count,
            "lineStats": lineStats,
            "preview": preview(normalized),
        ]
    }

    static func rect(_ rect: NSRect) -> String {
        "x=\(number(rect.origin.x)),y=\(number(rect.origin.y)),w=\(number(rect.size.width)),h=\(number(rect.size.height))"
    }

    static func size(_ size: NSSize) -> String {
        "w=\(number(size.width)),h=\(number(size.height))"
    }

    static func point(_ point: NSPoint) -> String {
        "x=\(number(point.x)),y=\(number(point.y))"
    }

    static func insets(_ insets: NSSize) -> String {
        "w=\(number(insets.width)),h=\(number(insets.height))"
    }

    static func number(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private static func makeLine(
        event: String,
        metadata: [String: Any],
        file: String,
        line: UInt
    ) -> String {
        let timestamp = ISO8601DateFormatter.textPinDiagnostic.string(from: Date())
        var parts = [
            timestamp,
            "pid=\(ProcessInfo.processInfo.processIdentifier)",
            "thread=\(Thread.isMainThread ? "main" : "background")",
            "event=\(sanitize(event))",
        ]
        if !metadata.isEmpty {
            parts.append(contentsOf: metadata.keys.sorted().map { key in
                "\(sanitize(key))=\(sanitize(String(describing: metadata[key] ?? "")))"
            })
        }
        parts.append("source=\(sanitize(file)):\(line)")
        return parts.joined(separator: " ") + "\n"
    }

    private static func append(_ data: Data) {
        guard let url = logURL else { return }
        let directory = url.deletingLastPathComponent()
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: url.path) {
                _ = fm.createFile(atPath: url.path, contents: nil)
            }
            trimIfNeeded(at: url)
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            handle.write(data)
            handle.synchronizeFile()
            handle.closeFile()
        } catch {
            NSLog("[aulycShot] TextPinDebugLog append failed: \(error.localizedDescription)")
        }
    }

    private static func trimIfNeeded(at url: URL) {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard (values?.fileSize ?? 0) > maxLogBytes,
              let existing = try? Data(contentsOf: url),
              existing.count > trimToBytes else {
            return
        }

        var trimmed = Data()
        if let marker = "\n--- earlier text pin layout log lines truncated ---\n".data(using: .utf8) {
            trimmed.append(marker)
        }
        trimmed.append(existing.suffix(trimToBytes))
        try? trimmed.write(to: url, options: .atomic)
    }

    private static func preview(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return String(escaped.prefix(220))
    }

    private static func prefixCount(in text: String, matching character: Character) -> Int {
        text.prefix { $0 == character }.count
    }

    private static func suffixCount(in text: String, matching character: Character) -> Int {
        text.reversed().prefix { $0 == character }.count
    }

    private static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

private extension ISO8601DateFormatter {
    static var textPinDiagnostic: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        return formatter
    }
}

@MainActor
enum TextPinLayout {
    static let font = NSFont.systemFont(ofSize: 15, weight: .regular)
    private static let minWidth: CGFloat = 220
    private static let maxPreferredWidth: CGFloat = 560
    private static let minHeight: CGFloat = 72
    private static let contentInset: CGFloat = 17
    private static let padding = NSEdgeInsets(
        top: contentInset,
        left: contentInset,
        bottom: contentInset,
        right: contentInset
    )

    static func maxWidth(on screen: NSScreen) -> CGFloat {
        min(maxPreferredWidth, max(minWidth, screen.visibleFrame.width - 80))
    }

    static func size(for text: String, maxWidth: CGFloat) -> NSSize {
        let attributes = textAttributes()
        let normalized = normalizedText(text)
        let availableWidth = max(120, maxWidth - padding.left - padding.right)
        let measured = (normalized as NSString).boundingRect(
            with: NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let contentWidth = min(availableWidth, max(1, ceil(measured.width)))
        let width = ceil(min(maxWidth, max(minWidth, contentWidth + padding.left + padding.right)))
        let wrappedWidth = max(120, width - padding.left - padding.right)
        let wrapped = (normalized as NSString).boundingRect(
            with: NSSize(width: wrappedWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let textSystem = textSystemMeasurement(for: normalized, width: wrappedWidth)
        let textHeight = max(1, ceil(textSystem.usedRect.height))
        let height = ceil(max(minHeight, textHeight + padding.top + padding.bottom))
        let result = NSSize(width: width, height: height)
        var metadata = TextPinDebugLog.textMetadata(normalized)
        metadata["availableWidth"] = TextPinDebugLog.number(availableWidth)
        metadata["contentWidth"] = TextPinDebugLog.number(contentWidth)
        metadata["maxWidth"] = TextPinDebugLog.number(maxWidth)
        metadata["measuredRect"] = TextPinDebugLog.rect(measured)
        metadata["padding"] = "top=\(TextPinDebugLog.number(padding.top)),left=\(TextPinDebugLog.number(padding.left)),bottom=\(TextPinDebugLog.number(padding.bottom)),right=\(TextPinDebugLog.number(padding.right))"
        metadata["resultSize"] = TextPinDebugLog.size(result)
        metadata["textHeight"] = TextPinDebugLog.number(textHeight)
        metadata["textSystemExtraLineFragment"] = TextPinDebugLog.rect(textSystem.extraLineFragmentRect)
        metadata["textSystemGlyphRangeLength"] = textSystem.glyphRangeLength
        metadata["textSystemLineCount"] = textSystem.lineCount
        metadata["textSystemUsedRect"] = TextPinDebugLog.rect(textSystem.usedRect)
        metadata["wrappedRect"] = TextPinDebugLog.rect(wrapped)
        metadata["wrappedWidth"] = TextPinDebugLog.number(wrappedWidth)
        TextPinDebugLog.log("layout-size", metadata: metadata)
        return result
    }

    static func textFrame(in bounds: NSRect) -> NSRect {
        NSRect(
            x: bounds.minX + padding.left,
            y: bounds.minY + padding.bottom,
            width: max(1, bounds.width - padding.left - padding.right),
            height: max(1, bounds.height - padding.top - padding.bottom)
        )
    }

    static func normalizedText(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    static func previewText(_ text: String) -> String {
        var normalized = normalizedText(text)
        while normalized.last?.isWhitespace == true {
            normalized.removeLast()
        }
        return normalized
    }

    static func textAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 3
        return [
            .font: font,
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1),
            .paragraphStyle: paragraph,
        ]
    }

    static func configure(_ textView: NSTextView, text: String) {
        let attributed = NSAttributedString(
            string: normalizedText(text),
            attributes: textAttributes()
        )
        textView.textStorage?.setAttributedString(attributed)
        textView.font = font
        textView.textColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        textView.typingAttributes = textAttributes()
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: max(1, textView.bounds.width),
            height: CGFloat.greatestFiniteMagnitude
        )
        var metadata = TextPinDebugLog.textMetadata(textView.string)
        metadata["textViewBounds"] = TextPinDebugLog.rect(textView.bounds)
        metadata["textViewFrame"] = TextPinDebugLog.rect(textView.frame)
        metadata["textContainerSize"] = TextPinDebugLog.size(textView.textContainer?.containerSize ?? .zero)
        metadata["textContainerInset"] = TextPinDebugLog.insets(textView.textContainerInset)
        metadata["textContainerLineFragmentPadding"] = TextPinDebugLog.number(textView.textContainer?.lineFragmentPadding ?? -1)
        metadata["textContainerOrigin"] = TextPinDebugLog.point(textView.textContainerOrigin)
        TextPinDebugLog.log("layout-configure-text-view", metadata: metadata)
    }

    static func drawBackground(in bounds: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 10,
            yRadius: 10
        )
        NSColor(calibratedWhite: 0.98, alpha: 0.97).setFill()
        path.fill()
        NSColor(calibratedWhite: 0.12, alpha: 0.14).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    static func renderImage(for text: String, size: NSSize) -> NSImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        var metadata = TextPinDebugLog.textMetadata(text)
        metadata["renderSize"] = TextPinDebugLog.size(size)
        metadata["textFrame"] = TextPinDebugLog.rect(textFrame(in: NSRect(origin: .zero, size: size)))
        TextPinDebugLog.log("layout-render-image", metadata: metadata)
        let image = NSImage(size: size)
        image.lockFocus()
        let bounds = NSRect(origin: .zero, size: size)
        drawBackground(in: bounds)
        (normalizedText(text) as NSString).draw(
            with: textFrame(in: bounds),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: textAttributes()
        )
        image.unlockFocus()
        return image
    }

    private struct TextSystemMeasurement {
        let usedRect: NSRect
        let extraLineFragmentRect: NSRect
        let glyphRangeLength: Int
        let lineCount: Int
    }

    private static func textSystemMeasurement(for text: String, width: CGFloat) -> TextSystemMeasurement {
        let storage = NSTextStorage(string: normalizedText(text), attributes: textAttributes())
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(
            width: max(1, width),
            height: CGFloat.greatestFiniteMagnitude
        ))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        let glyphRange = layoutManager.glyphRange(for: container)
        var lineCount = 0
        var index = glyphRange.location
        while index < NSMaxRange(glyphRange) {
            var effectiveRange = NSRange(location: 0, length: 0)
            _ = layoutManager.lineFragmentRect(
                forGlyphAt: index,
                effectiveRange: &effectiveRange,
                withoutAdditionalLayout: true
            )
            let next = NSMaxRange(effectiveRange)
            guard next > index else { break }
            lineCount += 1
            index = next
        }

        return TextSystemMeasurement(
            usedRect: layoutManager.usedRect(for: container),
            extraLineFragmentRect: layoutManager.extraLineFragmentRect,
            glyphRangeLength: glyphRange.length,
            lineCount: lineCount
        )
    }
}

@MainActor
final class TextPinContentView: NSView, NSTextViewDelegate {
    weak var pinWindow: PinWindow?

    private let toolbar = TextPinToolbarView()
    private let displayTextView = TextPinDisplayTextView()
    private let debugID = UUID().uuidString
    private var text: String
    private var trackingArea: NSTrackingArea?
    private var isToolbarVisible = false
    private var isEndingTextEditing = false
    private var committedTextDuringEditing = false

    override var acceptsFirstResponder: Bool { true }

    init(text: String, frame frameRect: NSRect) {
        self.text = text
        super.init(frame: frameRect)
        wantsLayer = true
        setupDisplayTextView()
        setupToolbar()
        logSnapshot("content-init")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        TextPinLayout.drawBackground(in: bounds)
    }

    override func layout() {
        super.layout()
        layoutDisplayTextView()
        layoutToolbar()
        refreshToolbarVisibility()
        logSnapshot("content-layout")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard !isTextEditing else {
            super.mouseDown(with: event)
            return
        }
        window?.makeFirstResponder(self)
        pinWindow?.performDrag(with: event)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateToolbarVisibility(for: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateToolbarVisibility(for: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateToolbarVisibility(for: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshToolbarVisibility()
    }

    private func setupDisplayTextView() {
        displayTextView.isEditable = false
        displayTextView.isSelectable = false
        displayTextView.isRichText = false
        displayTextView.importsGraphics = false
        displayTextView.drawsBackground = false
        displayTextView.insertionPointColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        displayTextView.textContainer?.widthTracksTextView = true
        displayTextView.textContainer?.containerSize = NSSize(
            width: max(1, bounds.width),
            height: CGFloat.greatestFiniteMagnitude
        )
        displayTextView.onMouseDown = { [weak self] event in
            self?.handleDisplayMouseDown(event)
        }
        displayTextView.onPointerEvent = { [weak self] event in
            self?.updateToolbarVisibility(for: event)
        }
        displayTextView.onCommit = { [weak self] in self?.commitTextEditingIfNeeded() }
        displayTextView.onCancel = { [weak self] in self?.cancelTextEditing() }
        displayTextView.delegate = self
        TextPinLayout.configure(displayTextView, text: text)
        addSubview(displayTextView)
        logSnapshot("setup-display-text-view")
    }

    private func layoutDisplayTextView() {
        displayTextView.frame = TextPinLayout.textFrame(in: bounds)
        displayTextView.textContainer?.containerSize = NSSize(
            width: max(1, displayTextView.bounds.width),
            height: CGFloat.greatestFiniteMagnitude
        )
        logSnapshot("layout-display-text-view")
    }

    private func handleDisplayMouseDown(_ event: NSEvent) {
        if isTextEditing {
            return
        }
        window?.makeFirstResponder(self)
        if event.clickCount >= 2 {
            beginTextEditing()
            displayTextView.forwardEditingMouseDown(with: event)
            return
        }
        pinWindow?.performDrag(with: event)
    }

    private func setupToolbar() {
        toolbar.alphaValue = 0
        toolbar.isHidden = true
        toolbar.onClose = { [weak self] in
            self?.pinWindow?.dismissClearingSource()
        }
        toolbar.onEdit = { [weak self] in
            self?.editTextImage()
        }
        toolbar.onEditText = { [weak self] in
            self?.beginTextEditingFromToolbar()
        }
        toolbar.onPointerEvent = { [weak self] event in
            self?.updateToolbarVisibility(for: event)
        }
        addSubview(toolbar)
    }

    private func layoutToolbar() {
        toolbar.frame = NSRect(
            x: 8,
            y: max(8, bounds.height - TextPinToolbarView.preferredHeight - 8),
            width: TextPinToolbarView.preferredWidth,
            height: TextPinToolbarView.preferredHeight
        )
    }

    private var isTextEditing: Bool {
        displayTextView.isTextEditing
    }

    private func updateToolbarVisibility(for event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        setToolbarVisible(bounds.contains(point))
    }

    private func refreshToolbarVisibility() {
        guard let window else {
            setToolbarVisible(false)
            return
        }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        setToolbarVisible(bounds.contains(point))
    }

    private func setToolbarVisible(_ visible: Bool) {
        guard visible != isToolbarVisible else { return }
        isToolbarVisible = visible
        toolbar.isHidden = !visible
        toolbar.alphaValue = visible ? 1 : 0
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 7:
            pinWindow?.dismissClearingSource()
        case 53:
            pinWindow?.dismiss()
        default:
            super.keyDown(with: event)
        }
    }

    func textDidEndEditing(_ notification: Notification) {
        logSnapshot("delegate-text-did-end-editing", extra: [
            "committedTextDuringEditing": committedTextDuringEditing,
            "isEndingTextEditing": isEndingTextEditing,
        ])
        guard isTextEditing, !isEndingTextEditing, !committedTextDuringEditing else { return }
        commitTextEditingIfNeeded()
    }

    func textDidBeginEditing(_ notification: Notification) {
        logSnapshot("delegate-text-did-begin-editing")
    }

    func textDidChange(_ notification: Notification) {
        resizeForLiveTextEditing()
        logSnapshot("delegate-text-did-change")
    }

    private func beginTextEditing() {
        guard !isTextEditing else { return }
        logSnapshot("begin-text-editing-before")
        committedTextDuringEditing = false
        displayTextView.isTextEditing = true
        displayTextView.isEditable = true
        displayTextView.isSelectable = true
        window?.makeFirstResponder(displayTextView)
        logSnapshot("begin-text-editing-after")
    }

    private func beginTextEditingFromToolbar() {
        beginTextEditing()
        displayTextView.setSelectedRange(NSRange(location: displayTextView.string.utf16.count, length: 0))
        logSnapshot("begin-text-editing-from-toolbar")
    }

    @discardableResult
    func commitTextEditingIfNeeded() -> Bool {
        guard isTextEditing else { return true }
        logSnapshot("commit-text-editing-start")
        committedTextDuringEditing = true
        let updatedText = TextPinLayout.previewText(displayTextView.string)
        endTextEditing()

        guard !updatedText.isEmpty else {
            logSnapshot("commit-text-editing-empty-dismiss")
            pinWindow?.dismissClearingSource()
            return false
        }

        text = updatedText
        updateDisplayTextAndResize()
        logSnapshot("commit-text-editing-finish")
        return true
    }

    private func cancelTextEditing() {
        guard isTextEditing else { return }
        logSnapshot("cancel-text-editing-start")
        TextPinLayout.configure(displayTextView, text: text)
        endTextEditing()
        updateDisplayTextAndResize()
        logSnapshot("cancel-text-editing-finish")
    }

    private func endTextEditing() {
        logSnapshot("end-text-editing-before")
        isEndingTextEditing = true
        displayTextView.isTextEditing = false
        displayTextView.isEditable = false
        displayTextView.isSelectable = false
        window?.makeFirstResponder(self)
        isEndingTextEditing = false
        logSnapshot("end-text-editing-after")
    }

    private func updateDisplayTextAndResize() {
        let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let targetSize = targetTextSize(for: text, on: screen)
        logSnapshot("update-display-text-and-resize-before", extra: [
            "targetSize": TextPinDebugLog.size(targetSize),
            "screenVisibleFrame": TextPinDebugLog.rect(screen.visibleFrame),
        ])
        resizeWindow(to: targetSize, on: screen)
        frame = NSRect(origin: .zero, size: targetSize)
        TextPinLayout.configure(displayTextView, text: text)
        layoutDisplayTextView()
        needsDisplay = true
        logSnapshot("update-display-text-and-resize-after", extra: [
            "targetSize": TextPinDebugLog.size(targetSize),
        ])
    }

    private func resizeForLiveTextEditing() {
        guard isTextEditing else { return }
        let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let selection = displayTextView.selectedRange()
        let targetSize = targetTextSize(for: displayTextView.string, on: screen)
        let shouldResize = abs(targetSize.width - bounds.width) > 0.5 ||
            abs(targetSize.height - bounds.height) > 0.5

        logSnapshot("live-text-resize-before", extra: [
            "shouldResize": shouldResize,
            "targetSize": TextPinDebugLog.size(targetSize),
            "screenVisibleFrame": TextPinDebugLog.rect(screen.visibleFrame),
        ])
        if shouldResize {
            resizeWindow(to: targetSize, on: screen)
            frame = NSRect(origin: .zero, size: targetSize)
            layoutDisplayTextView()
            needsDisplay = true
        }

        displayTextView.setSelectedRange(selection)
        displayTextView.ensureSelectionVisible()
        logSnapshot("live-text-resize-after", extra: [
            "targetSize": TextPinDebugLog.size(targetSize),
        ])
    }

    private func targetTextSize(for string: String, on screen: NSScreen) -> NSSize {
        fittedSize(
            for: TextPinLayout.size(
                for: string,
                maxWidth: TextPinLayout.maxWidth(on: screen)
            ),
            on: screen
        )
    }

    private func resizeWindow(to targetSize: NSSize, on screen: NSScreen) {
        guard let window else {
            logSnapshot("resize-window-no-window", extra: [
                "targetSize": TextPinDebugLog.size(targetSize),
            ])
            setFrameSize(targetSize)
            return
        }

        let current = window.frame
        var targetFrame = NSRect(
            x: current.minX,
            y: current.maxY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )
        targetFrame = clampedFrame(targetFrame, on: screen)
        TextPinDebugLog.log("resize-window", metadata: [
            "pinID": debugID,
            "currentFrame": TextPinDebugLog.rect(current),
            "targetFrame": TextPinDebugLog.rect(targetFrame),
            "targetSize": TextPinDebugLog.size(targetSize),
            "screenVisibleFrame": TextPinDebugLog.rect(screen.visibleFrame),
        ])
        window.setFrame(targetFrame, display: true, animate: false)
    }

    private func fittedSize(for size: NSSize, on screen: NSScreen) -> NSSize {
        guard size.width > 0, size.height > 0 else { return size }
        let frame = screen.visibleFrame
        let maxWidth = max(200, frame.width - 80)
        let maxHeight = max(200, frame.height - 80)
        let ratio = min(1.0, min(maxWidth / size.width, maxHeight / size.height))
        if ratio >= 1.0 { return size }
        return NSSize(width: floor(size.width * ratio), height: floor(size.height * ratio))
    }

    private func clampedFrame(_ frame: NSRect, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        var result = frame
        result.origin.x = min(max(result.minX, visible.minX), max(visible.minX, visible.maxX - result.width))
        result.origin.y = min(max(result.minY, visible.minY), max(visible.minY, visible.maxY - result.height))
        return result
    }

    private func editTextImage() {
        guard commitTextEditingIfNeeded() else { return }
        guard let pinWindow,
              let appDelegate = NSApp.delegate as? AppDelegate,
              let image = TextPinLayout.renderImage(for: text, size: bounds.size)
        else { return }
        logSnapshot("edit-text-image")

        appDelegate.handlePinnedImageEditRequest(image) {
            pinWindow.dismiss()
        }
    }

    private func logSnapshot(_ event: String, extra: [String: Any] = [:]) {
        var metadata = TextPinDebugLog.textMetadata(displayTextView.string)
        metadata["pinID"] = debugID
        metadata["contentBounds"] = TextPinDebugLog.rect(bounds)
        metadata["contentFrame"] = TextPinDebugLog.rect(frame)
        metadata["displayBounds"] = TextPinDebugLog.rect(displayTextView.bounds)
        metadata["displayFrame"] = TextPinDebugLog.rect(displayTextView.frame)
        metadata["displayVisibleRect"] = TextPinDebugLog.rect(displayTextView.visibleRect)
        metadata["expectedTextFrame"] = TextPinDebugLog.rect(TextPinLayout.textFrame(in: bounds))
        metadata["firstResponder"] = String(describing: window?.firstResponder)
        metadata["isEditable"] = displayTextView.isEditable
        metadata["isSelectable"] = displayTextView.isSelectable
        metadata["isTextEditing"] = isTextEditing
        metadata["textContainerInset"] = TextPinDebugLog.insets(displayTextView.textContainerInset)
        metadata["textContainerLineFragmentPadding"] = TextPinDebugLog.number(displayTextView.textContainer?.lineFragmentPadding ?? -1)
        metadata["textContainerOrigin"] = TextPinDebugLog.point(displayTextView.textContainerOrigin)
        metadata["textContainerSize"] = TextPinDebugLog.size(displayTextView.textContainer?.containerSize ?? .zero)
        metadata["windowFrame"] = TextPinDebugLog.rect(window?.frame ?? .zero)
        if let layoutManager = displayTextView.layoutManager,
           let textContainer = displayTextView.textContainer {
            metadata["layoutManagerExtraLineFragment"] = TextPinDebugLog.rect(layoutManager.extraLineFragmentRect)
            metadata["layoutManagerGlyphRange"] = String(describing: layoutManager.glyphRange(for: textContainer))
            metadata["layoutManagerUsedRect"] = TextPinDebugLog.rect(layoutManager.usedRect(for: textContainer))
        }
        for (key, value) in extra {
            metadata[key] = value
        }
        TextPinDebugLog.log(event, metadata: metadata)
    }
}

private final class TextPinDisplayTextView: NSTextView {
    var onMouseDown: ((NSEvent) -> Void)?
    var onPointerEvent: ((NSEvent) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var isTextEditing = false
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { isTextEditing }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onPointerEvent?(event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onPointerEvent?(event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointerEvent?(event)
    }

    override func mouseDown(with event: NSEvent) {
        onPointerEvent?(event)
        guard !isTextEditing else {
            super.mouseDown(with: event)
            return
        }
        onMouseDown?(event)
    }

    override func keyDown(with event: NSEvent) {
        guard isTextEditing else {
            super.keyDown(with: event)
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53, modifiers.isEmpty {
            onCancel?()
            return
        }
        if (event.keyCode == 36 || event.keyCode == 76), modifiers == .command {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    func forwardEditingMouseDown(with event: NSEvent) {
        guard isTextEditing else { return }
        super.mouseDown(with: event)
    }

    func ensureSelectionVisible() {
        guard isTextEditing else { return }
        if let layoutManager, let textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }
        scrollRangeToVisible(selectedRange())
    }
}
