import AppKit

// MARK: - Annotation Protocol

protocol Annotation {
    func draw(in context: CGContext, bounds: NSRect)

    /// True when the point is on (or close enough to) this annotation that
    /// the user can grab it for moving. For stroke-based shapes this is the
    /// stroke band only — the interior is intentionally transparent so the
    /// user can click through to whatever is behind.
    func containsPoint(_ point: NSPoint) -> Bool

    /// Returns a copy of this annotation translated by `delta`. Used while
    /// the user drags an existing annotation.
    func translated(by delta: NSPoint) -> Annotation

    /// Axis-aligned bounding box used for selection handles and rotation
    /// pivots. Computed in canvas coordinates.
    var boundingRect: NSRect { get }

    /// Current rotation angle in radians, applied around `boundingRect` mid.
    var rotation: CGFloat { get }

    /// Whether rotating this annotation has a visible effect. Pen / marker /
    /// mosaic strokes opt out — their geometry already encodes their shape.
    var supportsRotation: Bool { get }

    /// Returns a copy with the given rotation. Default impl is a no-op for
    /// types that don't support rotation.
    func withRotation(_ rotation: CGFloat) -> Annotation

    /// Adjust-mode mutators — return a copy with the given property replaced.
    /// Annotation types that don't carry the property fall back to the
    /// default no-op implementation, so callers can apply changes uniformly
    /// without type-switching.
    func withColor(_ color: NSColor) -> Annotation
    func withLineWidth(_ lineWidth: CGFloat) -> Annotation
    func withFontSize(_ fontSize: CGFloat) -> Annotation
    func withFill(_ filled: Bool) -> Annotation
    func withShapeFillMode(_ fillMode: ShapeFillMode) -> Annotation
    func withShapeStrokeStyle(_ strokeStyle: ShapeStrokeStyle) -> Annotation
}
extension Annotation {
    var rotation: CGFloat { 0 }
    var supportsRotation: Bool { false }
    func withRotation(_ rotation: CGFloat) -> Annotation { self }
    func withColor(_ color: NSColor) -> Annotation { self }
    func withLineWidth(_ lineWidth: CGFloat) -> Annotation { self }
    func withFontSize(_ fontSize: CGFloat) -> Annotation { self }
    func withFill(_ filled: Bool) -> Annotation { self }
    func withShapeFillMode(_ fillMode: ShapeFillMode) -> Annotation { self }
    func withShapeStrokeStyle(_ strokeStyle: ShapeStrokeStyle) -> Annotation { self }

    /// Wraps `draw` with the rotation transform if the annotation has any.
    /// All draw methods are written in unrotated coordinates; this helper is
    /// the single place rotation is applied.
    func drawApplyingTransforms(in context: CGContext, bounds: NSRect) {
        guard rotation != 0, supportsRotation else {
            draw(in: context, bounds: bounds)
            return
        }
        let center = NSPoint(x: boundingRect.midX, y: boundingRect.midY)
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation)
        context.translateBy(x: -center.x, y: -center.y)
        draw(in: context, bounds: bounds)
        context.restoreGState()
    }

    /// Map a canvas-space point back into the annotation's unrotated frame
    /// so existing hit tests can ignore rotation entirely.
    func unrotate(_ point: NSPoint) -> NSPoint {
        guard rotation != 0, supportsRotation else { return point }
        let c = NSPoint(x: boundingRect.midX, y: boundingRect.midY)
        let dx = point.x - c.x
        let dy = point.y - c.y
        let cosR = cos(-rotation)
        let sinR = sin(-rotation)
        return NSPoint(
            x: c.x + dx * cosR - dy * sinR,
            y: c.y + dx * sinR + dy * cosR
        )
    }
}

private let strokeHitTolerance: CGFloat = 8

enum ShapeFillMode: String, CaseIterable {
    case none
    case opaque
    case translucent

    var isFilled: Bool { self != .none }

    var alpha: CGFloat {
        switch self {
        case .none: return 0
        case .opaque: return 1
        case .translucent: return 0.42
        }
    }
}

enum ShapeStrokeStyle: String, CaseIterable {
    case standard
    case rounded
    case handDrawn
}

