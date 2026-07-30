import AppKit
import ApplicationServices

final class AccessibilityElementDetector {
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let fallbackBundleIdentifiers = ["com.apple.finder", "com.apple.dock"]

    func elementCandidates(
        at point: CGPoint,
        preferredPID: pid_t?,
        screenFrame: CGRect
    ) -> [SmartSelectionCandidate] {
        guard AXIsProcessTrusted() else { return [] }

        for pid in candidatePIDs(preferredPID: preferredPID) where pid != ownPID {
            let candidates = candidates(at: point, in: pid, screenFrame: screenFrame)
            if !candidates.isEmpty {
                return candidates
            }
        }
        return []
    }

    private func candidatePIDs(preferredPID: pid_t?) -> [pid_t] {
        if let preferredPID {
            return [preferredPID]
        }

        var seen = Set<pid_t>()
        var pids: [pid_t] = []
        for bundleIdentifier in fallbackBundleIdentifiers {
            for application in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
                let pid = application.processIdentifier
                if seen.insert(pid).inserted {
                    pids.append(pid)
                }
            }
        }
        return pids
    }

    private func candidates(
        at point: CGPoint,
        in pid: pid_t,
        screenFrame: CGRect
    ) -> [SmartSelectionCandidate] {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.08)

        var hitElement: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            application,
            Float(point.x),
            Float(point.y),
            &hitElement
        )
        guard error == .success, let hitElement else { return [] }

        var candidates: [SmartSelectionCandidate] = []
        var current: AXUIElement? = hitElement
        for _ in 0..<8 {
            guard let element = current else { break }
            let role = stringAttribute(kAXRoleAttribute as CFString, from: element)
            if role == "AXWindow" || role == "AXApplication" || role == "AXSystemWide" {
                break
            }
            if SmartSelectionPolicy.isMeaningfulAccessibilityRole(role),
               let frame = frame(of: element),
               frame.width >= SmartSelectionPolicy.minimumRegionWidth,
               frame.height >= SmartSelectionPolicy.minimumRegionHeight,
               frame.contains(point),
               frame.intersects(screenFrame) {
                candidates.append(SmartSelectionCandidate(
                    kind: .element,
                    frame: frame.intersection(screenFrame),
                    ownerPID: pid,
                    role: role
                ))
            }
            current = elementAttribute(kAXParentAttribute as CFString, from: element)
        }
        return candidates
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = valueAttribute(kAXPositionAttribute as CFString, from: element),
              let sizeValue = valueAttribute(kAXSizeAttribute as CFString, from: element),
              AXValueGetType(positionValue) == .cgPoint,
              AXValueGetType(sizeValue) == .cgSize
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }

        return CGRect(origin: position, size: size).standardized
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func valueAttribute(_ attribute: CFString, from element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        return (value as! AXValue)
    }

    private func elementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }
}
