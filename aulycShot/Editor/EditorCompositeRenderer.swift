import AppKit

enum EditorCompositeRenderer {
    static func compositeImage(
        baseImage: NSImage,
        annotations: [Annotation],
        annotationBounds: NSRect,
        annotationClipMask: NSImage?
    ) -> NSImage {
        guard !annotations.isEmpty,
              let compositeRep = makeBitmapRep(matching: baseImage),
              let graphicsContext = NSGraphicsContext(bitmapImageRep: compositeRep)
        else {
            return baseImage
        }

        let imageBounds = NSRect(origin: .zero, size: baseImage.size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        graphicsContext.imageInterpolation = .high
        baseImage.draw(
            in: imageBounds,
            from: NSRect(origin: .zero, size: baseImage.size),
            operation: .copy,
            fraction: 1.0
        )

        let context = graphicsContext.cgContext
        if let annotationClipMask {
            _ = WindowEffects.clip(context, toAlphaOf: annotationClipMask, in: imageBounds)
        }
        context.saveGState()
        if annotationBounds.width > 0, annotationBounds.height > 0 {
            context.scaleBy(
                x: imageBounds.width / annotationBounds.width,
                y: imageBounds.height / annotationBounds.height
            )
        }
        for annotation in annotations {
            annotation.drawApplyingTransforms(in: context, bounds: annotationBounds)
        }
        context.restoreGState()
        graphicsContext.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let merged = NSImage(size: baseImage.size)
        merged.addRepresentation(compositeRep)
        return merged
    }

    private static func makeBitmapRep(matching image: NSImage) -> NSBitmapImageRep? {
        guard let cgImage = image.cgImagePreservingBacking() else { return nil }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: cgImage.width,
            pixelsHigh: cgImage.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        rep?.size = image.size
        return rep
    }
}
