import Foundation

struct HotkeyBinding: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
}

struct HotkeyDescriptor: Equatable {
    let defaultsKeyPrefix: String
    let carbonHotKeyID: UInt32?
    let allowsBareKey: Bool

    var keyCodeKey: String { "\(defaultsKeyPrefix)HotkeyKeyCode" }
    var modifiersKey: String { "\(defaultsKeyPrefix)HotkeyModifiers" }
}

enum HotkeySlot: String, CaseIterable, Hashable {
    case screenshot
    case clipboard
    case selectedImageEdit
    case clipboardImageEdit
    case selectedImagePin
    case clipboardImagePin
    case record
    case imageMerge
    case clipboardTextPin

    var descriptor: HotkeyDescriptor {
        switch self {
        case .screenshot:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 1, allowsBareKey: false)
        case .selectedImagePin:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 3, allowsBareKey: false)
        case .selectedImageEdit:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 4, allowsBareKey: false)
        case .clipboardImageEdit:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 5, allowsBareKey: false)
        case .clipboardImagePin:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 6, allowsBareKey: false)
        case .record:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 9, allowsBareKey: false)
        case .imageMerge:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 10, allowsBareKey: false)
        case .clipboardTextPin:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: 14, allowsBareKey: false)
        case .clipboard:
            HotkeyDescriptor(defaultsKeyPrefix: rawValue, carbonHotKeyID: nil, allowsBareKey: true)
        }
    }

    static var globalCases: [HotkeySlot] {
        allCases.filter { $0.descriptor.carbonHotKeyID != nil }
    }

    init?(carbonHotKeyID: UInt32) {
        guard let slot = Self.globalCases.first(where: {
            $0.descriptor.carbonHotKeyID == carbonHotKeyID
        }) else {
            return nil
        }
        self = slot
    }

    var localizedHeader: String {
        switch self {
        case .screenshot: L10n.shortcutHeader
        case .clipboard: L10n.clipboardShortcutHeader
        case .selectedImageEdit: L10n.selectedImageEditShortcutHeader
        case .clipboardImageEdit: L10n.clipboardImageEditShortcutHeader
        case .selectedImagePin: L10n.selectedImagePinShortcutHeader
        case .clipboardImagePin: L10n.clipboardImagePinShortcutHeader
        case .record: L10n.recordShortcutHeader
        case .imageMerge: L10n.imageMergeShortcutHeader
        case .clipboardTextPin: L10n.clipboardTextPinShortcutHeader
        }
    }

    var localizedDefaultDisplay: String {
        switch self {
        case .screenshot: L10n.shortcutDefaultDisplay
        case .clipboard: L10n.clipboardShortcutDefaultDisplay
        case .selectedImageEdit: L10n.selectedImageEditShortcutDefaultDisplay
        case .clipboardImageEdit: L10n.clipboardImageEditShortcutDefaultDisplay
        case .selectedImagePin: L10n.selectedImagePinShortcutDefaultDisplay
        case .clipboardImagePin: L10n.clipboardImagePinShortcutDefaultDisplay
        case .record: L10n.recordShortcutDefaultDisplay
        case .imageMerge: L10n.imageMergeShortcutDefaultDisplay
        case .clipboardTextPin: L10n.clipboardTextPinShortcutDefaultDisplay
        }
    }

    var localizedConflictMessage: String {
        switch self {
        case .screenshot: L10n.shortcutConflictScreenshot
        case .clipboard: L10n.shortcutConflictClipboard
        case .selectedImageEdit: L10n.shortcutConflictSelectedImageEdit
        case .clipboardImageEdit: L10n.shortcutConflictClipboardImageEdit
        case .selectedImagePin: L10n.shortcutConflictSelectedImagePin
        case .clipboardImagePin: L10n.shortcutConflictClipboardImagePin
        case .record: L10n.shortcutConflictRecord
        case .imageMerge: L10n.shortcutConflictImageMerge
        case .clipboardTextPin: L10n.shortcutConflictClipboardTextPin
        }
    }
}
