import Foundation

enum AgentParsedArgument: Equatable {
    case flag(String)
    case help
    case option(key: String, value: String)
}

struct AgentArgumentCursor {
    private let arguments: [String]
    private var index = 0

    init(_ arguments: [String]) {
        self.arguments = arguments
    }

    mutating func next(flags: Set<String>) throws -> AgentParsedArgument? {
        guard index < arguments.count else { return nil }
        let token = arguments[index]

        if flags.contains(token) {
            index += 1
            return .flag(token)
        }
        if token == "--help" || token == "-h" {
            index += 1
            return .help
        }

        if let split = token.firstIndex(of: "="), token.hasPrefix("--") {
            index += 1
            return .option(
                key: String(token[..<split]),
                value: String(token[token.index(after: split)...])
            )
        }

        guard index + 1 < arguments.count else {
            throw AgentCLIError.usage("Missing value for \(token)")
        }
        index += 2
        return .option(key: token, value: arguments[index - 1])
    }
}