struct RoughShapeStyle: Equatable {
    let seed: UInt64
    let roughness: CGFloat
    let passes: Int

    init(seed: UInt64 = RoughShapeStyle.randomSeed(), roughness: CGFloat, passes: Int = 1) {
        self.seed = seed == 0 ? Self.fallbackSeed : seed
        self.roughness = min(max(roughness, 0), 4)
        self.passes = max(1, min(passes, 3))
    }

    static func make(seed: UInt64 = RoughShapeStyle.randomSeed(), rect: NSRect, lineWidth: CGFloat) -> RoughShapeStyle {
        RoughShapeStyle(seed: seed, roughness: defaultRoughness(for: rect, lineWidth: lineWidth), passes: 1)
    }

    func tuned(for rect: NSRect, lineWidth: CGFloat) -> RoughShapeStyle {
        RoughShapeStyle(seed: seed, roughness: Self.defaultRoughness(for: rect, lineWidth: lineWidth), passes: passes)
    }

    static func randomSeed() -> UInt64 {
        UInt64.random(in: 1...UInt64.max)
    }

    private static let fallbackSeed: UInt64 = 0x9E3779B97F4A7C15

    private static func defaultRoughness(for rect: NSRect, lineWidth: CGFloat) -> CGFloat {
        let sizeDriven = min(rect.width, rect.height) * 0.001
        let widthDriven = lineWidth * 0.04
        return max(0.15, min(0.55, max(sizeDriven, widthDriven)))
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x123456789ABCDEF : seed
    }

    mutating func next() -> CGFloat {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return CGFloat(state % 10_000) / 10_000
    }

    mutating func range(_ min: CGFloat, _ max: CGFloat) -> CGFloat {
        min + (max - min) * next()
    }
}

func strokedPathContains(_ path: CGPath, point: NSPoint, lineWidth: CGFloat) -> Bool {
    let width = max(strokeHitTolerance, lineWidth + 4)
    let stroked = path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
    return stroked.contains(point)
}

func distanceFrom(_ point: NSPoint, toSegmentFrom start: NSPoint, to end: NSPoint) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else {
        return hypot(point.x - start.x, point.y - start.y)
    }

    let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
    let closest = NSPoint(x: start.x + t * dx, y: start.y + t * dy)
    return hypot(point.x - closest.x, point.y - closest.y)
}

enum ShapeDrawing {
    static func fillRect(_ rect: NSRect, color: NSColor, lineWidth: CGFloat, fillMode: ShapeFillMode, strokeStyle: ShapeStrokeStyle, roughStyle: RoughShapeStyle, in context: CGContext) {
        guard fillMode.isFilled else { return }
        context.saveGState()
        context.setFillColor(color.withAlphaComponent(fillMode.alpha).cgColor)
        switch strokeStyle {
        case .standard:
            context.fill(rect)
        case .rounded:
            context.addPath(roundedRectPath(rect, lineWidth: lineWidth))
            context.fillPath()
        case .handDrawn:
            context.addPath(roughRoundedRectPath(rect, lineWidth: lineWidth, style: roughStyle, pass: 0))
            context.fillPath()
        }
        context.restoreGState()
    }

    static func fillEllipse(_ rect: NSRect, color: NSColor, lineWidth: CGFloat, fillMode: ShapeFillMode, strokeStyle: ShapeStrokeStyle, roughStyle: RoughShapeStyle, in context: CGContext) {
        guard fillMode.isFilled else { return }
        context.saveGState()
        context.setFillColor(color.withAlphaComponent(fillMode.alpha).cgColor)
        switch strokeStyle {
        case .standard, .rounded:
            context.fillEllipse(in: rect)
        case .handDrawn:
            context.addPath(roughEllipsePath(rect, style: roughStyle, pass: 0))
            context.fillPath()
        }
        context.restoreGState()
    }

