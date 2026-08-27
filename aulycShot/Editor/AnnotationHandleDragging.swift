import AppKit

/// Pure handle-drag policy for committed annotations. The canvas supplies
/// modifier state and the base image; this type owns the type-specific
/// mutation rules so event handling only manages interaction lifecycle.
enum AnnotationHandleDragging {
    struct Context {
        let canvasBounds: NSRect
        let shiftPressed: Bool
        let baseImage: NSImage?
    }

    static func transformedAnnotation(
        from original: Annotation,
        handle: AnnotationHitTesting.Handle,
        currentMouse: NSPoint,
        startAngle: CGFloat,
        startRotation: CGFloat,
        context: Context
    ) -> Annotation? {
        switch handle {
        case .rotate:
            let center = NSPoint(
                x: original.boundingRect.midX,
                y: original.boundingRect.midY
            )
            let currentAngle = atan2(currentMouse.y - center.y, currentMouse.x - center.x)
            var newRotation = startRotation + (currentAngle - startAngle)
            if context.shiftPressed {
                let step = CGFloat.pi / 12
                newRotation = (newRotation / step).rounded() * step
            }
            return original.withRotation(newRotation)

        case .curve:
            if let arrow = original as? ArrowAnnotation {
                let midpoint = arrow.defaultCurveMid
                let controlPoint = hypot(
                    currentMouse.x - midpoint.x,
                    currentMouse.y - midpoint.y
                ) < 4 ? nil : currentMouse
                return arrow.withControlPoint(controlPoint)
            }
            if let number = original as? NumberAnnotation,
               let midpoint = number.defaultCurveMid {
                let controlPoint = hypot(
                    currentMouse.x - midpoint.x,
                    currentMouse.y - midpoint.y
                ) < 4 ? nil : currentMouse
                return number.withControlPoint(controlPoint)
            }
            return nil

        case .tip:
            guard let number = original as? NumberAnnotation else { return nil }
            let distance = hypot(
                currentMouse.x - number.center.x,
                currentMouse.y - number.center.y
            )
            return number.withTip(
                distance < NumberAnnotation.arrowMinDistance ? nil : currentMouse
            )

        case .textCalloutTip:
            guard let text = original as? TextAnnotation, text.hasCallout else { return nil }
            let point = text.unrotate(currentMouse)
            if text.calloutBodyRect.insetBy(dx: -2, dy: -2).contains(point) {
                return text.withCalloutTip(nil)
            }
            let anchor = text.calloutAnchorPoint(for: point)
            let distance = hypot(point.x - anchor.x, point.y - anchor.y)
            return text.withCalloutTip(
                distance <= TextAnnotation.calloutArrowMinDistance ? nil : point
            )

        case .magnifierSource:
            guard let magnifier = original as? MagnifierAnnotation else { return nil }
            let point = EditorCanvasGeometry.clamped(currentMouse, to: context.canvasBounds)
            let distance = hypot(
                point.x - magnifier.center.x,
                point.y - magnifier.center.y
            )
            let source = distance < MagnifierAnnotation.sourceResetDistance ? nil : point
            return magnifier.withSourceCenter(source)

        case .arrowStart:
            if let arrow = original as? ArrowAnnotation {
                return arrow.withStartPoint(constrainedEndpoint(
                    currentMouse,
                    fixedPoint: arrow.endPoint,
                    shiftPressed: context.shiftPressed
                ))
            }
            if let line = original as? LineAnnotation {
                return line.withStartPoint(constrainedEndpoint(
                    currentMouse,
                    fixedPoint: line.endPoint,
                    shiftPressed: context.shiftPressed
                ))
            }
            return nil

        case .arrowEnd:
            if let arrow = original as? ArrowAnnotation {
                return arrow.withEndPoint(constrainedEndpoint(
                    currentMouse,
                    fixedPoint: arrow.startPoint,
                    shiftPressed: context.shiftPressed
                ))
            }
            if let line = original as? LineAnnotation {
                return line.withEndPoint(constrainedEndpoint(
                    currentMouse,
                    fixedPoint: line.startPoint,
                    shiftPressed: context.shiftPressed
                ))
            }
            return nil

        case .resize(let anchor):
            return resizedAnnotation(
                original,
                anchor: anchor,
                currentMouse: currentMouse,
                context: context
            )
        }
    }

