import AppKit

struct PinViewportGeometry: Equatable {
    let frame: NSRect
    let panOffset: NSPoint
}

enum PinZoom {
    static let minScale: CGFloat = 0.25
    static let maxScale: CGFloat = 5.0
    static let buttonStep: CGFloat = 0.1
    static let wheelSensitivity: CGFloat = 0.002
    static let expandedViewportScaleThreshold: CGFloat = 1.5
    static let expandedViewportWidthRatio: CGFloat = 0.5
    static let expandedViewportVerticalInset: CGFloat = 16
    static let viewportTransitionDuration: TimeInterval = 0.22
    static let viewportAnimationFrameInterval: TimeInterval = 1.0 / 60.0
    static let interactivePreviewMaxPixelDimension = 1280
    static let interactivePreviewEndDelay: TimeInterval = 0.1
    static let toolbarInset: CGFloat = 8
    static let navigatorScaleThreshold: CGFloat = 1.2
    static let navigatorGap: CGFloat = 8
    static let navigatorIdleHideDelay: TimeInterval = 0.8
    static let navigatorActivationDelay: TimeInterval = 0.4
    static let navigatorEntryTimeout: TimeInterval = 3.0
    static let toolbarAnimationDuration: TimeInterval = 0.16

    static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minScale), maxScale)
    }

    static func usesExpandedViewport(at scale: CGFloat) -> Bool {
        Int((scale * 100).rounded()) > Int((expandedViewportScaleThreshold * 100).rounded())
    }

    static func scaledImageSize(baseImageSize: NSSize, scale: CGFloat) -> NSSize {
        NSSize(
            width: max(1, floor(baseImageSize.width * scale)),
            height: max(1, floor(baseImageSize.height * scale))
        )
    }

    static func windowSize(
        baseImageSize: NSSize,
        scale: CGFloat,
        screenFrame: NSRect?,
        visibleFrame: NSRect?,
        toolbarVisible: Bool,
        toolbarMinimumSize: NSSize
    ) -> NSSize {
        guard baseImageSize.width > 0, baseImageSize.height > 0 else {
            return baseImageSize
        }

        if usesExpandedViewport(at: scale),
           let screenFrame,
           let visibleFrame {
            let constraintFrame = windowConstraintFrame(for: scale, visibleFrame: visibleFrame)
            return NSSize(
                width: floor(min(screenFrame.width * expandedViewportWidthRatio, constraintFrame.width)),
                height: floor(constraintFrame.height)
            )
        }

        let requestedViewportScale = min(scale, 1)
        let maximumViewportScale: CGFloat
        if let visibleSize = visibleFrame?.size {
            maximumViewportScale = min(
                visibleSize.width / baseImageSize.width,
                visibleSize.height / baseImageSize.height
            )
        } else {
            maximumViewportScale = requestedViewportScale
        }
        let viewportScale = min(requestedViewportScale, maximumViewportScale)
        let imageViewportSize = NSSize(
            width: baseImageSize.width * viewportScale,
            height: baseImageSize.height * viewportScale
        )
        guard toolbarVisible else { return imageViewportSize }

        let maximumHostSize = visibleFrame?.size ?? imageViewportSize
        return NSSize(
            width: min(max(imageViewportSize.width, toolbarMinimumSize.width), maximumHostSize.width),
            height: min(max(imageViewportSize.height, toolbarMinimumSize.height), maximumHostSize.height)
        )
    }

    static func windowConstraintFrame(for scale: CGFloat, visibleFrame: NSRect) -> NSRect {
        guard usesExpandedViewport(at: scale) else { return visibleFrame }

        let maximumInset = max(0, (visibleFrame.height - 1) / 2)
        let verticalInset = min(expandedViewportVerticalInset, maximumInset)
        return visibleFrame.insetBy(dx: 0, dy: verticalInset)
    }

    static func clampedWindowFrame(_ frame: NSRect, to constraintFrame: NSRect) -> NSRect {
        var clamped = frame
        let maxX = max(constraintFrame.minX, constraintFrame.maxX - clamped.width)
        let maxY = max(constraintFrame.minY, constraintFrame.maxY - clamped.height)
        clamped.origin.x = min(max(clamped.minX, constraintFrame.minX), maxX)
        clamped.origin.y = min(max(clamped.minY, constraintFrame.minY), maxY)
        return clamped
    }

    static func clampedPanOffset(
        _ offset: NSPoint,
        baseImageSize: NSSize,
        scale: CGFloat,
        viewportSize: NSSize,
        allowsEmptyViewportSpace: Bool
    ) -> NSPoint {
        let imageSize = scaledImageSize(baseImageSize: baseImageSize, scale: scale)
        let minimumX: CGFloat
        let maximumX: CGFloat
        if imageSize.width > viewportSize.width {
            minimumX = viewportSize.width - imageSize.width
            maximumX = 0
        } else if allowsEmptyViewportSpace {
            minimumX = 0
            maximumX = viewportSize.width - imageSize.width
        } else {
            minimumX = 0
            maximumX = 0
        }

        let minimumY: CGFloat
        let maximumY: CGFloat
        if imageSize.height > viewportSize.height {
            minimumY = 0
            maximumY = imageSize.height - viewportSize.height
        } else if allowsEmptyViewportSpace {
            minimumY = imageSize.height - viewportSize.height
            maximumY = 0
        } else {
            minimumY = 0
            maximumY = 0
        }
        return NSPoint(
            x: min(max(offset.x, minimumX), maximumX),
            y: min(max(offset.y, minimumY), maximumY)
        )
    }

    static func focusedPanOffset(
        on unitPoint: NSPoint,
        scale: CGFloat,
        baseImageSize: NSSize,
        viewportSize: NSSize,
        focusPoint: NSPoint?,
        allowsEmptyViewportSpace: Bool
    ) -> NSPoint {
        let imageSize = scaledImageSize(baseImageSize: baseImageSize, scale: scale)
        let targetPoint = focusPoint ?? NSPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let imagePoint = NSPoint(
            x: min(max(unitPoint.x, 0), 1) * imageSize.width,
            y: min(max(unitPoint.y, 0), 1) * imageSize.height
        )
        let proposed = NSPoint(
            x: targetPoint.x - imagePoint.x,
            y: targetPoint.y - imagePoint.y - viewportSize.height + imageSize.height
        )
        return clampedPanOffset(
            proposed,
            baseImageSize: baseImageSize,
            scale: scale,
            viewportSize: viewportSize,
            allowsEmptyViewportSpace: allowsEmptyViewportSpace
        )
    }

    static func adjustedFocusPoint(_ point: NSPoint?, by windowOriginDelta: NSPoint) -> NSPoint? {
        guard let point else { return nil }
        return NSPoint(x: point.x + windowOriginDelta.x, y: point.y + windowOriginDelta.y)
    }

    static func viewportGeometry(
        currentFrame: NSRect,
        currentPanOffset: NSPoint,
        targetSize: NSSize,
        baseImageSize: NSSize,
        scale: CGFloat,
        constraintFrame: NSRect?,
        allowsEmptyViewportSpace: Bool
    ) -> PinViewportGeometry {
        let imageScreenMinX = currentFrame.minX + currentPanOffset.x
        let imageScreenMaxY = currentFrame.maxY + currentPanOffset.y
        var targetPanOffset = clampedPanOffset(
            currentPanOffset,
            baseImageSize: baseImageSize,
            scale: scale,
            viewportSize: targetSize,
            allowsEmptyViewportSpace: allowsEmptyViewportSpace
        )
        var targetFrame = NSRect(
            x: imageScreenMinX - targetPanOffset.x,
            y: imageScreenMaxY - targetPanOffset.y - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )

        if let constraintFrame {
            targetFrame = clampedWindowFrame(targetFrame, to: constraintFrame)
            targetPanOffset = clampedPanOffset(
                NSPoint(
                    x: imageScreenMinX - targetFrame.minX,
                    y: imageScreenMaxY - targetFrame.maxY
                ),
                baseImageSize: baseImageSize,
                scale: scale,
                viewportSize: targetSize,
                allowsEmptyViewportSpace: allowsEmptyViewportSpace
            )
        }

        return PinViewportGeometry(frame: targetFrame, panOffset: targetPanOffset)
    }
}
