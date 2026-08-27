import AppKit

enum AnnotationHitTesting {
    enum SelectionAction: Equatable {
        case delete
        case edit
        case incrementNumber
        case decrementNumber
        case zoomInMagnifier
        case zoomOutMagnifier
    }

    enum Handle: Equatable {
        case rotate
        case curve
        case tip
        case textCalloutTip
        case magnifierSource
        case arrowStart
        case arrowEnd
        case resize(EditorCanvasGeometry.ResizeAnchor)
    }

    enum ChromeHit: Equatable {
        case action(SelectionAction)
        case handle(Handle)
    }

    /// Returns the topmost annotation index in the existing array model.
    static func topmostIndex(at point: NSPoint, in annotations: [Annotation]) -> Int? {
        annotations.indices.reversed().first { annotations[$0].containsPoint(point) }
    }

    /// Single entry point for selection chrome hit testing. Action buttons
    /// win over drag handles because both can extend beyond the annotation's
    /// body and mouse-down dispatch must make the same precedence decision as
    /// cursor updates and NSView hit routing.
    static func chromeHit(
        at point: NSPoint,
        for annotation: Annotation,
        includeActions: Bool = true
    ) -> ChromeHit? {
        if includeActions, let action = selectionAction(at: point, for: annotation) {
            return .action(action)
        }
        if let handle = selectionHandle(at: point, for: annotation) {
            return .handle(handle)
        }
        return nil
    }

    private static func selectionAction(
        at point: NSPoint,
        for annotation: Annotation
    ) -> SelectionAction? {
        if AnnotationHandlePolicy.deleteButtonRect(for: annotation).contains(point) {
            return .delete
        }
        if let editRect = AnnotationHandlePolicy.editButtonRect(for: annotation),
           editRect.contains(point) {
            return .edit
        }
        if let decrementRect = AnnotationHandlePolicy.numberStepButtonRect(
            for: annotation,
            increment: false
        ),
           decrementRect.contains(point) {
            return .decrementNumber
        }
        if let incrementRect = AnnotationHandlePolicy.numberStepButtonRect(
            for: annotation,
            increment: true
        ),
           incrementRect.contains(point) {
            return .incrementNumber
        }
        if let decrementRect = AnnotationHandlePolicy.magnifierZoomButtonRect(
            for: annotation,
            increment: false
        ),
           decrementRect.contains(point) {
            return .zoomOutMagnifier
        }
        if let incrementRect = AnnotationHandlePolicy.magnifierZoomButtonRect(
            for: annotation,
            increment: true
        ),
           incrementRect.contains(point) {
            return .zoomInMagnifier
        }
        return nil
    }

