import AppKit

enum AnnotationHitTesting {
    /// Returns the topmost annotation index in the existing array model.
    static func topmostIndex(at point: NSPoint, in annotations: [Annotation]) -> Int? {
        annotations.indices.reversed().first { annotations[$0].containsPoint(point) }
    }
}