    static func strokeRect(_ rect: NSRect, color: NSColor, lineWidth: CGFloat, strokeStyle: ShapeStrokeStyle, roughStyle: RoughShapeStyle, in context: CGContext) {
        switch strokeStyle {
        case .standard:
            context.saveGState()
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.stroke(rect)
            context.restoreGState()
        case .rounded:
            context.saveGState()
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineJoin(.round)
            context.addPath(roundedRectPath(rect, lineWidth: lineWidth))
            context.strokePath()
            context.restoreGState()
        case .handDrawn:
            let drawingRect = rect.insetBy(dx: strokeInset(for: rect, lineWidth: lineWidth), dy: strokeInset(for: rect, lineWidth: lineWidth))
            drawRoughStroke(
                color: color,
                style: roughStyle,
                in: context
            ) { pass in
                roughRoundedRectStrokeSamples(drawingRect, lineWidth: lineWidth, style: roughStyle, pass: pass)
            }
        }
    }

    static func strokeEllipse(_ rect: NSRect, color: NSColor, lineWidth: CGFloat, strokeStyle: ShapeStrokeStyle, roughStyle: RoughShapeStyle, in context: CGContext) {
        switch strokeStyle {
        case .standard, .rounded:
            context.saveGState()
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: rect)
            context.restoreGState()
        case .handDrawn:
            let drawingRect = rect.insetBy(dx: strokeInset(for: rect, lineWidth: lineWidth), dy: strokeInset(for: rect, lineWidth: lineWidth))
            drawRoughStroke(
                color: color,
                style: roughStyle,
                in: context
            ) { pass in
                roughEllipseStrokeSamples(drawingRect, lineWidth: lineWidth, style: roughStyle, pass: pass)
            }
        }
    }

    private static func roundedRectRadius(for rect: NSRect, lineWidth: CGFloat) -> CGFloat {
        let shortest = max(1, min(rect.width, rect.height))
        return min(shortest * 0.2, max(12, lineWidth * 3.2))
    }

    private static func roundedRectPath(_ rect: NSRect, lineWidth: CGFloat) -> CGPath {
        let radius = roundedRectRadius(for: rect, lineWidth: lineWidth)
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    static func rectPath(_ rect: NSRect, lineWidth: CGFloat, strokeStyle: ShapeStrokeStyle) -> CGPath {
        switch strokeStyle {
        case .standard:
            return CGPath(rect: rect, transform: nil)
        case .rounded, .handDrawn:
            return roundedRectPath(rect, lineWidth: lineWidth)
        }
    }

    private struct VariableStrokeSample {
        let point: CGPoint
        let width: CGFloat
    }

    private static func drawRoughStroke(color: NSColor, style: RoughShapeStyle, in context: CGContext, samplesForPass: (Int) -> [VariableStrokeSample]) {
        context.saveGState()
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        for pass in 0..<style.passes {
            let alpha: CGFloat
            let widthScale: CGFloat
            switch pass {
            case 0:
                alpha = 1
                widthScale = 1
            case 1:
                alpha = 0.62
                widthScale = 0.86
            default:
                alpha = 0.38
                widthScale = 0.68
            }
            drawVariableWidthStroke(
                samples: samplesForPass(pass).map {
                    VariableStrokeSample(point: $0.point, width: max(1, $0.width * widthScale))
                },
                color: colorByMultiplyingAlpha(color, by: alpha),
                in: context
            )
        }

        context.restoreGState()
    }

    private static func colorByMultiplyingAlpha(_ color: NSColor, by alpha: CGFloat) -> NSColor {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        return rgb.withAlphaComponent(min(max(rgb.alphaComponent * alpha, 0), 1))
    }

    private static func strokeInset(for rect: NSRect, lineWidth: CGFloat) -> CGFloat {
        let maxInset = max(0, min(rect.width, rect.height) / 2 - 0.5)
        return min(maxInset, max(0, lineWidth / 2))
    }

    private static func roughRoundedRectPath(_ rect: NSRect, lineWidth: CGFloat, style: RoughShapeStyle, pass: Int) -> CGPath {
        guard rect.width > 0, rect.height > 0 else { return CGMutablePath() }
        var rng = SeededRandom(seed: passSeed(style.seed, pass: pass))
        let radius = roundedRectRadius(for: rect, lineWidth: lineWidth)
        let points = roundedRectPoints(
            rect: rect,
            radius: radius,
            step: roughSampleStep,
            bowAmount: 0,
            rng: &rng
        )
        return smoothClosedPath(points: points)
    }

    private static func roughEllipsePath(_ rect: NSRect, style _: RoughShapeStyle, pass _: Int) -> CGPath {
        guard rect.width > 0, rect.height > 0 else { return CGMutablePath() }
        return smoothClosedPath(points: ellipsePoints(rect: rect, step: roughSampleStep))
    }

    private static func roughRoundedRectStrokeSamples(_ rect: NSRect, lineWidth: CGFloat, style: RoughShapeStyle, pass: Int) -> [VariableStrokeSample] {
        guard rect.width > 0, rect.height > 0 else { return [] }
        var rng = SeededRandom(seed: passSeed(style.seed, pass: pass))
        let radius = roundedRectRadius(for: rect, lineWidth: lineWidth)
        let points = roundedRectPoints(
            rect: rect,
            radius: radius,
            step: roughSampleStep,
            bowAmount: 0,
            rng: &rng
        )
        return pressureSamples(points: points, lineWidth: lineWidth, style: style, rng: &rng)
    }

    private static func roughEllipseStrokeSamples(_ rect: NSRect, lineWidth: CGFloat, style: RoughShapeStyle, pass: Int) -> [VariableStrokeSample] {
        guard rect.width > 0, rect.height > 0 else { return [] }
        var rng = SeededRandom(seed: passSeed(style.seed, pass: pass))
        return pressureSamples(points: ellipsePoints(rect: rect, step: roughSampleStep), lineWidth: lineWidth, style: style, rng: &rng)
    }

    private static func pressureSamples(points: [CGPoint], lineWidth: CGFloat, style: RoughShapeStyle, rng: inout SeededRandom) -> [VariableStrokeSample] {
        guard !points.isEmpty else { return [] }
        let phaseA = rng.range(0, .pi * 2)
        let phaseB = rng.range(0, .pi * 2)
        let phaseC = rng.range(0, .pi * 2)
        let variation = max(0.12, min(0.24, 0.14 + style.roughness * 0.08))
        let count = CGFloat(points.count)

        return points.enumerated().map { index, point in
            let progress = CGFloat(index) / count
            let t = progress * .pi * 2
            let pressure = 1
                + variation * sin(t + phaseA)
                + variation * 0.45 * sin(t * 2.3 + phaseB)
                + variation * 0.24 * cos(t * 4.1 + phaseC)
            return VariableStrokeSample(
                point: point,
                width: max(1, lineWidth * min(max(pressure, 0.72), 1.28))
            )
        }
    }

    private static func drawVariableWidthStroke(samples: [VariableStrokeSample], color: NSColor, in context: CGContext) {
        guard samples.count >= 3 else { return }

        var left: [CGPoint] = []
        var right: [CGPoint] = []
        left.reserveCapacity(samples.count)
        right.reserveCapacity(samples.count)

        for index in samples.indices {
            let normal = strokeNormal(at: index, in: samples)
            let halfWidth = samples[index].width / 2
            let point = samples[index].point
            left.append(CGPoint(
                x: point.x + normal.dx * halfWidth,
                y: point.y + normal.dy * halfWidth
            ))
            right.append(CGPoint(
                x: point.x - normal.dx * halfWidth,
                y: point.y - normal.dy * halfWidth
            ))
        }

        let path = CGMutablePath()
        addSmoothedClosedLoop(left, to: path)
        addSmoothedClosedLoop(right.reversed(), to: path)

        context.saveGState()
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    private static func strokeNormal(at index: Int, in samples: [VariableStrokeSample]) -> CGVector {
        let previousIndex = index == samples.startIndex
            ? samples.index(before: samples.endIndex)
            : samples.index(before: index)
        let nextIndex = index == samples.index(before: samples.endIndex)
            ? samples.startIndex
            : samples.index(after: index)
        let previous = samples[previousIndex].point
        let next = samples[nextIndex].point
        let dx = next.x - previous.x
        let dy = next.y - previous.y
        let length = max(0.001, hypot(dx, dy))
        return CGVector(dx: -dy / length, dy: dx / length)
    }

    private static func addSmoothedClosedLoop<S: Sequence>(_ points: S, to path: CGMutablePath) where S.Element == CGPoint {
        let points = Array(points)
        guard points.count > 2 else { return }

        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        let count = points.count
        path.move(to: mid(points[0], points[1]))
        for index in 1...count {
            let current = points[index % count]
            let next = points[(index + 1) % count]
            path.addQuadCurve(to: mid(current, next), control: current)
        }
        path.closeSubpath()
    }

    private static func passSeed(_ seed: UInt64, pass: Int) -> UInt64 {
        seed &+ (UInt64(pass + 1) &* 0x9E3779B97F4A7C15)
    }

    private static let roughSampleStep: CGFloat = 10
    private static let roughArcStep: CGFloat = .pi / 12

    private static func roundedRectPoints(rect: NSRect, radius: CGFloat, step: CGFloat, bowAmount: CGFloat, rng: inout SeededRandom) -> [CGPoint] {
        let r = min(radius, rect.width / 2, rect.height / 2)
        var points: [CGPoint] = []

        sampleRoughLine(
            from: CGPoint(x: rect.minX + r, y: rect.minY),
            to: CGPoint(x: rect.maxX - r, y: rect.minY),
            step: step,
            bowAmount: bowAmount,
            rng: &rng,
            points: &points
        )
        sampleArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r,
            startAngle: -.pi / 2,
            endAngle: 0,
            stepAngle: roughArcStep,
            points: &points
        )
        sampleRoughLine(
            from: CGPoint(x: rect.maxX, y: rect.minY + r),
            to: CGPoint(x: rect.maxX, y: rect.maxY - r),
            step: step,
            bowAmount: bowAmount,
            rng: &rng,
            points: &points
        )
        sampleArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r,
            startAngle: 0,
            endAngle: .pi / 2,
            stepAngle: roughArcStep,
            points: &points
        )
        sampleRoughLine(
            from: CGPoint(x: rect.maxX - r, y: rect.maxY),
            to: CGPoint(x: rect.minX + r, y: rect.maxY),
            step: step,
            bowAmount: bowAmount,
            rng: &rng,
            points: &points
        )
        sampleArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r,
            startAngle: .pi / 2,
            endAngle: .pi,
            stepAngle: roughArcStep,
            points: &points
        )
        sampleRoughLine(
            from: CGPoint(x: rect.minX, y: rect.maxY - r),
            to: CGPoint(x: rect.minX, y: rect.minY + r),
            step: step,
            bowAmount: bowAmount,
            rng: &rng,
            points: &points
        )
        sampleArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r,
            startAngle: .pi,
            endAngle: .pi * 1.5,
            stepAngle: roughArcStep,
            points: &points
        )

        return points
    }

    private static func ellipsePoints(rect: NSRect, step: CGFloat) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        let circumference = .pi * (3 * (rx + ry) - sqrt((3 * rx + ry) * (rx + 3 * ry)))
        let count = max(24, Int(ceil(circumference / step)))
        return (0..<count).map { index in
            let angle = .pi * 2 * CGFloat(index) / CGFloat(count)
            return CGPoint(
                x: center.x + rx * cos(angle),
                y: center.y + ry * sin(angle)
            )
        }
    }

    private static func sampleRoughLine(
        from start: CGPoint,
        to end: CGPoint,
        step: CGFloat,
        bowAmount: CGFloat,
        rng: inout SeededRandom,
        points: inout [CGPoint]
    ) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 0 else {
            appendPoint(start, to: &points)
            return
        }

        let count = max(1, Int(ceil(distance / step)))
        let nx = -dy / distance
        let ny = dx / distance
        let bowDirection = rng.range(-1, 1)
        for index in 0...count {
            if !points.isEmpty && index == 0 { continue }
            let t = CGFloat(index) / CGFloat(count)
            let bow = sin(t * .pi) * bowAmount * bowDirection
            points.append(CGPoint(
                x: start.x + dx * t + nx * bow,
                y: start.y + dy * t + ny * bow
            ))
        }
    }

    private static func sampleArc(
        center: CGPoint,
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        stepAngle: CGFloat,
        points: inout [CGPoint]
    ) {
        guard radius > 0 else {
            appendPoint(center, to: &points)
            return
        }

        let total = abs(endAngle - startAngle)
        let count = max(3, Int(ceil(total / stepAngle)))
        for index in 0...count {
            if !points.isEmpty && index == 0 { continue }
            let t = CGFloat(index) / CGFloat(count)
            let angle = startAngle + (endAngle - startAngle) * t
            points.append(CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            ))
        }
    }

    private static func appendPoint(_ point: CGPoint, to points: inout [CGPoint]) {
        guard points.last != point else { return }
        points.append(point)
    }

    private static func smoothClosedPath(points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count > 2 else { return path }

        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        let count = points.count
        path.move(to: mid(points[0], points[1]))
        for index in 1...count {
            let current = points[index % count]
            let next = points[(index + 1) % count]
            path.addQuadCurve(to: mid(current, next), control: current)
        }
        path.closeSubpath()
        return path
    }
}

