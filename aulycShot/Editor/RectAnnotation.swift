import AppKit

// MARK: - Rectangle Annotation

struct RectAnnotation: Annotation, Equatable {
    let rect: NSRect
    let color: NSColor
    let lineWidth: CGFloat
    let fillMode: ShapeFillMode
    let strokeStyle: ShapeStrokeStyle
    let roughStyle: RoughShapeStyle
    var rotation: CGFloat = 0

    init(
        rect: NSRect,
        color: NSColor,
        lineWidth: CGFloat,
        filled: Bool = false,
        fillMode: ShapeFillMode? = nil,
        strokeStyle: ShapeStrokeStyle = .standard,
        roughStyle: RoughShapeStyle? = nil,
        rotation: CGFloat = 0
    ) {
        self.rect = rect
        self.color = color
        self.lineWidth = lineWidth
        self.fillMode = fillMode ?? (filled ? .opaque : .none)
        self.strokeStyle = strokeStyle
        self.roughStyle = roughStyle ?? RoughShapeStyle.make(rect: rect, lineWidth: lineWidth)
        self.rotation = rotation
    }

    var boundingRect: NSRect { rect }
    var supportsRotation: Bool { true }
    var filled: Bool { fillMode.isFilled }

    func draw(in context: CGContext, bounds: NSRect) {
        ShapeDrawing.fillRect(rect, color: color, lineWidth: lineWidth, fillMode: fillMode, strokeStyle: strokeStyle, roughStyle: roughStyle, in: context)
        ShapeDrawing.strokeRect(rect, color: color, lineWidth: lineWidth, strokeStyle: strokeStyle, roughStyle: roughStyle, in: context)
    }

    func containsPoint(_ point: NSPoint) -> Bool {
        let p = unrotate(point)
        let path = ShapeDrawing.rectPath(rect, lineWidth: lineWidth, strokeStyle: strokeStyle)
        if filled, path.contains(p) {
            return true
        }
        return strokedPathContains(path, point: p, lineWidth: lineWidth)
    }

    func translated(by delta: NSPoint) -> Annotation {
        RectAnnotation(
            rect: rect.offsetBy(dx: delta.x, dy: delta.y),
            color: color,
            lineWidth: lineWidth,
            fillMode: fillMode,
            strokeStyle: strokeStyle,
            roughStyle: roughStyle,
            rotation: rotation
        )
    }

    func withRotation(_ rotation: CGFloat) -> Annotation {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    func withColor(_ color: NSColor) -> Annotation {
        RectAnnotation(rect: rect, color: color, lineWidth: lineWidth, fillMode: fillMode, strokeStyle: strokeStyle, roughStyle: roughStyle, rotation: rotation)
    }

    func withLineWidth(_ lineWidth: CGFloat) -> Annotation {
        RectAnnotation(rect: rect, color: color, lineWidth: lineWidth, fillMode: fillMode, strokeStyle: strokeStyle, roughStyle: roughStyle.tuned(for: rect, lineWidth: lineWidth), rotation: rotation)
    }

    func withFill(_ filled: Bool) -> Annotation {
        RectAnnotation(rect: rect, color: color, lineWidth: lineWidth, filled: filled, strokeStyle: strokeStyle, roughStyle: roughStyle, rotation: rotation)
    }

    func withShapeFillMode(_ fillMode: ShapeFillMode) -> Annotation {
        RectAnnotation(rect: rect, color: color, lineWidth: lineWidth, fillMode: fillMode, strokeStyle: strokeStyle, roughStyle: roughStyle, rotation: rotation)
    }

    func withShapeStrokeStyle(_ strokeStyle: ShapeStrokeStyle) -> Annotation {
        RectAnnotation(rect: rect, color: color, lineWidth: lineWidth, fillMode: fillMode, strokeStyle: strokeStyle, roughStyle: roughStyle, rotation: rotation)
    }
}
