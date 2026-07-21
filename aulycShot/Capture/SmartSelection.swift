import CoreGraphics
import Darwin

struct SmartSelectionCandidate: Equatable {
    enum Kind: Equatable {
        case element
        case window(CGWindowID)
        case screen(CGDirectDisplayID)
    }

    let kind: Kind
    let frame: CGRect
    let ownerPID: pid_t?
    let role: String?

    init(
        kind: Kind,
        frame: CGRect,
        ownerPID: pid_t? = nil,
        role: String? = nil
    ) {
        self.kind = kind
        self.frame = frame.standardized
        self.ownerPID = ownerPID
        self.role = role
    }

    var windowID: CGWindowID? {
        guard case .window(let windowID) = kind else { return nil }
        return windowID
    }

    var isWindowSelection: Bool {
        windowID != nil
    }
}

struct SmartSelectionHoverState {
    private(set) var candidates: [SmartSelectionCandidate] = []
    private(set) var currentIndex = 0

    var currentCandidate: SmartSelectionCandidate? {
        guard candidates.indices.contains(currentIndex) else { return nil }
        return candidates[currentIndex]
    }

    var isEmpty: Bool {
        candidates.isEmpty
    }

    mutating func replaceCandidates(_ newCandidates: [SmartSelectionCandidate]) {
        let previous = currentCandidate
        candidates = newCandidates
        if let previous,
           let preservedIndex = newCandidates.firstIndex(of: previous) {
            currentIndex = preservedIndex
        } else {
            currentIndex = 0
        }
    }

    mutating func cycle(reverse: Bool) {
        currentIndex = SmartSelectionPolicy.cycledIndex(
            current: currentIndex,
            count: candidates.count,
            reverse: reverse
        )
    }

    mutating func clear() {
        candidates.removeAll()
        currentIndex = 0
    }
}

enum SmartSelectionPolicy {
    static let minimumElementDimension: CGFloat = 8

    static func isMeaningfulAccessibilityRole(_ role: String?) -> Bool {
        guard let role, !role.isEmpty else { return false }
        switch role {
        case "AXApplication", "AXWindow", "AXSystemWide", "AXUnknown":
            return false
        default:
            return true
        }
    }

    static func orderedCandidates(
        element: SmartSelectionCandidate?,
        window: SmartSelectionCandidate?,
        screen: SmartSelectionCandidate,
        at point: CGPoint
    ) -> [SmartSelectionCandidate] {
        guard isUsable(screen), screen.frame.contains(point) else { return [] }

        var candidates: [SmartSelectionCandidate] = []

        if let element,
           isUsableElement(element),
           element.frame.contains(point),
           element.frame.intersects(screen.frame),
           window.map({ !approximatelyEqual(element.frame, $0.frame) }) ?? true {
            candidates.append(element)
        }

        if let window,
           isUsable(window),
           window.frame.contains(point),
           window.frame.intersects(screen.frame) {
            candidates.append(window)
        }

        candidates.append(screen)
        return candidates
    }

    static func cycledIndex(current: Int, count: Int, reverse: Bool) -> Int {
        guard count > 0 else { return 0 }
        let normalized = ((current % count) + count) % count
        return reverse
            ? (normalized - 1 + count) % count
            : (normalized + 1) % count
    }

    private static func isUsableElement(_ candidate: SmartSelectionCandidate) -> Bool {
        candidate.frame.width >= minimumElementDimension
            && candidate.frame.height >= minimumElementDimension
            && isUsable(candidate)
    }

    private static func isUsable(_ candidate: SmartSelectionCandidate) -> Bool {
        candidate.frame.width.isFinite
            && candidate.frame.height.isFinite
            && candidate.frame.minX.isFinite
            && candidate.frame.minY.isFinite
            && candidate.frame.width > 1
            && candidate.frame.height > 1
    }

    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let tolerance: CGFloat = 1
        return abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
