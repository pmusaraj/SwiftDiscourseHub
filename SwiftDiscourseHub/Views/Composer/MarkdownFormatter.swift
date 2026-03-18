import Foundation

enum MarkdownFormatter {
    enum Format {
        case bold, italic, link, quote
    }

    static func apply(_ format: Format, to text: String) -> String {
        switch format {
        case .bold:
            return toggleWrap(text, prefix: "**", suffix: "**", placeholder: "bold text")
        case .italic:
            return toggleWrap(text, prefix: "*", suffix: "*", placeholder: "italic text")
        case .link:
            return text + "[link text](url)"
        case .quote:
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text + "> "
            }
            let lines = text.components(separatedBy: "\n")
            return lines.map { line in
                if line.hasPrefix("> ") { return String(line.dropFirst(2)) }
                return "> " + line
            }.joined(separator: "\n")
        }
    }

    static func bold(_ text: String) -> String { apply(.bold, to: text) }
    static func italic(_ text: String) -> String { apply(.italic, to: text) }
    static func link(_ text: String) -> String { apply(.link, to: text) }
    static func quote(_ text: String) -> String { apply(.quote, to: text) }

    static func quoteReply(text: String, username: String, topicId: Int, postNumber: Int) -> String {
        let quoted = text.components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
        return "[quote=\"\(username), post:\(postNumber), topic:\(topicId)\"]\n\(quoted)\n[/quote]\n\n"
    }

    private static func toggleWrap(_ text: String, prefix: String, suffix: String, placeholder: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return text + "\(prefix)\(placeholder)\(suffix)"
        }
        if trimmed.hasPrefix(prefix) && trimmed.hasSuffix(suffix) && trimmed.count > prefix.count + suffix.count {
            let start = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
            let end = trimmed.index(trimmed.endIndex, offsetBy: -suffix.count)
            return String(trimmed[start..<end])
        }
        return "\(prefix)\(trimmed)\(suffix)"
    }
}
