import Foundation

struct DiscourseMarkdownPreprocessor {
    let baseURL: String

    func process(_ markdown: String) -> String {
        var result = markdown
        result = resolveRelativeImageURLs(result)
        result = convertQuotes(result)
        result = convertDetails(result)
        result = convertMentions(result)
        return result
    }

    // Collect all upload:// short URLs from the markdown
    static func extractUploadShortURLs(from markdown: String) -> [String] {
        let pattern = #"upload://[A-Za-z0-9]+\.\w+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(markdown.startIndex..., in: markdown)
        return regex.matches(in: markdown, range: range).compactMap { match in
            guard let r = Range(match.range, in: markdown) else { return nil }
            return String(markdown[r])
        }
    }

    // Replace upload:// URLs with resolved real URLs
    static func replaceUploadURLs(in markdown: String, mapping: [String: String]) -> String {
        var result = markdown
        for (shortURL, realURL) in mapping {
            result = result.replacingOccurrences(of: shortURL, with: realURL)
        }
        return result
    }

    // MARK: - Private

    private func resolveRelativeImageURLs(_ markdown: String) -> String {
        // Match markdown images with relative URLs: ![alt](/uploads/...)
        let pattern = #"!\[([^\]]*)\]\((/[^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        // Process in reverse to preserve ranges
        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let altRange = Range(match.range(at: 1), in: result),
                  let pathRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }

            let alt = String(result[altRange])
            let path = String(result[pathRange])
            let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
            let resolved = "![\(alt)](\(base)\(path))"
            result.replaceSubrange(fullRange, with: resolved)
        }

        return result
    }

    private func convertQuotes(_ markdown: String) -> String {
        // [quote="username, post:3, topic:123"]...[/quote]
        let pattern = #"(?s)\[quote="([^"]*?)(?:,\s*post:\d+)?(?:,\s*topic:\d+)?(?:,\s*full:\w+)?"\](.*?)\[/quote\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: result),
                  let contentRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }

            let name = String(result[nameRange]).components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
            let content = String(result[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let quoted = content.components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
            let replacement = "**\(name):**\n\(quoted)"
            result.replaceSubrange(fullRange, with: replacement)
        }

        return result
    }

    private func convertDetails(_ markdown: String) -> String {
        // [details="Summary"]...[/details]
        let pattern = #"(?s)\[details="([^"]*?)"\](.*?)\[/details\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let summaryRange = Range(match.range(at: 1), in: result),
                  let contentRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }

            let summary = String(result[summaryRange])
            let content = String(result[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = "**\(summary)**\n\n\(content)"
            result.replaceSubrange(fullRange, with: replacement)
        }

        return result
    }

    private func convertMentions(_ markdown: String) -> String {
        // @username -> **@username**
        let pattern = #"(?<!\w)@([a-zA-Z0-9_.-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let fullRange = Range(match.range, in: result) else { continue }
            let mention = String(result[fullRange])
            result.replaceSubrange(fullRange, with: "**\(mention)**")
        }

        return result
    }
}
