import Foundation

enum OutputFilename {
    static func imageFileName(fileExtension: String, date: Date = Date()) -> String {
        fileName(prefix: "aulycShot", fileExtension: fileExtension, date: date)
    }

    static func recordingFileName(fileExtension: String, date: Date = Date()) -> String {
        fileName(prefix: "aulycShot-rec", fileExtension: fileExtension, date: date)
    }

    private static func fileName(prefix: String, fileExtension: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyMMdd-HHmmss"

        let randomSuffix = UUID()
            .uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
            .prefix(3)

        return "\(prefix)-\(formatter.string(from: date))-\(randomSuffix).\(fileExtension)"
    }
}
