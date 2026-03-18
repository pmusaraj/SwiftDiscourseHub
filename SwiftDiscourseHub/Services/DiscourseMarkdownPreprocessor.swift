import Foundation

struct QuoteInfo {
    let username: String
    let postNumber: Int?
    let topicId: Int?
    let content: String
}

enum PostContentSegment {
    case markdown(String)
    case quote(QuoteInfo)
}

struct LinkedTopicDestination: Hashable {
    let topicId: Int
}

struct DiscourseMarkdownPreprocessor {
    let baseURL: String

    func process(_ markdown: String) -> String {
        var result = markdown
        result = stripHTML(result)
        result = convertCheckboxes(result)
        result = resolveUploadURLs(result)
        result = cleanDiscourseImageSyntax(result)
        result = resolveRelativeImageURLs(result)
        result = convertDetails(result)
        result = convertMentions(result)
        result = ensureHardBreaks(result)
        return result
    }

    // MARK: - Quote Segment Extraction

    static func extractSegments(from markdown: String) -> [PostContentSegment] {
        let pattern = #"(?s)\[quote="([^"]*?)"\](.*?)\[/quote\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.markdown(markdown)]
        }

        let range = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: range)

        if matches.isEmpty {
            return [.markdown(markdown)]
        }

        var segments: [PostContentSegment] = []
        var lastEnd = markdown.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: markdown),
                  let metaRange = Range(match.range(at: 1), in: markdown),
                  let contentRange = Range(match.range(at: 2), in: markdown) else { continue }

            let textBefore = String(markdown[lastEnd..<fullRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !textBefore.isEmpty {
                segments.append(.markdown(textBefore))
            }

            let meta = String(markdown[metaRange])
            let content = String(markdown[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            segments.append(.quote(parseQuoteMeta(meta, content: content)))

            lastEnd = fullRange.upperBound
        }

        let remaining = String(markdown[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            segments.append(.markdown(remaining))
        }

        return segments
    }

    private static func parseQuoteMeta(_ meta: String, content: String) -> QuoteInfo {
        var username = ""
        var postNumber: Int?
        var topicId: Int?

        let parts = meta.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if let first = parts.first {
            username = first
        }
        for part in parts.dropFirst() {
            if part.hasPrefix("post:"), let num = Int(part.dropFirst(5)) {
                postNumber = num
            } else if part.hasPrefix("topic:"), let num = Int(part.dropFirst(6)) {
                topicId = num
            }
        }

        return QuoteInfo(username: username, postNumber: postNumber, topicId: topicId, content: content)
    }

    // MARK: - HTML Conversion

    /// Rules for converting HTML elements to Markdown (or removing them).
    /// Each entry is a (regex pattern, replacement template) pair.
    /// Use `$1`, `$2`, etc. to reference capture groups in the replacement.
    /// An empty replacement removes the match entirely.
    /// Add new entries here to handle additional tags.
    private static let htmlConversionRules: [(pattern: String, replacement: String)] = [
        // HTML comments: <!-- ... -->
        (#"<!--.*?-->"#, ""),
        // <hr> / <hr /> → Markdown horizontal rule
        (#"<hr\s*/?>"#, "\n---\n"),
        // <br> / <br /> → hard line break
        (#"<br\s*/?>"#, "  \n"),
        // Matched pairs of tags with only whitespace content: <div ...> </div>
        (#"<(\w+)\b[^>]*>\s*</\1>"#, ""),
        // <strong>text</strong> / <b>text</b> → **text**
        (#"<(strong|b)(?:\s[^>]*)?>([^<]*)</\1>"#, "**$2**"),
        // <em>text</em> / <i>text</i> → *text*
        (#"<(em|i)(?:\s[^>]*)?>([^<]*)</\1>"#, "*$2*"),
        // <del>text</del> / <s>text</s> → ~~text~~
        (#"<(del|s)(?:\s[^>]*)?>([^<]*)</\1>"#, "~~$2~~"),
        // <code>text</code> → `text`
        (#"<code(?:\s[^>]*)?>([^<]*)</code>"#, "`$1`"),
        // Remaining inline tags: unwrap content
        (#"<(small|sup|sub|big|u|mark|abbr|ins)(?:\s[^>]*)?>([^<]*)</\1>"#, "$2"),
        // Self-closing tags with attributes not matched above: <div ... />
        (#"<\w+\s[^>]*/>"#, ""),
    ]

    private func stripHTML(_ markdown: String) -> String {
        var result = markdown
        for rule in Self.htmlConversionRules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.dotMatchesLineSeparators]) else {
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: rule.replacement)
        }
        // Clean up leftover blank lines from removed block-level elements
        result = result.replacing(/\n{3,}/, with: "\n\n")
        return result
    }

    // MARK: - Private

    private func convertCheckboxes(_ markdown: String) -> String {
        // Discourse uses - [x] / - [ ] (GFM task lists) and bare [x] / [ ] for checkboxes.
        // Convert to unicode checkbox characters since Textual doesn't support GFM task lists.
        let pattern = #"^(\s*(?:[-*+]\s+)?)\[([ xX])\] "#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return markdown
        }
        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown
        for match in regex.matches(in: markdown, range: range).reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let checkRange = Range(match.range(at: 2), in: result) else { continue }
            let leading = match.range(at: 1).location != NSNotFound
                ? String(result[Range(match.range(at: 1), in: result)!])
                : ""
            let checked = result[checkRange] != " "
            let replacement = leading + (checked ? "☑ " : "☐ ")
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }

    private func resolveUploadURLs(_ markdown: String) -> String {
        // Replace upload://hash.ext with {baseURL}/uploads/short-url/hash.ext
        // The short-url path 302-redirects to the real CDN URL (no auth needed)
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let pattern = #"upload://([A-Za-z0-9]+\.\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let hashRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let hashAndExt = String(result[hashRange])
            let resolved = "\(base)/uploads/short-url/\(hashAndExt)"
            result.replaceSubrange(fullRange, with: resolved)
        }

        return result
    }

    private func cleanDiscourseImageSyntax(_ markdown: String) -> String {
        // Discourse uses ![name|WxH](url) and ![name|video](url) — the pipe breaks
        // standard Markdown image parsing. Clean to ![name](url).
        let pattern = #"!\[([^\]\|]*)\|[^\]]*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let name = String(result[nameRange])
            result.replaceSubrange(fullRange, with: "![\(name)]")
        }

        return result
    }

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

    private func ensureHardBreaks(_ markdown: String) -> String {
        // Discourse treats single newlines as hard line breaks (<br>).
        // Standard Markdown treats them as soft breaks (collapsed into space).
        // Add two trailing spaces before each newline to force hard breaks,
        // but skip lines inside fenced code blocks.
        var lines = markdown.components(separatedBy: "\n")
        var inCodeFence = false
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeFence.toggle()
                continue
            }
            if inCodeFence { continue }
            // Skip blank lines — they already produce paragraph breaks
            if trimmed.isEmpty { continue }
            // Skip lines that already end with two+ spaces
            if lines[i].hasSuffix("  ") { continue }
            lines[i] = lines[i] + "  "
        }
        return lines.joined(separator: "\n")
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
