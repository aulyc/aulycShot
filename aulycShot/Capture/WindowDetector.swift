import AppKit
import CoreGraphics

struct DetectedWindow: Sendable {
    let name: String
    let windowID: CGWindowID
    let ownerPID: pid_t
    let layer: Int
    let frame: CGRect   // CG coordinates (global, top-left origin)

    var usesCompositedScreenBackdrop: Bool {
        layer >= 20
    }
}

final class WindowDetector: @unchecked Sendable {
    private var windows: [DetectedWindow] = []
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let accessibilityDetector = AccessibilityElementDetector()
    private let accessibilityQueue = DispatchQueue(
        label: "com.aulyc.aulycshot.smart-selection",
        qos: .userInteractive
    )
    private let requestLock = NSLock()
    private var requestGeneration = 0

    /// Snapshot all visible windows (excluding this app).
    func refresh() {
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            windows = []
            return
        }

        let primaryFrame = NSScreen.screens[0].frame
        let screenArea = primaryFrame.width * primaryFrame.height

        windows = infoList.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsNS = info[kCGWindowBounds as String] as? NSDictionary,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer >= 0
            else { return nil }

            // Keep this app's own menus/popups detectable so aulycShot can capture
            // its visible transient UI. Only screen-saver-level chrome (toasts,
            // tooltips and progress panels) is excluded.
            // The capture overlay itself is created after refresh(), so it is
            // never in this snapshot.
            if pid == ownPID && layer >= Int(CGWindowLevelForKey(.screenSaverWindow)) {
                return nil
            }

            // Skip fully transparent windows (invisible system overlays)
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha <= 0 {
                return nil
            }

            var rect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsNS as CFDictionary, &rect) else { return nil }
            guard rect.width > 1, rect.height > 1 else { return nil }

            // For windows above normal app levels (dock, menu bar, popups, etc.),
            // skip near-full-screen ones — these are typically invisible system
            // overlays (e.g. input method backgrounds) that block real windows.
            if layer >= 20 {
                if rect.width * rect.height > screenArea * 0.8 {
                    return nil
                }
            }

            let name = info[kCGWindowOwnerName as String] as? String ?? ""
            let windowID = info[kCGWindowNumber as String] as? CGWindowID ?? 0

            return DetectedWindow(
                name: name,
                windowID: windowID,
                ownerPID: pid,
                layer: layer,
                frame: rect
            )
        }
    }

    /// High-layer system surfaces (menu bar, Dock, popups) are often only a
    /// translucent foreground when captured as independent windows. Capture
    /// their already-composited screen pixels instead.
    func usesCompositedScreenBackdrop(forWindowID windowID: CGWindowID) -> Bool {
        windows.first { $0.windowID == windowID }?.usesCompositedScreenBackdrop ?? false
    }

    /// Return the topmost window whose frame contains `cgPoint`
    /// (CG coordinates: origin at top-left of primary display, y increases downward).
    func windowAt(cgPoint: CGPoint) -> DetectedWindow? {
        // CGWindowListCopyWindowInfo returns windows in front-to-back z-order,
        // so the first hit is the topmost window.
        return windows.first { $0.frame.contains(cgPoint) }
    }

    func baseCandidates(
        at cgPoint: CGPoint,
        screenFrame: CGRect,
        displayID: CGDirectDisplayID
    ) -> [SmartSelectionCandidate] {
        let detectedWindow = windowAt(cgPoint: cgPoint)
        let windowCandidate = detectedWindow.map {
            SmartSelectionCandidate(
                kind: .window($0.windowID),
                frame: $0.frame,
                ownerPID: $0.ownerPID
            )
        }
        let screenCandidate = SmartSelectionCandidate(
            kind: .screen(displayID),
            frame: screenFrame
        )
        return SmartSelectionPolicy.orderedCandidates(
            elements: [],
            window: windowCandidate,
            screen: screenCandidate,
            at: cgPoint
        )
    }

    func requestCandidates(
        at cgPoint: CGPoint,
        screenFrame: CGRect,
        displayID: CGDirectDisplayID,
        completion: @escaping @MainActor @Sendable ([SmartSelectionCandidate]) -> Void
    ) {
        guard screenFrame.contains(cgPoint), AXIsProcessTrusted() else { return }

        let detectedWindow = windowAt(cgPoint: cgPoint)
        let windowCandidate = detectedWindow.map {
            SmartSelectionCandidate(
                kind: .window($0.windowID),
                frame: $0.frame,
                ownerPID: $0.ownerPID
            )
        }
        let screenCandidate = SmartSelectionCandidate(
            kind: .screen(displayID),
            frame: screenFrame
        )
        let preferredPID = detectedWindow?.ownerPID
        let generation = beginCandidateRequest()

        accessibilityQueue.asyncAfter(deadline: .now() + .milliseconds(24)) { [weak self] in
            guard let self, self.isCurrentCandidateRequest(generation) else { return }
            let elementCandidates = self.accessibilityDetector.elementCandidates(
                at: cgPoint,
                preferredPID: preferredPID,
                screenFrame: screenFrame
            )
            guard self.isCurrentCandidateRequest(generation) else { return }

            let candidates = SmartSelectionPolicy.orderedCandidates(
                elements: elementCandidates,
                window: windowCandidate,
                screen: screenCandidate,
                at: cgPoint
            )
            Task { @MainActor [weak self] in
                guard let self, self.isCurrentCandidateRequest(generation) else { return }
                completion(candidates)
            }
        }
    }

    private func beginCandidateRequest() -> Int {
        requestLock.lock()
        defer { requestLock.unlock() }
        requestGeneration &+= 1
        return requestGeneration
    }

    private func isCurrentCandidateRequest(_ generation: Int) -> Bool {
        requestLock.lock()
        defer { requestLock.unlock() }
        return requestGeneration == generation
    }
}
