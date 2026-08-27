import AppKit

enum AnnotationChromeRenderer {
    private static let outlineColor = NSColor(calibratedWhite: 0.36, alpha: 0.9)

    static func drawSelectionOutline(for annotation: Annotation, in context: CGContext) {
        let box = AnnotationHandlePolicy.selectionBox(for: annotation)
        let needsRotation = annotation.supportsRotation && annotation.rotation != 0
        context.saveGState()
        if needsRotation {
            let rect = annotation.boundingRect
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: annotation.rotation)
            context.translateBy(x: -rect.midX, y: -rect.midY)
        }
        context.setStrokeColor(outlineColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(box)
        context.restoreGState()
    }

    static func drawSelectionHandles(for annotation: Annotation, in context: CGContext) {
        drawSelectionOutline(for: annotation, in: context)

        if AnnotationHandlePolicy.isResizable(annotation) {
            for anchor in EditorCanvasGeometry.ResizeAnchor.allCases {
                drawHandleDot(
                    at: AnnotationHandlePolicy.resizeHandlePoint(anchor, for: annotation),
                    size: AnnotationHandlePolicy.resizeHandleSize,
                    fill: NSColor.white.withAlphaComponent(0.95),
                    stroke: accentGreen,
                    in: context
                )
            }
        }

        if annotation.supportsRotation {
            let handleCenter = AnnotationHandlePolicy.rotationHandleCenter(for: annotation)
            let tether = AnnotationHandlePolicy.rotationTetherAnchor(for: annotation)
            context.saveGState()
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [3, 3])
            context.move(to: tether)
            context.addLine(to: handleCenter)
            context.strokePath()
            context.restoreGState()

            drawHandleDot(
                at: handleCenter,
                size: AnnotationHandlePolicy.rotateHandleSize,
                fill: NSColor(white: 0.12, alpha: 0.94),
                stroke: accentGreen,
                in: context
            )
            drawSymbolGlyph(
                "arrow.triangle.2.circlepath",
                at: handleCenter,
                pointSize: 10
            )
        }

        drawOptionalHandle(
            center: AnnotationHandlePolicy.curveHandleCenter(for: annotation),
            size: AnnotationHandlePolicy.curveHandleSize,
            in: context
        )
        drawOptionalHandle(
            center: AnnotationHandlePolicy.tipHandleCenter(for: annotation),
            size: AnnotationHandlePolicy.tipHandleSize,
            in: context
        )
        drawOptionalHandle(
            center: AnnotationHandlePolicy.textCalloutHandleCenter(for: annotation),
            size: AnnotationHandlePolicy.textCalloutHandleSize,
            fill: (annotation as? TextAnnotation)?.color ?? .white,
            stroke: NSColor.white.withAlphaComponent(0.95),
            in: context
        )
        drawOptionalHandle(
            center: AnnotationHandlePolicy.magnifierSourceHandleCenter(for: annotation),
            size: AnnotationHandlePolicy.magnifierSourceHandleSize,
            in: context
        )
        drawOptionalHandle(
            center: AnnotationHandlePolicy.arrowStartHandleCenter(for: annotation),
            size: AnnotationHandlePolicy.endpointHandleSize,
            in: context
        )
        drawOptionalHandle(
            center: AnnotationHandlePolicy.arrowEndHandleCenter(for: annotation),
            size: AnnotationHandlePolicy.endpointHandleSize,
            in: context
        )

        drawActionButton(
            in: AnnotationHandlePolicy.deleteButtonRect(for: annotation),
            symbolName: "xmark",
            symbolPointSize: 9,
            in: context
        )
        if let editRect = AnnotationHandlePolicy.editButtonRect(for: annotation) {
            drawActionButton(
                in: editRect,
                symbolName: "pencil",
                symbolPointSize: 10,
                in: context
            )
        }

        if let number = annotation as? NumberAnnotation,
           let decrementRect = AnnotationHandlePolicy.numberStepButtonRect(
               for: annotation,
               increment: false
           ),
           let incrementRect = AnnotationHandlePolicy.numberStepButtonRect(
               for: annotation,
               increment: true
           ) {
            drawActionButton(
                in: decrementRect,
                symbolName: "minus",
                symbolPointSize: 9,
                enabled: number.number > 1,
                in: context
            )
            drawActionButton(
                in: incrementRect,
                symbolName: "plus",
                symbolPointSize: 9,
                in: context
            )
        }

        if let magnifier = annotation as? MagnifierAnnotation,
           let decrementRect = AnnotationHandlePolicy.magnifierZoomButtonRect(
               for: annotation,
               increment: false
           ),
           let incrementRect = AnnotationHandlePolicy.magnifierZoomButtonRect(
               for: annotation,
               increment: true
           ) {
            drawActionButton(
                in: decrementRect,
                symbolName: "minus",
                symbolPointSize: 9,
                enabled: magnifier.zoom > MagnifierAnnotation.minZoom,
                in: context
            )
            drawActionButton(
                in: incrementRect,
                symbolName: "plus",
                symbolPointSize: 9,
                enabled: magnifier.zoom < MagnifierAnnotation.maxZoom,
                in: context
            )
        }
    }

    private static func drawOptionalHandle(
        center: NSPoint?,
        size: CGFloat,
        fill: NSColor = NSColor.white.withAlphaComponent(0.95),
        stroke: NSColor = accentGreen,
        in context: CGContext
    ) {
        guard let center else { return }
        drawHandleDot(at: center, size: size, fill: fill, stroke: stroke, in: context)
    }

    private static func drawHandleDot(
        at center: NSPoint,
        size: CGFloat,
        fill: NSColor,
        stroke: NSColor,
        in context: CGContext
    ) {
        let rect = NSRect(
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
        context.setFillColor(fill.cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(stroke.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: rect.insetBy(dx: 0.75, dy: 0.75))
    }

    private static func drawSymbolGlyph(
        _ symbolName: String,
        at center: NSPoint,
        pointSize: CGFloat,
        alpha: CGFloat = 1
    ) {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        guard let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(configuration) else {
            return
        }
        let tinted = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        let drawRect = NSRect(
            x: center.x - tinted.size.width / 2,
            y: center.y - tinted.size.height / 2,
            width: tinted.size.width,
            height: tinted.size.height
        )
        NSGraphicsContext.saveGraphicsState()
        tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: alpha)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawActionButton(
        in rect: NSRect,
        symbolName: String,
        symbolPointSize: CGFloat,
        enabled: Bool = true,
        in context: CGContext
    ) {
        let alpha: CGFloat = enabled ? 1 : 0.4
        drawHandleDot(
            at: NSPoint(x: rect.midX, y: rect.midY),
            size: rect.width,
            fill: NSColor(white: 0.12, alpha: 0.94 * alpha),
            stroke: accentGreen.withAlphaComponent(alpha),
            in: context
        )
        drawSymbolGlyph(
            symbolName,
            at: NSPoint(x: rect.midX, y: rect.midY),
            pointSize: symbolPointSize,
            alpha: alpha
        )
    }
}
