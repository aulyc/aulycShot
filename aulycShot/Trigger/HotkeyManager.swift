import Cocoa
import Carbon

@MainActor
final class HotkeyManager {

    static let shared = HotkeyManager()

    private(set) var isRecording: Bool = false

    private var hotKeyRefs: [HotkeySlot: EventHotKeyRef] = [:]
    private var callbacks: [HotkeySlot: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?

    private static let regularHotKeySignature: OSType = OSType(0x4341_5043) // 'CAPC'

    private init() {}

    deinit {
        MainActor.assumeIsolated {
            unregisterAllGlobalHotkeys()
            if let handler = eventHandlerRef {
                RemoveEventHandler(handler)
                eventHandlerRef = nil
            }
        }
    }

    // MARK: - Registration

    func register(_ slot: HotkeySlot, callback: @escaping () -> Void) {
        guard let carbonHotKeyID = slot.descriptor.carbonHotKeyID else { return }
        callbacks[slot] = callback
        unregister(slot)
        guard let binding = currentHotkey(for: slot) else { return }

        installEventHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(
            signature: Self.regularHotKeySignature,
            id: carbonHotKeyID
        )
        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefs[slot] = ref
        }
    }

    func unregister(_ slot: HotkeySlot) {
        guard let ref = hotKeyRefs.removeValue(forKey: slot) else { return }
        UnregisterEventHotKey(ref)
    }

    func unregisterAllGlobalHotkeys() {
        for slot in HotkeySlot.globalCases {
            unregister(slot)
        }
    }

    // MARK: - Recording lifecycle

    /// Called by Settings UI when the user starts capturing a new key combo.
    /// Suspends the active hotkey so the user's recorded keypress is not swallowed.
    func beginRecording() {
        isRecording = true
        unregisterAllGlobalHotkeys()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
    }

    /// Called when recording finishes (saved or cancelled).
    func endRecording() {
        isRecording = false
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
    }

    // MARK: - Stored hotkey accessors

    func currentHotkey(for slot: HotkeySlot) -> HotkeyBinding? {
        guard let binding = Defaults.hotkey(for: slot) else { return nil }
        guard slot.descriptor.allowsBareKey
                || binding.modifiers != 0
                || Self.isFunctionKey(binding.keyCode)
        else {
            return nil
        }
        return binding
    }

    static func currentDisplayString(for slot: HotkeySlot) -> String? {
        guard let binding = HotkeyManager.shared.currentHotkey(for: slot) else { return nil }
        return modifierString(binding.modifiers) + keyString(binding.keyCode)
    }

    func currentHotkey() -> (keyCode: UInt32, modifiers: UInt32)? {
        currentHotkeyTuple(for: .screenshot)
    }

    static func currentDisplayString() -> String? {
        currentDisplayString(for: .screenshot)
    }

    nonisolated static func currentClipboardDisplayString() -> String? {
        guard let binding = Defaults.hotkey(for: .clipboard) else { return nil }
        return modifierString(binding.modifiers) + keyString(binding.keyCode)
    }

    private func currentHotkeyTuple(
        for slot: HotkeySlot
    ) -> (keyCode: UInt32, modifiers: UInt32)? {
        guard let binding = currentHotkey(for: slot) else { return nil }
        return (binding.keyCode, binding.modifiers)
    }

    /// Returns true when the given keyDown event matches the user's
    /// screenshot-execution hotkey. Returns false when no custom hotkey is set.
    static func eventMatchesClipboardHotkey(_ event: NSEvent) -> Bool {
        guard let binding = HotkeyManager.shared.currentHotkey(for: .clipboard) else { return false }
        return matches(
            event: event,
            keyCode: binding.keyCode,
            modifiers: binding.modifiers
        )
    }

    private static func matches(event: NSEvent, keyCode: UInt32, modifiers: UInt32) -> Bool {
        let activeMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let mods = event.modifierFlags.intersection(activeMask)
        var carbonMods: UInt32 = 0
        if mods.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if mods.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
        if mods.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if mods.contains(.control) { carbonMods |= UInt32(controlKey) }
        return UInt32(event.keyCode) == keyCode && carbonMods == modifiers
    }

    // MARK: - Conflict detection

    /// Returns a localized message describing the existing binding a candidate
    /// `(keyCode, modifiers)` would collide with, or nil when it is free to
    /// assign. `slot` is the function being edited and is excluded from the
    /// check, so re-recording its own combo is not flagged as a self-conflict.
    func hotkeyConflictMessage(forKeyCode keyCode: UInt32,
                               modifiers: UInt32,
                               assigningTo slot: HotkeySlot) -> String? {
        let candidate = HotkeyBinding(keyCode: keyCode, modifiers: modifiers)
        for occupiedSlot in HotkeySlot.allCases where occupiedSlot != slot {
            if currentHotkey(for: occupiedSlot) == candidate {
                return occupiedSlot.localizedConflictMessage
            }
        }
        return nil
    }

