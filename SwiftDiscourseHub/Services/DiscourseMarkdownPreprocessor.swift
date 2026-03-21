import Foundation

struct LinkedTopicDestination: Hashable {
    let topicId: Int
}

struct DiscourseMarkdownPreprocessor {
    let baseURL: String

    func process(_ markdown: String, cooked: String? = nil) -> String {
        var result = markdown
        result = stripHTML(result)
        result = convertCheckboxes(result)
        result = resolveUploadURLs(result)
        result = extractVideoMarkers(result)
        result = cleanDiscourseImageSyntax(result)
        result = resolveRelativeImageURLs(result)
        result = convertQuotes(result)
        result = convertDetails(result)
        result = convertBareURLsToLinks(result, cooked: cooked)
        result = convertMentions(result)
        result = convertEmojiShortcodes(result)
        result = ensureHardBreaks(result)
        return result
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
        // Convert to unicode checkbox characters for GFM task lists.
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

    private func extractVideoMarkers(_ markdown: String) -> String {
        // Replace ![name|video](url) with a marker before cleanDiscourseImageSyntax strips |video
        let pattern = #"!\[[^\]]*\|video\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let urlRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            let url = String(result[urlRange])
            result.replaceSubrange(fullRange, with: "\n%%DISCOURSE_VIDEO:\(url)%%\n")
        }

        return result
    }

    private func cleanDiscourseImageSyntax(_ markdown: String) -> String {
        // Discourse uses ![name|WxH](url) and ![name|video](url) — the pipe breaks
        // standard Markdown image parsing.
        var result = markdown

        // Step 1: Extract WxH dimensions and encode as URL fragment for space reservation
        let dimPattern = #"!\[([^\]\|]*)\|(\d+)x(\d+)[^\]]*\]\(([^)]+)\)"#
        if let dimRegex = try? NSRegularExpression(pattern: dimPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = dimRegex.matches(in: result, range: range).reversed()
            for match in matches {
                guard let nameRange = Range(match.range(at: 1), in: result),
                      let wRange = Range(match.range(at: 2), in: result),
                      let hRange = Range(match.range(at: 3), in: result),
                      let urlRange = Range(match.range(at: 4), in: result),
                      let fullRange = Range(match.range, in: result) else { continue }
                let name = String(result[nameRange])
                let w = String(result[wRange])
                let h = String(result[hRange])
                let url = String(result[urlRange])
                result.replaceSubrange(fullRange, with: "![\(name)](\(url)#dim=\(w)x\(h))")
            }
        }

        // Step 2: Strip remaining pipe suffixes (non-dimension patterns)
        let pipePattern = #"!\[([^\]\|]*)\|[^\]]*\]"#
        if let pipeRegex = try? NSRegularExpression(pattern: pipePattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = pipeRegex.matches(in: result, range: range).reversed()
            for match in matches {
                guard let nameRange = Range(match.range(at: 1), in: result),
                      let fullRange = Range(match.range, in: result) else { continue }
                let name = String(result[nameRange])
                result.replaceSubrange(fullRange, with: "![\(name)]")
            }
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

    private func convertQuotes(_ markdown: String) -> String {
        // Convert [quote="username, post:N, topic:T"]content[/quote] to markdown blockquotes
        let pattern = #"(?s)\[quote(?:="([^"]*?)")?\](.*?)\[/quote\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let range = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: range)
        if matches.isEmpty { return markdown }

        var result = markdown
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let contentRange = Range(match.range(at: 2), in: result) else { continue }

            let meta = Range(match.range(at: 1), in: result).map { String(result[$0]) } ?? ""
            let content = String(result[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract username from meta (first comma-separated part)
            let username = meta.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""

            // Build blockquote: attribution line + quoted content
            var lines: [String] = []
            if !username.isEmpty {
                lines.append("> **\(username):**")
            }
            for line in content.components(separatedBy: "\n") {
                lines.append("> \(line)")
            }

            result.replaceSubrange(fullRange, with: lines.joined(separator: "\n"))
        }

        return result
    }

    private func convertBareURLsToLinks(_ markdown: String, cooked: String?) -> String {
        // Parse onebox data from cooked HTML if available
        let oneboxes = Self.parseOneboxes(from: cooked)

        // Match bare URLs on their own line
        let pattern = #"^(https?://\S+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return markdown
        }

        let range = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: range)
        if matches.isEmpty { return markdown }

        var result = markdown
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let urlRange = Range(match.range(at: 1), in: result) else { continue }

            let url = String(result[urlRange])
            let normalizedURL = Self.normalizeURL(url)

            if let info = oneboxes[normalizedURL] ?? oneboxes[url] {
                // Rich link: render as styled block with title, description, domain
                var block: [String] = []
                if let title = info.title {
                    block.append("**[\(title)](\(url))**")
                } else {
                    block.append("**[\(url)](\(url))**")
                }
                if let desc = info.description, !desc.isEmpty {
                    block.append(desc)
                }
                block.append("*\(info.domain)*")
                result.replaceSubrange(fullRange, with: block.joined(separator: "\n"))
            } else {
                // Plain link
                result.replaceSubrange(fullRange, with: "[\(url)](\(url))")
            }
        }

        return result
    }

