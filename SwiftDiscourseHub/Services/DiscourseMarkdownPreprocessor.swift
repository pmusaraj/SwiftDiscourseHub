import Foundation

struct QuoteInfo {
    let username: String
    let postNumber: Int?
    let topicId: Int?
    let content: String
}

struct OneboxInfo {
    let url: String
    let title: String?
    let description: String?
    let imageURL: String?
    let faviconURL: String?
    let siteName: String?

    var domain: String {
        guard let urlObj = URL(string: url), let host = urlObj.host() else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

enum PostContentSegment {
    case markdown(String)
    case quote(QuoteInfo)
    case richLink(OneboxInfo)
    case video(String)
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
        result = extractVideoMarkers(result)
        result = cleanDiscourseImageSyntax(result)
        result = resolveRelativeImageURLs(result)
        result = convertDetails(result)
        result = convertMentions(result)
        result = ensureHardBreaks(result)
        return result
    }

    // MARK: - Segment Extraction

    static func extractSegments(from markdown: String, oneboxes: [String: OneboxInfo] = [:], videoURLs: [String] = []) -> [PostContentSegment] {
        // Pass 1: extract quotes
        var segments = extractQuoteSegments(from: markdown)

        // Pass 2: extract videos from markdown segments, substituting cooked URLs when available
        var videoIndex = 0
        segments = segments.flatMap { segment -> [PostContentSegment] in
            if case .markdown(let text) = segment {
                return extractVideoSegments(from: text, cookedURLs: videoURLs, videoIndex: &videoIndex)
            }
            return [segment]
        }

        // Pass 3: extract rich links and convert bare URLs in markdown segments
        segments = segments.flatMap { segment -> [PostContentSegment] in
            if case .markdown(let text) = segment {
                return extractRichLinks(from: text, oneboxes: oneboxes)
            }
            return [segment]
        }

        return segments
    }

    private static func extractQuoteSegments(from markdown: String) -> [PostContentSegment] {
        let pattern = #"(?s)\[quote(?:="([^"]*?)")?\](.*?)\[/quote\]"#
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
                  let contentRange = Range(match.range(at: 2), in: markdown) else { continue }

            let textBefore = String(markdown[lastEnd..<fullRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !textBefore.isEmpty {
                segments.append(.markdown(textBefore))
            }

            let meta = Range(match.range(at: 1), in: markdown).map { String(markdown[$0]) } ?? ""
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

    // MARK: - Video Extraction

    private static let videoMarkerPattern = #"%%DISCOURSE_VIDEO:(.*?)%%"#

    private static func extractVideoSegments(from markdown: String, cookedURLs: [String], videoIndex: inout Int) -> [PostContentSegment] {
        guard let regex = try? NSRegularExpression(pattern: videoMarkerPattern) else {
            return [.markdown(markdown)]
        }

        let range = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: range)

        if matches.isEmpty { return [.markdown(markdown)] }

        var segments: [PostContentSegment] = []
        var lastEnd = markdown.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: markdown),
                  let urlRange = Range(match.range(at: 1), in: markdown) else { continue }

            let textBefore = String(markdown[lastEnd..<fullRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !textBefore.isEmpty {
                segments.append(.markdown(textBefore))
            }

            // Prefer the direct URL from cooked HTML over the short-url redirect
            let markerURL = String(markdown[urlRange])
            let videoURL: String
            if videoIndex < cookedURLs.count {
                videoURL = cookedURLs[videoIndex]
                videoIndex += 1
            } else {
                videoURL = markerURL
            }
            segments.append(.video(videoURL))
            lastEnd = fullRange.upperBound
        }

        let remaining = String(markdown[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            segments.append(.markdown(remaining))
        }

        return segments.isEmpty ? [.markdown(markdown)] : segments
    }

    // MARK: - Rich Link Extraction

    private static func extractRichLinks(from markdown: String, oneboxes: [String: OneboxInfo]) -> [PostContentSegment] {
        // Bare URLs on their own line (with optional trailing spaces from ensureHardBreaks)
        let pattern = #"^(https?://\S+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return [.markdown(markdown)]
        }

        let range = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, range: range)

        if matches.isEmpty { return [.markdown(markdown)] }

        var segments: [PostContentSegment] = []
        var lastEnd = markdown.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: markdown),
                  let urlRange = Range(match.range(at: 1), in: markdown) else { continue }

            let url = String(markdown[urlRange])
            let normalizedURL = normalizeURL(url)

            let textBefore = String(markdown[lastEnd..<fullRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !textBefore.isEmpty {
                segments.append(.markdown(textBefore))
            }

            if let info = oneboxes[normalizedURL] ?? oneboxes[url] {
                segments.append(.richLink(info))
            } else {
                // No onebox data — convert to markdown link so it's clickable
                segments.append(.markdown("[\(url)](\(url))"))
            }
            lastEnd = fullRange.upperBound
        }

        let remaining = String(markdown[lastEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            segments.append(.markdown(remaining))
        }

        return segments.isEmpty ? [.markdown(markdown)] : segments
    }

    private static func normalizeURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") { normalized = String(normalized.dropLast()) }
        return normalized
    }

    // MARK: - Onebox Parsing from Cooked HTML

    static func parseOneboxes(from cooked: String?) -> [String: OneboxInfo] {
        guard let cooked else { return [:] }

        let pattern = #"(?s)<aside\b[^>]*\bdata-onebox-src="([^"]*)"[^>]*>(.*?)</aside>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }

        let range = NSRange(cooked.startIndex..., in: cooked)
        let matches = regex.matches(in: cooked, range: range)

        var result: [String: OneboxInfo] = [:]
        for match in matches {
            guard let urlRange = Range(match.range(at: 1), in: cooked),
                  let bodyRange = Range(match.range(at: 2), in: cooked) else { continue }

            let url = String(cooked[urlRange])
            let body = String(cooked[bodyRange])

            let title = stripHTML(firstMatch(in: body, pattern: #"<h[34]>\s*<a[^>]*>(.*?)</a>"#))
            let description = stripHTML(firstMatch(in: body, pattern: #"<p[^>]*>(.*?)</p>"#))
            let imageURL = firstMatch(in: body, pattern: #"<img[^>]+class="[^"]*thumbnail[^"]*"[^>]+src="([^"]*)"#)
                ?? firstMatch(in: body, pattern: #"<img[^>]+src="([^"]*)"[^>]+class="[^"]*thumbnail[^"]*""#)
            let faviconURL = firstMatch(in: body, pattern: #"<img[^>]+src="([^"]*)"[^>]+class="[^"]*site-icon[^"]*""#)
                ?? firstMatch(in: body, pattern: #"<img[^>]+class="[^"]*site-icon[^"]*"[^>]+src="([^"]*)"#)
            let siteName = stripHTML(firstMatch(in: body, pattern: #"<header class="source">.*?<a[^>]*>(.*?)</a>"#))

            let key = normalizeURL(url)
            result[key] = OneboxInfo(
                url: url,
                title: title,
                description: description,
                imageURL: imageURL,
                faviconURL: faviconURL,
                siteName: siteName
            )
        }

        return result
    }

    static func parseVideoURLs(from cooked: String?, baseURL: String) -> [String] {
        guard let cooked else { return [] }

        let pattern = #"data-video-src="([^"]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(cooked.startIndex..., in: cooked)
        let matches = regex.matches(in: cooked, range: range)
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL

        return matches.compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: cooked) else { return nil }
            let src = String(cooked[captureRange])
            if src.hasPrefix("http") { return src }
            return "\(base)\(src)"
        }
    }

    private static func firstMatch(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let captureRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[captureRange])
    }

    private static func stripHTML(_ text: String?) -> String? {
        guard let text else { return nil }
        let stripped = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