enum ArrowStyle: String, CaseIterable {
    case tapered
    case doubleEnded
    case line
    case dotTail
}

enum NumberArrowShape {
    static let shaftWidth: CGFloat = 3
    static let headStrokeWidth: CGFloat = 1.5
    static let dotTailRadius: CGFloat = 5

    static var headLength: CGFloat { max(10, shaftWidth * 4) }
    static var headWidth: CGFloat { max(7, shaftWidth * 3) }

    static func headPath(
        tip: NSPoint,
        unitX: CGFloat,
        unitY: CGFloat,
        length: CGFloat = headLength,
        width: CGFloat = headWidth
    ) -> CGMutablePath {
        let baseX = tip.x - unitX * length
        let baseY = tip.y - unitY * length
        let perpX = -unitY
        let perpY = unitX
        let path = CGMutablePath()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: baseX + perpX * width / 2, y: baseY + perpY * width / 2))
        path.addLine(to: CGPoint(x: baseX - perpX * width / 2, y: baseY - perpY * width / 2))
        path.closeSubpath()
        return path
    }

    static func drawHead(
        tip: NSPoint,
        unitX: CGFloat,
        unitY: CGFloat,
        length: CGFloat = headLength,
        width: CGFloat = headWidth,
        in context: CGContext
    ) {
        context.saveGState()
        context.addPath(headPath(tip: tip, unitX: unitX, unitY: unitY, length: length, width: width))
        context.setLineJoin(.round)
        context.setLineWidth(headStrokeWidth)
        context.drawPath(using: .fillStroke)
        context.restoreGState()
    }
}

