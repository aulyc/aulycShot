import AppKit
import Carbon

enum EditorKeyboardShortcut {
    case select
    case tool(EditTool)
    case fill
    case pin
    case close

    init?(event: NSEvent) {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.intersection(blockedModifiers).isEmpty else { return nil }
        guard let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1 else {
            return nil
        }

        switch key {
        case "v": self = .select
        case "r": self = .tool(.rectangle)
        case "o": self = .tool(.ellipse)
        case "l": self = .tool(.line)
        case "a": self = .tool(.arrow)
        case "d": self = .tool(.pen)
        case "h": self = .tool(.marker)
        case "m": self = .tool(.mosaic)
        case "e": self = .tool(.eraser)
        case "f": self = .fill
        case "t": self = .tool(.text)
        case "n": self = .tool(.numbered)
        case "p": self = .pin
        case "x": self = .close
        default: return nil
        }
    }
}
