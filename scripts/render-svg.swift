import AppKit
import Foundation

guard CommandLine.arguments.count == 4,
      let outputSize = Int(CommandLine.arguments[3]),
      outputSize > 0 else {
    FileHandle.standardError.write(Data("usage: render-svg.swift <input.svg> <output.png> <size>\n".utf8))
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let image = NSImage(contentsOf: inputURL) else {
    FileHandle.standardError.write(Data("error: unable to load SVG\n".utf8))
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: outputSize,
    pixelsHigh: outputSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("error: unable to create bitmap canvas\n".utf8))
    exit(1)
}

bitmap.size = NSSize(width: outputSize, height: outputSize)
NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    NSGraphicsContext.restoreGraphicsState()
    FileHandle.standardError.write(Data("error: unable to create drawing context\n".utf8))
    exit(1)
}

NSGraphicsContext.current = context
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: outputSize, height: outputSize).fill()
image.draw(
    in: NSRect(x: 0, y: 0, width: outputSize, height: outputSize),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("error: unable to encode PNG\n".utf8))
    exit(1)
}

do {
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write(Data("error: unable to write PNG\n".utf8))
    exit(1)
}