// MARK: - Path smoothing

extension NSBezierPath {
    /// Append a quadratic bezier as an equivalent cubic. NSBezierPath has no
    /// native quadratic primitive, but Q(P0,C,P2) maps cleanly to
    /// C(P0, P0+2/3·(C-P0), P2+2/3·(C-P2), P2).
    func addQuadCurveAsCubic(to endPoint: NSPoint, controlPoint c: NSPoint) {
        let start = currentPoint
        let cp1 = NSPoint(
            x: start.x + (c.x - start.x) * 2.0 / 3.0,
            y: start.y + (c.y - start.y) * 2.0 / 3.0
        )
        let cp2 = NSPoint(
            x: endPoint.x + (c.x - endPoint.x) * 2.0 / 3.0,
            y: endPoint.y + (c.y - endPoint.y) * 2.0 / 3.0
        )
        curve(to: endPoint, controlPoint1: cp1, controlPoint2: cp2)
    }

    /// Build a smooth path through `points` using midpoint quadratic
    /// smoothing — each raw point becomes a quadratic control, anchors are
    /// the midpoints between consecutive raw points, and the curve flows
    /// through them without hard corners. Tangents stay continuous at the
    /// joints because each midpoint lies on the line between its neighbouring
    /// raw points, so the quadratic and the adjacent line share a tangent.
    static func smoothed(through points: [NSPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 1 { return path }
        if points.count == 2 {
            path.line(to: points[1])
            return path
        }
        let firstMid = NSPoint(
            x: (points[0].x + points[1].x) / 2,
            y: (points[0].y + points[1].y) / 2
        )
        path.line(to: firstMid)
        for i in 1..<points.count - 1 {
            let mid = NSPoint(
                x: (points[i].x + points[i + 1].x) / 2,
                y: (points[i].y + points[i + 1].y) / 2
            )
            path.addQuadCurveAsCubic(to: mid, controlPoint: points[i])
        }
        path.line(to: points[points.count - 1])
        return path
    }
}