    // MARK: - Event handler

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return OSStatus(eventNotHandledErr) }

                if let slot = HotkeySlot(carbonHotKeyID: hkID.id),
                   let callback = mgr.callbacks[slot] {
                    MainRunLoopScheduler.perform(callback)
                }
                return noErr
            },
            1, &spec, selfPtr, &eventHandlerRef
        )
    }

    // MARK: - Keycode helpers

    nonisolated static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        let codes: Set<UInt32> = [
            UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
            UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
            UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
            UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
            UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19), UInt32(kVK_F20),
        ]
        return codes.contains(keyCode)
    }

    nonisolated static func modifierString(_ m: UInt32) -> String {
        var s = ""
        if m & UInt32(controlKey) != 0 { s += "\u{2303}" }
        if m & UInt32(optionKey) != 0  { s += "\u{2325}" }
        if m & UInt32(shiftKey) != 0   { s += "\u{21E7}" }
        if m & UInt32(cmdKey) != 0     { s += "\u{2318}" }
        return s
    }

    nonisolated static func keyString(_ keyCode: UInt32) -> String {
        if let mapped = keyMap[keyCode] { return mapped }
        return "Key \(keyCode)"
    }

    // MARK: - NSMenuItem integration

    /// Apply the saved hotkey to a menu item via the native keyEquivalent system.
    static func applyToMenuItem(_ item: NSMenuItem) {
        apply(.screenshot, to: item)
    }

    static func applyImageMergeToMenuItem(_ item: NSMenuItem) {
        apply(.imageMerge, to: item)
    }

    static func applyRecordToMenuItem(_ item: NSMenuItem) {
        apply(.record, to: item)
    }

    private static func apply(_ slot: HotkeySlot, to item: NSMenuItem) {
        item.attributedTitle = nil
        guard let binding = HotkeyManager.shared.currentHotkey(for: slot) else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            return
        }
        apply(keyCode: binding.keyCode, modifiers: binding.modifiers, to: item)
    }

    private static func apply(keyCode kc: UInt32, modifiers mods: UInt32, to item: NSMenuItem) {
        var flags: NSEvent.ModifierFlags = []
        if mods & UInt32(cmdKey) != 0     { flags.insert(.command) }
        if mods & UInt32(shiftKey) != 0   { flags.insert(.shift) }
        if mods & UInt32(optionKey) != 0  { flags.insert(.option) }
        if mods & UInt32(controlKey) != 0 { flags.insert(.control) }

        let key: String
        if let special = menuKeyCharMap[kc] {
            key = special
        } else {
            let display = keyString(kc)
            guard !display.hasPrefix("Key ") else {
                item.keyEquivalent = ""
                item.keyEquivalentModifierMask = []
                return
            }
            key = display.lowercased()
        }
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = flags
    }

    private static let menuKeyCharMap: [UInt32: String] = [
        UInt32(kVK_F1): "\u{F704}", UInt32(kVK_F2): "\u{F705}", UInt32(kVK_F3): "\u{F706}",
        UInt32(kVK_F4): "\u{F707}", UInt32(kVK_F5): "\u{F708}", UInt32(kVK_F6): "\u{F709}",
        UInt32(kVK_F7): "\u{F70A}", UInt32(kVK_F8): "\u{F70B}", UInt32(kVK_F9): "\u{F70C}",
        UInt32(kVK_F10): "\u{F70D}", UInt32(kVK_F11): "\u{F70E}", UInt32(kVK_F12): "\u{F70F}",
        UInt32(kVK_F13): "\u{F710}", UInt32(kVK_F14): "\u{F711}", UInt32(kVK_F15): "\u{F712}",
        UInt32(kVK_F16): "\u{F713}", UInt32(kVK_F17): "\u{F714}", UInt32(kVK_F18): "\u{F715}",
        UInt32(kVK_F19): "\u{F716}", UInt32(kVK_F20): "\u{F717}",
        UInt32(kVK_Space): " ", UInt32(kVK_Return): "\r", UInt32(kVK_Tab): "\t",
        UInt32(kVK_Delete): "\u{7F}", UInt32(kVK_ForwardDelete): "\u{F728}",
        UInt32(kVK_Escape): "\u{1B}",
        UInt32(kVK_LeftArrow): "\u{F702}", UInt32(kVK_RightArrow): "\u{F703}",
        UInt32(kVK_UpArrow): "\u{F700}", UInt32(kVK_DownArrow): "\u{F701}",
        UInt32(kVK_Home): "\u{F729}", UInt32(kVK_End): "\u{F72B}",
        UInt32(kVK_PageUp): "\u{F72C}", UInt32(kVK_PageDown): "\u{F72D}",
    ]

    nonisolated private static let keyMap: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\", UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".", UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Grave): "`",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16", UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18",
        UInt32(kVK_F19): "F19", UInt32(kVK_F20): "F20",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return", UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Delete): "Delete", UInt32(kVK_ForwardDelete): "Fwd Del",
        UInt32(kVK_Escape): "Esc",
        UInt32(kVK_LeftArrow): "\u{2190}", UInt32(kVK_RightArrow): "\u{2192}",
        UInt32(kVK_UpArrow): "\u{2191}", UInt32(kVK_DownArrow): "\u{2193}",
        UInt32(kVK_Home): "Home", UInt32(kVK_End): "End",
        UInt32(kVK_PageUp): "PgUp", UInt32(kVK_PageDown): "PgDn",
    ]
}