    private static func selectionHandle(
        at point: NSPoint,
        for annotation: Annotation
    ) -> Handle? {
        if let source = AnnotationHandlePolicy.magnifierSourceHandleCenter(for: annotation),
           AnnotationHandlePolicy.contains(
               point,
               around: source,
               handleSize: AnnotationHandlePolicy.magnifierSourceHandleSize,
               hitSlop: 5
           ) {
            return .magnifierSource
        }

        // Resize grips must beat body drags on the same pixels.
        if AnnotationHandlePolicy.isResizable(annotation) {
            for anchor in EditorCanvasGeometry.ResizeAnchor.allCases {
                let center = AnnotationHandlePolicy.resizeHandlePoint(anchor, for: annotation)
                if AnnotationHandlePolicy.contains(
                    point,
                    around: center,
                    handleSize: AnnotationHandlePolicy.resizeHandleSize,
                    hitSlop: 4
                ) {
                    return .resize(anchor)
                }
            }
        }

        if annotation.supportsRotation {
            let center = AnnotationHandlePolicy.rotationHandleCenter(for: annotation)
            if AnnotationHandlePolicy.contains(
                point,
                around: center,
                handleSize: AnnotationHandlePolicy.rotateHandleSize,
                hitSlop: 2
            ) {
                return .rotate
            }
        }

        // The visible tip and endpoints are more salient than a nearby curve
        // grip, so they retain their historic precedence.
        if let tip = AnnotationHandlePolicy.tipHandleCenter(for: annotation),
           AnnotationHandlePolicy.contains(
               point,
               around: tip,
               handleSize: AnnotationHandlePolicy.tipHandleSize,
               hitSlop: 4
           ) {
            return .tip
        }
        if let tip = AnnotationHandlePolicy.textCalloutHandleCenter(for: annotation),
           AnnotationHandlePolicy.contains(
               point,
               around: tip,
               handleSize: AnnotationHandlePolicy.textCalloutHandleSize,
               hitSlop: 4
           ) {
            return .textCalloutTip
        }
        if let end = AnnotationHandlePolicy.arrowEndHandleCenter(for: annotation),
           AnnotationHandlePolicy.contains(
               point,
               around: end,
               handleSize: AnnotationHandlePolicy.endpointHandleSize,
               hitSlop: 4
           ) {
            return .arrowEnd
        }
        if let start = AnnotationHandlePolicy.arrowStartHandleCenter(for: annotation),
           AnnotationHandlePolicy.contains(
               point,
               around: start,
               handleSize: AnnotationHandlePolicy.endpointHandleSize,
               hitSlop: 4
           ) {
            return .arrowStart
        }
        if let controlPoint = AnnotationHandlePolicy.curveHandleCenter(for: annotation),
           AnnotationHandlePolicy.contains(
               point,
               around: controlPoint,
               handleSize: AnnotationHandlePolicy.curveHandleSize,
               hitSlop: 4
           ) {
            return .curve
        }
        return nil
    }
}

enum AnnotationHandlePolicy {
    static let rotateHandleSize: CGFloat = 22
    static let rotateHandleOffset: CGFloat = 22
    static let curveHandleSize: CGFloat = 14
    static let tipHandleSize: CGFloat = 14
    static let textCalloutHandleSize: CGFloat = 13
    static let magnifierSourceHandleSize: CGFloat = 14
    static let endpointHandleSize: CGFloat = 12
    static let resizeHandleSize: CGFloat = 10
    static let actionButtonSize: CGFloat = 22
    static let numberStepButtonSize: CGFloat = 20
    static let selectionBoxPadding: CGFloat = 6

    static func selectionBox(for annotation: Annotation) -> NSRect {
        EditorCanvasGeometry.selectionBox(
            boundingRect: annotation.boundingRect,
            padding: selectionBoxPadding
        )
    }

    static func rotated(_ point: NSPoint, for annotation: Annotation) -> NSPoint {
        EditorCanvasGeometry.rotated(
            point,
            around: annotation.boundingRect,
            rotation: annotation.supportsRotation ? annotation.rotation : 0
        )
    }

    static func rotationHandleCenter(for annotation: Annotation) -> NSPoint {
        let box = selectionBox(for: annotation)
        return rotated(
            NSPoint(x: box.midX, y: box.maxY + rotateHandleOffset),
            for: annotation
        )
    }

    static func rotationTetherAnchor(for annotation: Annotation) -> NSPoint {
        let box = selectionBox(for: annotation)
        return rotated(NSPoint(x: box.midX, y: box.maxY + 2), for: annotation)
    }

    static func curveHandleCenter(for annotation: Annotation) -> NSPoint? {
        if let arrow = annotation as? ArrowAnnotation {
            return arrow.curveHandlePoint
        }
        if let number = annotation as? NumberAnnotation {
            return number.curveHandlePoint
        }
        return nil
    }

    static func tipHandleCenter(for annotation: Annotation) -> NSPoint? {
        guard let number = annotation as? NumberAnnotation else { return nil }
        return number.tip ?? NSPoint(
            x: number.center.x,
            y: number.center.y + NumberAnnotation.arrowMinDistance + 4
        )
    }