    private static func constrainedEndpoint(
        _ currentMouse: NSPoint,
        fixedPoint: NSPoint,
        shiftPressed: Bool
    ) -> NSPoint {
        EditorCanvasGeometry.constrainedEndpoint(
            currentMouse,
            fixedPoint: fixedPoint,
            shiftPressed: shiftPressed
        )
    }

    private static func resizedAnnotation(
        _ original: Annotation,
        anchor: EditorCanvasGeometry.ResizeAnchor,
        currentMouse: NSPoint,
        context: Context
    ) -> Annotation? {
        if let magnifier = original as? MagnifierAnnotation {
            let radius = hypot(
                currentMouse.x - magnifier.center.x,
                currentMouse.y - magnifier.center.y
            )
            guard radius >= MagnifierAnnotation.minRadius else { return nil }
            return magnifier.withRadius(radius)
        }

        if let mosaic = original as? MosaicAnnotation {
            let newRect = EditorCanvasGeometry.resizedRect(
                from: mosaic.rect,
                anchor: anchor,
                currentMouse: currentMouse,
                minimumSize: 4,
                constraint: context.shiftPressed ? .preserveAspectRatio : .none
            )
            guard
                newRect.width >= 4,
                newRect.height >= 4,
                let baseImage = context.baseImage,
                let region = MosaicTool.createMosaicRegion(
                    rect: newRect,
                    imageSize: context.canvasBounds.size,
                    baseImage: baseImage,
                    blockSize: mosaic.blockSize
                )
            else { return nil }
            return MosaicAnnotation(
                rect: region.rect,
                pixelatedImage: region.pixelatedImage,
                blockSize: mosaic.blockSize
            )
        }

        if let rect = original as? RectAnnotation {
            let newRect = EditorCanvasGeometry.resizedRotatedRect(
                from: rect.rect,
                rotation: rect.rotation,
                anchor: anchor,
                currentMouse: currentMouse,
                minimumSize: 4,
                constraint: context.shiftPressed ? .square : .none
            )
            guard newRect.width >= 4, newRect.height >= 4 else { return nil }
            return RectAnnotation(
                rect: newRect,
                color: rect.color,
                lineWidth: rect.lineWidth,
                fillMode: rect.fillMode,
                strokeStyle: rect.strokeStyle,
                roughStyle: rect.roughStyle.tuned(for: newRect, lineWidth: rect.lineWidth),
                rotation: rect.rotation
            )
        }

        if let ellipse = original as? EllipseAnnotation {
            let newRect = EditorCanvasGeometry.resizedRotatedRect(
                from: ellipse.rect,
                rotation: ellipse.rotation,
                anchor: anchor,
                currentMouse: currentMouse,
                minimumSize: 4,
                constraint: context.shiftPressed ? .square : .none
            )
            guard newRect.width >= 4, newRect.height >= 4 else { return nil }
            return EllipseAnnotation(
                rect: newRect,
                color: ellipse.color,
                lineWidth: ellipse.lineWidth,
                fillMode: ellipse.fillMode,
                strokeStyle: ellipse.strokeStyle,
                roughStyle: ellipse.roughStyle.tuned(for: newRect, lineWidth: ellipse.lineWidth),
                rotation: ellipse.rotation
            )
        }

        if let image = original as? ImageAnnotation {
            let newRect = EditorCanvasGeometry.resizedRotatedRect(
                from: image.rect,
                rotation: image.rotation,
                anchor: anchor,
                currentMouse: currentMouse,
                minimumSize: 12,
                constraint: context.shiftPressed ? .preserveAspectRatio : .none
            )
            guard newRect.width >= 12, newRect.height >= 12 else { return nil }
            return image.withRect(newRect)
        }

        return nil
    }
}
