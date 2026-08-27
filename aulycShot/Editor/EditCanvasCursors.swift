import AppKit

@MainActor
enum EditCanvasCursors {
    static let magnifierCursor: NSCursor = {
        let size: CGFloat = 28
        let lensCenter = NSPoint(x: 11, y: 17)
        let lensRadius: CGFloat = 7

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let lens = NSBezierPath(ovalIn: NSRect(
                x: lensCenter.x - lensRadius,
                y: lensCenter.y - lensRadius,
                width: lensRadius * 2,
                height: lensRadius * 2
            ))

            // Handle — from the lens's lower-right edge toward the corner.
            let diag = CGFloat(2).squareRoot() / 2
            let handleStart = NSPoint(
                x: lensCenter.x + lensRadius * diag,
                y: lensCenter.y - lensRadius * diag
            )
            let handle = NSBezierPath()
            handle.lineCapStyle = .round
            handle.move(to: handleStart)
            handle.line(to: NSPoint(x: handleStart.x + 7.5, y: handleStart.y - 7.5))

            // "+" inside the lens, echoing the toolbar icon.
            let arm: CGFloat = 3.4
            let plus = NSBezierPath()
            plus.lineCapStyle = .round
            plus.move(to: NSPoint(x: lensCenter.x - arm, y: lensCenter.y))
            plus.line(to: NSPoint(x: lensCenter.x + arm, y: lensCenter.y))
            plus.move(to: NSPoint(x: lensCenter.x, y: lensCenter.y - arm))
            plus.line(to: NSPoint(x: lensCenter.x, y: lensCenter.y + arm))

            // Dark halo pass — fatter strokes underneath for contrast.
            NSColor.black.withAlphaComponent(0.55).setStroke()
            lens.lineWidth = 5;   lens.stroke()
            handle.lineWidth = 7; handle.stroke()
            plus.lineWidth = 4;   plus.stroke()

            // White body pass.
            NSColor.white.setStroke()
            lens.lineWidth = 2;     lens.stroke()
            handle.lineWidth = 3.5; handle.stroke()
            plus.lineWidth = 1.8;   plus.stroke()
            return true
        }
        return NSCursor(
            image: image,
            hotSpot: NSPoint(x: lensCenter.x, y: size - lensCenter.y)
        )
    }()

    static let eraserCursor: NSCursor = {
        let size: CGFloat = 28
        let center = NSPoint(x: 14, y: 14)

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let transform = NSAffineTransform()
            transform.translateX(by: center.x, yBy: center.y)
            transform.rotate(byDegrees: -35)
            transform.translateX(by: -center.x, yBy: -center.y)

            NSGraphicsContext.saveGraphicsState()
            transform.concat()

            let bodyRect = NSRect(x: 7, y: 9, width: 16, height: 10)
            let body = NSBezierPath(roundedRect: bodyRect, xRadius: 3, yRadius: 3)

            NSColor.black.withAlphaComponent(0.55).setStroke()
            body.lineWidth = 5
            body.stroke()

            NSColor.white.setFill()
            body.fill()

            NSColor.systemRed.withAlphaComponent(0.95).setFill()
            NSBezierPath(roundedRect: NSRect(x: 7, y: 9, width: 7, height: 10), xRadius: 3, yRadius: 3).fill()

            let divider = NSBezierPath()
            divider.move(to: NSPoint(x: 14, y: 10))
            divider.line(to: NSPoint(x: 14, y: 18))
            NSColor.black.withAlphaComponent(0.28).setStroke()
            divider.lineWidth = 1
            divider.stroke()

            NSColor.white.withAlphaComponent(0.95).setStroke()
            body.lineWidth = 1.5
            body.stroke()

            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: center.x, y: size - center.y))
    }()

}