    // MARK: - Onebox Parsing from Cooked HTML

    private static func parseOneboxes(from cooked: String?) -> [String: OneboxInfo] {
        guard let cooked else { return [:] }

        let pattern = #"(?s)<aside\b[^>]*\bdata-onebox-src="([^"]*)"[^>]*>(.*?)</aside>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }

        let range = NSRange(cooked.startIndex..., in: cooked)
        let matches = regex.matches(in: cooked, range: range)
        if matches.isEmpty { return [:] }

        var result: [String: OneboxInfo] = [:]
        for match in matches {
            guard let urlRange = Range(match.range(at: 1), in: cooked),
                  let bodyRange = Range(match.range(at: 2), in: cooked) else { continue }

            let url = String(cooked[urlRange])
            let body = String(cooked[bodyRange])

            let title = stripHTMLTags(firstMatch(in: body, pattern: #"<h[34]>\s*<a[^>]*>(.*?)</a>"#))
            let description = stripHTMLTags(firstMatch(in: body, pattern: #"<p[^>]*>(.*?)</p>"#))

            let key = normalizeURL(url)
            result[key] = OneboxInfo(url: url, title: title, description: description, domain: domainFrom(url))
        }

        return result
    }

    struct OneboxInfo {
        let url: String
        let title: String?
        let description: String?
        let domain: String
    }

    private static func normalizeURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") { normalized = String(normalized.dropLast()) }
        return normalized
    }

    private static func domainFrom(_ url: String) -> String {
        guard let urlObj = URL(string: url), let host = urlObj.host() else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func firstMatch(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let captureRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[captureRange])
    }

    private static func stripHTMLTags(_ text: String?) -> String? {
        guard let text else { return nil }
        return text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func convertEmojiShortcodes(_ markdown: String) -> String {
        let pattern = #"(?<![`\w]):([a-z0-9_+\-]+):(?![`\w])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return markdown }

        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        var result = markdown

        // Track code fence state to skip replacements inside code blocks
        let codeBlockRanges = Self.fencedCodeRanges(in: markdown)

        let matches = regex.matches(in: markdown, range: range).reversed()
        for match in matches {
            guard let fullRange = Range(match.range, in: result),
                  let nameRange = Range(match.range(at: 1), in: result) else { continue }

            // Skip matches inside fenced code blocks
            if codeBlockRanges.contains(where: { $0.contains(match.range.location) }) { continue }

            let name = String(result[nameRange])
            if let emoji = EmojiShortcodes.map[name] {
                result.replaceSubrange(fullRange, with: emoji)
            }
        }

        return result
    }

    private static func fencedCodeRanges(in markdown: String) -> [NSRange] {
        let pattern = #"(?m)^```.*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(markdown.startIndex..., in: markdown)
        let fences = regex.matches(in: markdown, range: range)

        var ranges: [NSRange] = []
        var i = 0
        while i + 1 < fences.count {
            let start = fences[i].range.location
            let end = fences[i + 1].range.location + fences[i + 1].range.length
            ranges.append(NSRange(location: start, length: end - start))
            i += 2
        }
        return ranges
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
