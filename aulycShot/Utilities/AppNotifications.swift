import Foundation

/// Cross-feature notifications live together so their ownership and stable
/// string identities do not depend on whichever feature first posts them.
extension Notification.Name {
    static let languageDidChange = Notification.Name("aulycShot.languageDidChange")
    static let recordingSaveDirectoryDidChange = Notification.Name("aulycShot.recordingSaveDirectoryDidChange")
    static let hotkeyDidChange = Notification.Name("aulycShot.hotkeyDidChange")
    static let updateStateDidChange = Notification.Name("aulycShot.updateStateDidChange")
}
