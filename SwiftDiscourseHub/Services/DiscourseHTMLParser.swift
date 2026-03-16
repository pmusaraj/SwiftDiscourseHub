import Foundation
import SwiftSoup
import Textual

struct DiscourseHTMLParser: MarkupParser {
    let baseURL: String

    func attributedString(for input: String) throws -> AttributedString {
        let doc = try SwiftSoup.parseBodyFragment(input)
        guard let body = doc.body() else {
            return AttributedString(input)
        }

        var result = AttributedString()
        var intentID = 0

        func nextID() -> Int {
            intentID += 1
            return intentID
        }

        func processBlockChildren(of element: Element, parentIntents: [PresentationIntent.Kind] = []) throws {
            for child in element.children() {
                try processBlock(child, parentIntents: parentIntents)
            }
        }

        /// Process an element that may contain a mix of block and inline children.
        /// Inline children are gathered into a paragraph; block children are recursed into.
        func processMixedChildren(of element: Element, parentIntents: [PresentationIntent.Kind]) throws {
            let children = element.children()
            let hasBlockChildren = children.contains { isBlockElement($0) }

            if !hasBlockChildren {
                // All children are inline — treat the whole element as a paragraph
                let text = try processInlineChildren(of: element)
                if text.characters.isEmpty { return }
                let intent = PresentationIntent(.paragraph, identity: nextID())
                let nested = nestIntent(intent, inside: parentIntents)
                var attributed = text
                attributed.presentationIntent = nested
                appendBlock(&result, attributed)
            } else {
                // Mix of block and inline children
                for child in children {
                    if isBlockElement(child) {
                        try processBlock(child, parentIntents: parentIntents)
                    } else {
                        // Inline child in a block context — wrap in a paragraph
                        let text = try processInlineElement(child)
                        if text.characters.isEmpty { continue }
                        let intent = PresentationIntent(.paragraph, identity: nextID())
                        let nested = nestIntent(intent, inside: parentIntents)
                        var attributed = text
                        attributed.presentationIntent = nested
                        appendBlock(&result, attributed)
                    }
                }
            }
        }

        func processBlock(_ element: Element, parentIntents: [PresentationIntent.Kind] = []) throws {
            let tag = element.tagName().lowercased()

            switch tag {
            case "p":
                let intent = PresentationIntent(.paragraph, identity: nextID())
                let nested = nestIntent(intent, inside: parentIntents)
                var text = try processInlineChildren(of: element)
                if text.characters.isEmpty { return }
                text.presentationIntent = nested
                appendBlock(&result, text)

            case "h1", "h2", "h3", "h4", "h5", "h6":
                let level = Int(String(tag.last!)) ?? 1
                let intent = PresentationIntent(.header(level: level), identity: nextID())
                let nested = nestIntent(intent, inside: parentIntents)
                var text = try processInlineChildren(of: element)
                if text.characters.isEmpty { return }
                text.presentationIntent = nested
                appendBlock(&result, text)

            case "blockquote":
                let quoteIntents = parentIntents + [.blockQuote]
                // Process children as blocks within the blockquote
                for child in element.children() {
                    try processBlock(child, parentIntents: quoteIntents)
                }
                // Handle direct text nodes in blockquote
                let directText = try directTextContent(of: element)
                if !directText.characters.isEmpty {
                    let intent = PresentationIntent(.paragraph, identity: nextID())
                    let nested = nestIntent(intent, inside: quoteIntents)
                    var text = directText
                    text.presentationIntent = nested
                    appendBlock(&result, text)
                }

            case "pre":
                let codeElement = try element.select("code").first()
                let codeText = try (codeElement ?? element).text()
                if codeText.isEmpty { return }
                let langClass = try codeElement?.className() ?? ""
                let lang = langClass.replacingOccurrences(of: "lang-", with: "")
                    .replacingOccurrences(of: "language-", with: "")
                let intentKind: PresentationIntent.Kind = lang.isEmpty
                    ? .codeBlock(languageHint: nil)
                    : .codeBlock(languageHint: lang)
                let intent = PresentationIntent(intentKind, identity: nextID())
                let nested = nestIntent(intent, inside: parentIntents)
                var text = AttributedString(codeText)
                text.presentationIntent = nested
                appendBlock(&result, text)

            case "ul":
                for (i, li) in element.children().enumerated() {
                    guard li.tagName().lowercased() == "li" else { continue }
                    try processListItem(li, ordinal: i + 1, ordered: false, parentIntents: parentIntents)
                }

            case "ol":
                for (i, li) in element.children().enumerated() {
                    guard li.tagName().lowercased() == "li" else { continue }
                    try processListItem(li, ordinal: i + 1, ordered: true, parentIntents: parentIntents)
                }

            case "table":
                try processTable(element, parentIntents: parentIntents)

            case "hr":
                let intent = PresentationIntent(.thematicBreak, identity: nextID())
                let nested = nestIntent(intent, inside: parentIntents)
                var text = AttributedString("—")
                text.presentationIntent = nested
                appendBlock(&result, text)

            case "aside":
                // Discourse oneboxes: just output the source URL as a link
                // TODO: expand oneboxes with richer preview (title, description, image)
                if let oneboxSrc = try? element.attr("data-onebox-src"), !oneboxSrc.isEmpty {
                    let resolved = resolveURL(oneboxSrc)
                    var text = AttributedString(resolved)
                    if let url = URL(string: resolved) {
                        text.link = url
                    }
                    let intent = PresentationIntent(.paragraph, identity: nextID())
                    let nested = nestIntent(intent, inside: parentIntents)
                    text.presentationIntent = nested
                    appendBlock(&result, text)
                } else {
                    // Regular aside/quote without onebox — treat as blockquote
                    let quoteIntents = parentIntents + [.blockQuote]
                    for child in element.children() {
                        try processBlock(child, parentIntents: quoteIntents)
                    }
                }

            case "div":
                // Check for media content that needs WKWebView
                if isMediaBlock(element) {
                    let intent = PresentationIntent(.paragraph, identity: nextID())
                    let nested = nestIntent(intent, inside: parentIntents)
                    let rawHTML = try element.outerHtml()
                    var text = AttributedString("[media]")
                    text.presentationIntent = nested
                    text.mediaHTML = rawHTML
                    text.mediaBaseURL = baseURL
                    appendBlock(&result, text)
                } else {
                    try processMixedChildren(of: element, parentIntents: parentIntents)
                }

            case "details":
                // Spoiler/details — render as blockquote for now
                let quoteIntents = parentIntents + [.blockQuote]
                if let summary = try element.select("summary").first() {
                    let intent = PresentationIntent(.paragraph, identity: nextID())
                    let nested = nestIntent(intent, inside: quoteIntents)
                    var text = try processInlineChildren(of: summary)
                    text.presentationIntent = nested
                    text.inlinePresentationIntent = .stronglyEmphasized
                    appendBlock(&result, text)
                }
                for child in element.children() {
                    if child.tagName().lowercased() != "summary" {
                        try processBlock(child, parentIntents: quoteIntents)
                    }
                }

            default:
                // For unknown elements, check if they contain block or inline children
                try processMixedChildren(of: element, parentIntents: parentIntents)
            }
        }

        func processListItem(_ li: Element, ordinal: Int, ordered: Bool, parentIntents: [PresentationIntent.Kind]) throws {
            let listKind: PresentationIntent.Kind = ordered ? .orderedList : .unorderedList
            let itemIntents = parentIntents + [listKind, .listItem(ordinal: ordinal)]

            // Check if li has block children
            let blockChildren = li.children().filter { isBlockElement($0) }
            if blockChildren.isEmpty {
                // Simple list item — inline content
                let intent = PresentationIntent(.paragraph, identity: nextID())
                let nested = nestIntent(intent, inside: itemIntents)
                var text = try processInlineChildren(of: li)
                if text.characters.isEmpty {
                    text = AttributedString(try li.text())
                }
                text.presentationIntent = nested
                appendBlock(&result, text)
            } else {
                // Complex list item with nested blocks
                for child in li.children() {
                    if isBlockElement(child) {
                        try processBlock(child, parentIntents: itemIntents)
                    } else {
                        let text = try processInlineChildren(of: child)
                        if text.characters.isEmpty { continue }
                        let intent = PresentationIntent(.paragraph, identity: nextID())
                        let nested = nestIntent(intent, inside: itemIntents)
                        var attributed = text
                        attributed.presentationIntent = nested
                        appendBlock(&result, attributed)
                    }
                }
            }
        }

        func processTable(_ table: Element, parentIntents: [PresentationIntent.Kind]) throws {
            var rowIndex = 0
            let tableID = nextID()

            func processRows(in container: Element, isHeader: Bool) throws {
                for tr in container.children() where tr.tagName().lowercased() == "tr" {
                    rowIndex += 1
                    let rowKind: PresentationIntent.Kind = isHeader
                        ? .tableHeaderRow
                        : .tableRow(rowIndex: rowIndex)
                    let rowID = nextID()

                    let cells = tr.children().filter {
                        let t = $0.tagName().lowercased()
                        return t == "td" || t == "th"
                    }
                    for (colIndex, cell) in cells.enumerated() {
                        let cellKind: PresentationIntent.Kind = .tableCell(columnIndex: colIndex)
                        let components: [PresentationIntent.Kind] = parentIntents + [
                            .table(columns: []),
                            rowKind,
                            cellKind
                        ]
                        var text = try processInlineChildren(of: cell)
                        if text.characters.isEmpty {
                            text = AttributedString(try cell.text())
                        }
                        // Build nested intent from components
                        var intent: PresentationIntent?
                        for (i, kind) in components.reversed().enumerated() {
                            if i == 0 {
                                intent = PresentationIntent(kind, identity: nextID())
                            } else {
                                intent = PresentationIntent(kind, identity: nextID(), parent: intent)
                            }
                        }
                        text.presentationIntent = intent
                        appendBlock(&result, text)
                    }
                }
            }

            if let thead = try table.select("thead").first() {
                try processRows(in: thead, isHeader: true)
            }
            if let tbody = try table.select("tbody").first() {
                try processRows(in: tbody, isHeader: false)
            }
            // Fallback: direct tr children
            if (try? table.select("thead").first()) == nil && (try? table.select("tbody").first()) == nil {
                try processRows(in: table, isHeader: false)
            }
        }

        func processInlineChildren(of element: Element) throws -> AttributedString {
            var result = AttributedString()
            for node in element.getChildNodes() {
                if let textNode = node as? TextNode {
                    let text = textNode.getWholeText()
                    if !text.isEmpty {
                        result.append(AttributedString(text))
                    }
                } else if let child = node as? Element {
                    let inline = try processInlineElement(child)
                    result.append(inline)
                }
            }
            return result
        }

        func processInlineElement(_ element: Element) throws -> AttributedString {
            let tag = element.tagName().lowercased()

            switch tag {
            case "strong", "b":
                var text = try processInlineChildren(of: element)
                addInlineIntent(&text, .stronglyEmphasized)
                return text

            case "em", "i":
                var text = try processInlineChildren(of: element)
                addInlineIntent(&text, .emphasized)
                return text

            case "code":
                var text = AttributedString(try element.text())
                addInlineIntent(&text, .code)
                return text

            case "s", "del", "strike":
                var text = try processInlineChildren(of: element)
                addInlineIntent(&text, .strikethrough)
                return text

            case "a":
                let href = try element.attr("href")
                var text = try processInlineChildren(of: element)
                if text.characters.isEmpty {
                    text = AttributedString(try element.text())
                }
                // Don't set link on anchor-wrapped images — the imageURL handles display
                let containsImage = text.runs.contains { $0.imageURL != nil }
                if !href.isEmpty && !containsImage {
                    let resolved = resolveURL(href)
                    if let url = URL(string: resolved) {
                        text.link = url
                    }
                }
                return text

            case "img":
                let src = try element.attr("src")
                let alt = try element.attr("alt")
                let cssClass = try element.className()

                // Discourse emoji images
                if cssClass.contains("emoji") {
                    return AttributedString(alt.isEmpty ? "🔲" : alt)
                }

                // Regular image — use ImageURL attribute for Textual
                let resolved = resolveURL(src)
                if let url = URL(string: resolved) {
                    var text = AttributedString(alt.isEmpty ? "📷" : alt)
                    text.imageURL = url
                    return text
                }
                return AttributedString(alt)

            case "br":
                return AttributedString("\n")

            case "span":
                return try processInlineChildren(of: element)

            case "sup":
                return try processInlineChildren(of: element)

            case "sub":
                // No direct PresentationIntent for subscript — just render inline
                return try processInlineChildren(of: element)

            default:
                // Unknown inline: render children
                return try processInlineChildren(of: element)
            }
        }

        // MARK: - Helpers

        func nestIntent(_ base: PresentationIntent, inside parents: [PresentationIntent.Kind]) -> PresentationIntent {
            if parents.isEmpty { return base }
            // Build chain: innermost (base) has parent chain going outward
            var current = base
            for kind in parents.reversed() {
                current = PresentationIntent(kind, identity: nextID(), parent: current)
            }
            return current
        }

        func appendBlock(_ target: inout AttributedString, _ block: AttributedString) {
            if !target.characters.isEmpty {
                target.append(AttributedString("\n"))
            }
            target.append(block)
        }

        func addInlineIntent(_ text: inout AttributedString, _ intent: InlinePresentationIntent) {
            for run in text.runs {
                let existing = text[run.range].inlinePresentationIntent ?? []
                text[run.range].inlinePresentationIntent = existing.union(intent)
            }
        }

        func resolveURL(_ urlString: String) -> String {
            if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
                return urlString
            }
            if urlString.hasPrefix("//") {
                return "https:" + urlString
            }
            let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
            let path = urlString.hasPrefix("/") ? urlString : "/" + urlString
            return base + path
        }

