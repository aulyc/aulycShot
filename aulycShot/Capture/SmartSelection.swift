import CoreGraphics
import Darwin

struct SmartSelectionCandidate: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
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
    private(set) var hasManuallyCycledCandidate = false

    var currentCandidate: SmartSelectionCandidate? {
        guard candidates.indices.contains(currentIndex) else { return nil }
        return candidates[currentIndex]
    }

    var isEmpty: Bool {
        candidates.isEmpty
    }

    mutating func replaceCandidates(
        _ newCandidates: [SmartSelectionCandidate],
        preservingCurrent: Bool = true
    ) {
        let previous = preservingCurrent ? currentCandidate : nil
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
        hasManuallyCycledCandidate = true
    }

    mutating func resetManualCycle() {
        hasManuallyCycledCandidate = false
    }

    mutating func clear() {
        candidates.removeAll()
        currentIndex = 0
        hasManuallyCycledCandidate = false
    }
}

enum SmartSelectionPolicy {
    static let minimumRegionWidth: CGFloat = 120
    static let minimumRegionHeight: CGFloat = 80
    static let minimumRegionAreaRatio: CGFloat = 0.01
    static let maximumRegionAreaRatio: CGFloat = 0.9

    private static let regionAccessibilityRoles: Set<String> = [
        "AXBrowser",
        "AXDialog",
        "AXGroup",
        "AXList",
        "AXMenu",
        "AXOutline",
        "AXPopover",
        "AXScrollArea",
        "AXSheet",
        "AXSplitGroup",
        "AXTabGroup",
        "AXTable",
        "AXToolbar",
        "AXWebArea",
    ]

    static func isMeaningfulAccessibilityRole(_ role: String?) -> Bool {
        guard let role else { return false }
        return regionAccessibilityRoles.contains(role)
    }

    static func orderedCandidates(
        elements: [SmartSelectionCandidate],
        window: SmartSelectionCandidate?,
        screen: SmartSelectionCandidate,
        at point: CGPoint
    ) -> [SmartSelectionCandidate] {
        guard isUsable(screen), screen.frame.contains(point) else { return [] }

        var candidates: [SmartSelectionCandidate] = []
        let referenceFrame = window?.frame ?? screen.frame

        if let element = preferredRegionCandidate(
            from: elements,
            referenceFrame: referenceFrame,
            windowFrame: window?.frame,
            screenFrame: screen.frame,
            at: point
        ) {
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

    static func hoverBorderRect(
        candidateRect: CGRect,
        drawableBounds: CGRect,
        lineWidth: CGFloat
    ) -> CGRect? {
        let visibleRect = candidateRect.standardized.intersection(drawableBounds.standardized)
        guard !visibleRect.isNull,
              visibleRect.width > 0,
              visibleRect.height > 0,
              lineWidth.isFinite,
              lineWidth >= 0 else {
            return nil
        }

        let borderRect = visibleRect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        guard borderRect.width > 0, borderRect.height > 0 else { return nil }
        return borderRect
    }

    private static func preferredRegionCandidate(
        from elements: [SmartSelectionCandidate],
        referenceFrame: CGRect,
        windowFrame: CGRect?,
        screenFrame: CGRect,
        at point: CGPoint
    ) -> SmartSelectionCandidate? {
        var preferred: SmartSelectionCandidate?

        for element in elements {
            guard isUsableRegion(element, relativeTo: referenceFrame),
                  element.frame.contains(point),
                  element.frame.intersects(screenFrame),
                  windowFrame.map({ !approximatelyEqual(element.frame, $0) }) ?? true
            else { continue }

            if let current = preferred,
               current.frame.width * current.frame.height >= element.frame.width * element.frame.height {
                continue
            }
            preferred = element
        }

        return preferred
    }

    private static func isUsableRegion(
        _ candidate: SmartSelectionCandidate,
        relativeTo referenceFrame: CGRect
    ) -> Bool {
        guard isMeaningfulAccessibilityRole(candidate.role),
              candidate.frame.width >= minimumRegionWidth,
              candidate.frame.height >= minimumRegionHeight,
              isUsable(candidate),
              referenceFrame.width.isFinite,
              referenceFrame.height.isFinite
        else { return false }

        let referenceArea = referenceFrame.width * referenceFrame.height
        guard referenceArea.isFinite, referenceArea > 1 else { return false }

        let areaRatio = candidate.frame.width * candidate.frame.height / referenceArea
        return areaRatio >= minimumRegionAreaRatio
            && areaRatio <= maximumRegionAreaRatio
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
