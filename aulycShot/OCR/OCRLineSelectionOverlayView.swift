import AppKit

/// Draws OCR line hit targets over an image and supports contiguous line
/// selection with the mouse. The view uses Vision's normalized, bottom-left
/// coordinate system when mapping recognized lines to the displayed image.
final class OCRLineSelectionOverlayView: NSView {
    private let imageSize: NSSize
    private var selectedLineIndices: Set<Int> = [] {
        didSet { needsDisplay = true }
    }
    private var selectionStartIndex: Int?

    var showsLineBoxes = false {
        didSet {
            if !showsLineBoxes {
                selectedLineIndices.removeAll()
            }
            needsDisplay = true
        }
    }

    var lines: [RecognizedTextLine] = [] {
        didSet {
            selectedLineIndices = Set(selectedLineIndices.filter { lines.indices.contains($0) })
            needsDisplay = true
        }
    }

    var onSelectText: ((String, [Int], Bool) -> Void)?

    init(imageSize: NSSize) {
        self.imageSize = imageSize
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard showsLineBoxes, !lines.isEmpty else { return }

        let imageRect = fittedImageRect()
        let lineRects = lines.indices.map { displayRect(for: lines[$0].boundingBox, in: imageRect) }

        let mask = NSBezierPath(rect: bounds)
        for rect in lineRects {
            mask.appendRoundedRect(rect.insetBy(dx: -3, dy: -2), xRadius: 3, yRadius: 3)
        }
        mask.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.22).setFill()
        mask.fill()

        for (index, rect) in lineRects.enumerated() {
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: -3, dy: -2), xRadius: 3, yRadius: 3)
            if selectedLineIndices.contains(index) {
                NSColor.selectedTextBackgroundColor.withAlphaComponent(0.58).setFill()
            } else {
                NSColor.textBackgroundColor.withAlphaComponent(0.72).setFill()
            }
            path.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard showsLineBoxes, !lines.isEmpty else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let index = nearestLineIndex(to: point) else { return }
        selectionStartIndex = index
        updateSelection(through: index, isFinal: false)
    }

    override func mouseDragged(with event: NSEvent) {
        guard selectionStartIndex != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let index = nearestLineIndex(to: point) else { return }
        updateSelection(through: index, isFinal: false)
    }

    override func mouseUp(with event: NSEvent) {
        defer { selectionStartIndex = nil }
        guard selectionStartIndex != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let index = nearestLineIndex(to: point) else { return }
        updateSelection(through: index, isFinal: true)
    }

    func copySelectedTextToClipboard() -> Bool {
        let text = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return true
    }

    func selectAllText() -> Bool {
        guard !lines.isEmpty else { return false }
        let indices = Array(lines.indices)
        selectedLineIndices = Set(indices)
        onSelectText?(selectedText, indices, false)
        return true
    }

    private var selectedText: String {
        selectedLineIndices.sorted().map { lines[$0].text }.joined(separator: "\n")
    }

    private func updateSelection(through endIndex: Int, isFinal: Bool) {
        guard let startIndex = selectionStartIndex else { return }
        let lower = min(startIndex, endIndex)
        let upper = max(startIndex, endIndex)
        let indices = Array(lower...upper)
        selectedLineIndices = Set(indices)
        onSelectText?(selectedText, indices, isFinal)
    }

    private func nearestLineIndex(to point: NSPoint) -> Int? {
        let imageRect = fittedImageRect()
        let candidates = lines.indices.map { index in
            (index, displayRect(for: lines[index].boundingBox, in: imageRect).insetBy(dx: -5, dy: -4))
        }
        if let direct = candidates.first(where: { $0.1.contains(point) }) {
            return direct.0
        }
        return candidates.min { distance(from: point, to: $0.1) < distance(from: point, to: $1.1) }?.0
    }

    private func fittedImageRect() -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func displayRect(for normalizedRect: CGRect, in imageRect: NSRect) -> NSRect {
        NSRect(
            x: imageRect.minX + normalizedRect.minX * imageRect.width,
            y: imageRect.minY + normalizedRect.minY * imageRect.height,
            width: normalizedRect.width * imageRect.width,
            height: normalizedRect.height * imageRect.height
        )
    }

    private func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }
}