    static func textCalloutHandleCenter(for annotation: Annotation) -> NSPoint? {
        guard let text = annotation as? TextAnnotation, text.hasCallout else { return nil }
        return rotated(text.calloutHandlePoint, for: annotation)
    }

    static func magnifierSourceHandleCenter(for annotation: Annotation) -> NSPoint? {
        guard let magnifier = annotation as? MagnifierAnnotation else { return nil }
        return magnifier.sourceCenter ?? magnifier.center
    }

    static func arrowStartHandleCenter(for annotation: Annotation) -> NSPoint? {
        if let arrow = annotation as? ArrowAnnotation { return arrow.startPoint }
        if let line = annotation as? LineAnnotation { return line.startPoint }
        return nil
    }

    static func arrowEndHandleCenter(for annotation: Annotation) -> NSPoint? {
        if let arrow = annotation as? ArrowAnnotation { return arrow.endPoint }
        if let line = annotation as? LineAnnotation { return line.endPoint }
        return nil
    }

    static func deleteButtonRect(for annotation: Annotation) -> NSRect {
        let topRight = rotated(
            NSPoint(x: selectionBox(for: annotation).maxX, y: selectionBox(for: annotation).maxY),
            for: annotation
        )
        return NSRect(
            x: topRight.x + 4,
            y: topRight.y - actionButtonSize,
            width: actionButtonSize,
            height: actionButtonSize
        )
    }

    static func editButtonRect(for annotation: Annotation) -> NSRect? {
        guard annotation is TextAnnotation else { return nil }
        let box = selectionBox(for: annotation)
        let topRight = rotated(NSPoint(x: box.maxX, y: box.maxY), for: annotation)
        return NSRect(
            x: topRight.x + 4,
            y: topRight.y - actionButtonSize * 2 - 4,
            width: actionButtonSize,
            height: actionButtonSize
        )
    }

    static func numberStepButtonRect(
        for annotation: Annotation,
        increment: Bool
    ) -> NSRect? {
        guard let number = annotation as? NumberAnnotation else { return nil }
        let size = numberStepButtonSize
        let gap: CGFloat = 4
        let centerY = number.center.y - NumberAnnotation.radius - 7 - size / 2
        let centerX = increment
            ? number.center.x + gap / 2 + size / 2
            : number.center.x - gap / 2 - size / 2
        return NSRect(x: centerX - size / 2, y: centerY - size / 2, width: size, height: size)
    }

    static func magnifierZoomButtonRect(
        for annotation: Annotation,
        increment: Bool
    ) -> NSRect? {
        guard let magnifier = annotation as? MagnifierAnnotation else { return nil }
        let size = numberStepButtonSize
        let gap: CGFloat = 4
        let centerY = magnifier.center.y - magnifier.radius - 9 - size / 2
        let centerX = increment
            ? magnifier.center.x + gap / 2 + size / 2
            : magnifier.center.x - gap / 2 - size / 2
        return NSRect(x: centerX - size / 2, y: centerY - size / 2, width: size, height: size)
    }

    static func isResizable(_ annotation: Annotation) -> Bool {
        annotation is RectAnnotation
            || annotation is EllipseAnnotation
            || annotation is MosaicAnnotation
            || annotation is MagnifierAnnotation
            || annotation is ImageAnnotation
    }

    static func resizeHandlePoint(
        _ anchor: EditorCanvasGeometry.ResizeAnchor,
        for annotation: Annotation
    ) -> NSPoint {
        EditorCanvasGeometry.resizeHandlePoint(
            anchor,
            boundingRect: annotation.boundingRect,
            rotation: annotation.supportsRotation ? annotation.rotation : 0
        )
    }

    static func contains(
        _ point: NSPoint,
        around center: NSPoint,
        handleSize: CGFloat,
        hitSlop: CGFloat
    ) -> Bool {
        hypot(point.x - center.x, point.y - center.y) <= handleSize / 2 + hitSlop
    }
}