        func isBlockElement(_ element: Element) -> Bool {
            let blockTags: Set<String> = [
                "p", "h1", "h2", "h3", "h4", "h5", "h6",
                "blockquote", "pre", "ul", "ol", "li",
                "table", "div", "hr", "aside", "details",
                "figure", "section", "article", "header", "footer"
            ]
            return blockTags.contains(element.tagName().lowercased())
        }

        func isMediaBlock(_ element: Element) -> Bool {
            let html = (try? element.outerHtml()) ?? ""
            // Video embeds, iframes, Discourse oneboxes with media
            if !(try! element.select("iframe").isEmpty()) { return true }
            if !(try! element.select("video").isEmpty()) { return true }
            if !(try! element.select("audio").isEmpty()) { return true }
            if element.hasClass("lazyYT") { return true }
            return false
        }

        func directTextContent(of element: Element) throws -> AttributedString {
            var result = AttributedString()
            for node in element.getChildNodes() {
                if let textNode = node as? TextNode {
                    let text = textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        result.append(AttributedString(text))
                    }
                }
            }
            return result
        }

        // Process the document
        try processBlockChildren(of: body)

        if result.characters.isEmpty {
            // Fallback: just extract all text
            return AttributedString(try body.text())
        }

        return result
    }
}

// MARK: - Custom attribute for media blocks

enum MediaHTMLAttribute: AttributedStringKey {
    typealias Value = String
    static let name = "DiscourseHub.MediaHTML"
}

enum MediaBaseURLAttribute: AttributedStringKey {
    typealias Value = String
    static let name = "DiscourseHub.MediaBaseURL"
}

extension AttributeScopes {
    struct DiscourseHubAttributes: AttributeScope {
        let mediaHTML: MediaHTMLAttribute
        let mediaBaseURL: MediaBaseURLAttribute
        let foundation: FoundationAttributes
    }

    var discourseHub: DiscourseHubAttributes.Type {
        DiscourseHubAttributes.self
    }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.DiscourseHubAttributes, T>
    ) -> T {
        self[T.self]
    }
}
