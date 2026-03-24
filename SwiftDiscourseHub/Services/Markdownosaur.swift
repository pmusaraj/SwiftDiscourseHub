//
//  Markdownosaur.swift
//  Based on https://github.com/christianselig/Markdownosaur
//  Modified for SwiftDiscourseHub — customized fonts, colors, and image handling.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import Markdown

#if os(iOS)
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
typealias PlatformImage = UIImage
typealias PlatformBezierPath = UIBezierPath
typealias PlatformFontTraits = UIFontDescriptor.SymbolicTraits
#else
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
typealias PlatformImage = NSImage
typealias PlatformBezierPath = NSBezierPath
typealias PlatformFontTraits = NSFontDescriptor.SymbolicTraits
#endif

// MARK: - Platform Compatibility

extension PlatformFontTraits {
    #if os(iOS)
    static var italic: PlatformFontTraits { .traitItalic }
    static var bold: PlatformFontTraits { .traitBold }
    #endif
}

#if os(iOS)
extension UIFont {
    static var preferredBodyFont: UIFont { .preferredFont(forTextStyle: .body) }
}
extension UIColor {
    static var labelColor: UIColor { .label }
    static var secondaryLabelColor: UIColor { .secondaryLabel }
    static var secondaryFillColor: UIColor { .secondarySystemFill }
    static var linkColor: UIColor { .systemBlue }
    static var separatorColor: UIColor { .separator }
}
#else
extension NSFont {
    static var preferredBodyFont: NSFont { .systemFont(ofSize: NSFont.systemFontSize) }
}
extension NSColor {
    static var secondaryFillColor: NSColor { .unemphasizedSelectedContentBackgroundColor }
}
extension NSBezierPath {
    /// Convert NSBezierPath to CGPath for use with CoreGraphics.
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath: path.closeSubpath()
            case .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
            @unknown default: break
            }
        }
        return path
    }
}
#endif

/// NSTextAttachment subclass that stores image URL and original size for async loading.
final class ScalableImageAttachment: NSTextAttachment {
    var imageURL: String?
    var originalSize: CGSize?

    /// A 1×1 tinted image used as a placeholder while the real image loads.
    static let placeholderImage: PlatformImage = {
        let size = CGSize(width: 1, height: 1)
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.label.withAlphaComponent(Theme.Markdown.imagePlaceholderOpacity).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        #else
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.labelColor.withAlphaComponent(Theme.Markdown.imagePlaceholderOpacity).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
        #endif
    }()
}

final class VideoPlaceholderAttachment: NSTextAttachment {
    var videoURLString: String?

    static func placeholderImage(width: CGFloat, height: CGFloat) -> PlatformImage {
        let size = CGSize(width: width, height: height)
        let iconSize = Theme.Video.playIconSize
        let cornerRadius = Theme.Video.placeholderCornerRadius

        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.secondarySystemFill.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: cornerRadius).fill()

            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
            if let icon = UIImage(systemName: "play.circle.fill", withConfiguration: config)?
                .withTintColor(.white.withAlphaComponent(0.8), renderingMode: .alwaysOriginal) {
                let iconRect = CGRect(
                    x: (width - icon.size.width) / 2,
                    y: (height - icon.size.height) / 2,
                    width: icon.size.width,
                    height: icon.size.height
                )
                icon.draw(in: iconRect)
            }
        }
        #else
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.separatorColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: CGRect(origin: .zero, size: size), xRadius: cornerRadius, yRadius: cornerRadius).fill()

        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        if let icon = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Play video")?
            .withSymbolConfiguration(config) {
            let iconRect = CGRect(
                x: (width - icon.size.width) / 2,
                y: (height - icon.size.height) / 2,
                width: icon.size.width,
                height: icon.size.height
            )
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 0.8)
        }
        image.unlockFocus()
        return image
        #endif
    }
}

struct Markdownosaur: MarkupVisitor {
    let baseFont: PlatformFont
    let bodyColor: PlatformColor
    let codeColor: PlatformColor
    let codeBgColor: PlatformColor
    let linkColor: PlatformColor
    let quoteColor: PlatformColor
    /// Maximum width for inline images (set to body content width).
    var maxImageWidth: CGFloat = 300

    init(
        baseFont: PlatformFont = .systemFont(ofSize: Theme.Markdown.bodyFontSize, weight: Theme.Markdown.bodyWeight),
        bodyColor: PlatformColor = .labelColor,
        codeColor: PlatformColor = .labelColor,
        codeBgColor: PlatformColor = .secondaryFillColor,
        linkColor: PlatformColor = .linkColor,
        quoteColor: PlatformColor = .secondaryLabelColor,
        maxImageWidth: CGFloat = Theme.Markdown.defaultImageWidth
    ) {
        self.baseFont = baseFont
        self.bodyColor = bodyColor
        self.codeColor = codeColor
        self.codeBgColor = codeBgColor
        self.linkColor = linkColor
        self.quoteColor = quoteColor
        self.maxImageWidth = maxImageWidth
    }

    private var baseFontSize: CGFloat { baseFont.pointSize }

    private var baseParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = Theme.Markdown.lineHeightMultiple
        return style
    }

    mutating func attributedString(from document: Document) -> NSAttributedString {
        let result = visit(document).mutableCopy() as! NSMutableAttributedString
        Self.spliceVideoPlaceholders(into: result, maxWidth: maxImageWidth)
        return result
    }

    /// Render markdown and splice in onebox blocks for any %%ONEBOX:N%% placeholders.
    mutating func attributedString(from document: Document, oneboxes: [DiscourseMarkdownPreprocessor.OneboxInfo]) -> NSAttributedString {
        let result = visit(document).mutableCopy() as! NSMutableAttributedString
        if !oneboxes.isEmpty {
            Self.spliceOneboxes(into: result, oneboxes: oneboxes, baseFont: baseFont, linkColor: linkColor)
        }
        Self.spliceVideoPlaceholders(into: result, maxWidth: maxImageWidth)
        return result
    }

    /// Replace %%DISCOURSE_VIDEO:url%% placeholders with tappable video placeholder attachments.
    static func spliceVideoPlaceholders(into attrString: NSMutableAttributedString, maxWidth: CGFloat) {
        guard let regex = try? NSRegularExpression(pattern: DiscourseMarkdownPreprocessor.videoPlaceholderPattern) else { return }

        let text = attrString.string
        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: fullRange)

        for match in matches.reversed() {
            guard let urlRange = Range(match.range(at: 1), in: text) else { continue }
            let urlString = String(text[urlRange])

            let width = maxWidth
            let height = width * Theme.Video.placeholderAspect

            let attachment = VideoPlaceholderAttachment()
            attachment.videoURLString = urlString
            attachment.image = VideoPlaceholderAttachment.placeholderImage(width: width, height: height)
            attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)

            let attachmentString = NSMutableAttributedString(attachment: attachment)
            if let url = URL(string: urlString) {
                attachmentString.addAttributes([
                    .videoURL: urlString,
                    .link: url,
                ], range: NSRange(location: 0, length: attachmentString.length))
            }

            // Expand to consume surrounding newlines
            var replaceRange = match.range
            let nsText = text as NSString
            if replaceRange.location > 0 && nsText.character(at: replaceRange.location - 1) == 0x0A {
                replaceRange.location -= 1
                replaceRange.length += 1
            }
            let afterEnd = replaceRange.location + replaceRange.length
            if afterEnd < nsText.length && nsText.character(at: afterEnd) == 0x0A {
                replaceRange.length += 1
            }

            attrString.replaceCharacters(in: replaceRange, with: attachmentString)
        }
    }

    /// Truncate text to fit within a max pixel width, appending ellipsis if needed.
    private static func truncateToFit(_ text: String, maxWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) -> String {
        let fullWidth = (text as NSString).size(withAttributes: attributes).width
        guard fullWidth > maxWidth else { return text }
        let ellipsis = "…"
        let ellipsisWidth = (ellipsis as NSString).size(withAttributes: attributes).width
        let targetWidth = maxWidth - ellipsisWidth
        // Binary search for the longest prefix that fits
        var lo = 0, hi = text.count
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            let prefix = String(text.prefix(mid))
            let w = (prefix as NSString).size(withAttributes: attributes).width
            if w <= targetWidth { lo = mid } else { hi = mid - 1 }
        }
        return String(text.prefix(lo)) + ellipsis
    }

    /// Replace %%ONEBOX:N%% placeholders with rich link attributed string blocks.
    static func spliceOneboxes(into attrString: NSMutableAttributedString, oneboxes: [DiscourseMarkdownPreprocessor.OneboxInfo], baseFont: PlatformFont, linkColor: PlatformColor) {
        guard let regex = try? NSRegularExpression(pattern: DiscourseMarkdownPreprocessor.oneboxPlaceholderPattern) else { return }

        // Find all placeholders (process from end to preserve ranges)
        let text = attrString.string
        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: fullRange)

        for match in matches.reversed() {
            guard let indexRange = Range(match.range(at: 1), in: text),
                  let index = Int(text[indexRange]),
                  index < oneboxes.count else { continue }

            let info = oneboxes[index]
            let oneboxBlock = buildOneboxBlock(info: info, baseFont: baseFont, linkColor: linkColor)

            // Replace placeholder (and surrounding whitespace) with the onebox block
            var replaceRange = match.range

            // Expand to consume surrounding newlines for clean insertion
            let nsText = text as NSString
            if replaceRange.location > 0 && nsText.character(at: replaceRange.location - 1) == 0x0A /* \n */ {
                replaceRange.location -= 1
                replaceRange.length += 1
            }
            let afterEnd = replaceRange.location + replaceRange.length
            if afterEnd < nsText.length && nsText.character(at: afterEnd) == 0x0A {
                replaceRange.length += 1
            }

            attrString.replaceCharacters(in: replaceRange, with: oneboxBlock)
        }
    }

    /// Build a self-contained rich link NSAttributedString block from onebox info.
    static func buildOneboxBlock(info: DiscourseMarkdownPreprocessor.OneboxInfo, baseFont: PlatformFont, linkColor: PlatformColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let fontSize = baseFont.pointSize
        let inset = Theme.RichLink.horizontalPadding
        let vPad = Theme.RichLink.verticalPadding

        // --- Line 1: favicon + URL ---
        let urlParaStyle = NSMutableParagraphStyle()
        urlParaStyle.lineHeightMultiple = Theme.Markdown.lineHeightMultiple
        urlParaStyle.firstLineHeadIndent = inset
        urlParaStyle.headIndent = inset
        urlParaStyle.tailIndent = -inset
        urlParaStyle.paragraphSpacingBefore = vPad

        let smallFont = PlatformFont.systemFont(ofSize: fontSize - 3)
        let urlAttrs: [NSAttributedString.Key: Any] = [
            .font: smallFont,
            .foregroundColor: PlatformColor.secondaryLabelColor,
            .paragraphStyle: urlParaStyle,
            .richLink: true,
        ]

        // Favicon as text attachment if URL available
        if let faviconURLStr = info.faviconURL, !faviconURLStr.isEmpty {
            let attachment = ScalableImageAttachment()
            attachment.imageURL = faviconURLStr
            attachment.bounds = CGRect(x: 0, y: -2, width: smallFont.pointSize, height: smallFont.pointSize)
            attachment.image = PlatformImage()
            let faviconStr = NSMutableAttributedString(attachment: attachment)
            faviconStr.addAttributes(urlAttrs, range: NSRange(location: 0, length: faviconStr.length))
            result.append(faviconStr)
            result.append(NSAttributedString(string: " ", attributes: urlAttrs))
        }

        // Display domain (not full URL) for cleaner look
        result.append(NSAttributedString(string: info.domain + "\n", attributes: urlAttrs))

        // --- Line 2: Title as heading link ---
        let titleParaStyle = NSMutableParagraphStyle()
        titleParaStyle.lineHeightMultiple = Theme.Markdown.lineHeightMultiple
        titleParaStyle.firstLineHeadIndent = inset
        titleParaStyle.headIndent = inset
        titleParaStyle.tailIndent = -inset

        let titleFont = PlatformFont.systemFont(ofSize: fontSize + 1, weight: .semibold)
        let titleText = info.title ?? info.url
        var titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: linkColor,
            .paragraphStyle: titleParaStyle,
            .richLink: true,
        ]
        if let url = URL(string: info.url) {
            titleAttrs[.link] = url
        }

        let hasDescription = info.description != nil && !info.description!.isEmpty
        result.append(NSAttributedString(string: titleText + (hasDescription ? "\n" : ""), attributes: titleAttrs))

        // --- Lines 3-4: Description (capped to ~2 lines) ---
        if let desc = info.description, !desc.isEmpty {
            let descParaStyle = NSMutableParagraphStyle()
            descParaStyle.lineHeightMultiple = Theme.Markdown.lineHeightMultiple
            descParaStyle.firstLineHeadIndent = inset
            descParaStyle.headIndent = inset
            descParaStyle.tailIndent = -inset
            descParaStyle.paragraphSpacing = vPad + 12

            let capped = desc.count > 160 ? String(desc.prefix(157)) + "..." : desc
            let descAttrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: PlatformColor.secondaryLabelColor,
                .paragraphStyle: descParaStyle,
                .richLink: true,
            ]
            result.append(NSAttributedString(string: capped, attributes: descAttrs))
        } else {
            // No description: add bottom spacing to title
            let lastRange = NSRange(location: result.length - 1, length: 1)
            let lastParaStyle = titleParaStyle.mutableCopy() as! NSMutableParagraphStyle
            lastParaStyle.paragraphSpacing = vPad + 12
            result.addAttribute(.paragraphStyle, value: lastParaStyle, range: lastRange)
        }

        // Add trailing newline for separation from next content
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: PlatformFont.systemFont(ofSize: fontSize * 0.1),
            .richLink: true,
        ]))

        return result
    }

    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    mutating func visitText(_ text: Text) -> NSAttributedString {
        return NSAttributedString(string: text.plainText, attributes: [
            .font: baseFont,
            .foregroundColor: bodyColor,
            .paragraphStyle: baseParagraphStyle
        ])
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in emphasis.children {
            result.append(visit(child))
        }
        result.applyEmphasis()
        return result
    }

    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strong.children {
            result.append(visit(child))
        }
        result.applyStrong()
        return result
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in paragraph.children {
            result.append(visit(child))
        }
        if paragraph.hasSuccessor {
            result.append(paragraph.isContainedInList
                ? .singleNewline(withFontSize: baseFontSize)
                : .doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in heading.children {
            result.append(visit(child))
        }
        result.applyHeading(withLevel: heading.level, baseFontSize: baseFontSize)
        if heading.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitLink(_ link: Link) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in link.children {
            result.append(visit(child))
        }
        let url = link.destination.flatMap { URL(string: $0) }
        result.applyLink(withURL: url, color: linkColor)
        return result
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        let codeFont = PlatformFont.monospacedSystemFont(ofSize: baseFontSize * Theme.Markdown.codeFontScale, weight: .regular)
        return NSAttributedString(string: inlineCode.code, attributes: [
            .font: codeFont,
            .foregroundColor: codeColor,
            .inlineCode: true
        ])
    }

    func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let codeFont = PlatformFont.monospacedSystemFont(ofSize: baseFontSize * Theme.Markdown.codeFontScale, weight: .regular)
        let codeParagraphStyle = NSMutableParagraphStyle()
        codeParagraphStyle.lineHeightMultiple = Theme.Markdown.codeBlockLineHeightMultiple
        codeParagraphStyle.firstLineHeadIndent = Theme.Markdown.codeBlockHorizontalPadding
        codeParagraphStyle.headIndent = Theme.Markdown.codeBlockHorizontalPadding
        codeParagraphStyle.tailIndent = -Theme.Markdown.codeBlockHorizontalPadding
        codeParagraphStyle.paragraphSpacingBefore = Theme.Markdown.codeBlockVerticalPadding
        let result = NSMutableAttributedString(string: codeBlock.code, attributes: [
            .font: codeFont,
            .foregroundColor: codeColor,
            .paragraphStyle: codeParagraphStyle,
            .codeBlock: true
        ])

        // Apply syntax highlighting
        SyntaxHighlighter.highlight(result, language: codeBlock.language, font: codeFont)

        if codeBlock.hasSuccessor {
            result.append(.singleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    // MARK: - Table

    mutating func visitTable(_ table: Markdown.Table) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Collect all rows (head + body) to calculate column widths
        var allRows: [[String]] = []
        var headRow: [String] = []

        if let head = table.head as? Markdown.Table.Head {
            for cell in head.cells {
                headRow.append(cell.plainText)
            }
            allRows.append(headRow)
        }

        if let body = table.body as? Markdown.Table.Body {
            for row in body.rows {
                var rowTexts: [String] = []
                for cell in row.cells {
                    rowTexts.append(cell.plainText)
                }
                allRows.append(rowTexts)
            }
        }

        guard !allRows.isEmpty else { return result }

        let columnCount = allRows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return result }

        // Measure max column widths for tab stop alignment
        let headerFont = PlatformFont.systemFont(ofSize: baseFontSize, weight: Theme.Table.headerWeight)
        let bodyMeasureAttrs: [NSAttributedString.Key: Any] = [.font: baseFont]
        let headerMeasureAttrs: [NSAttributedString.Key: Any] = [.font: headerFont]
        var columnWidths = [CGFloat](repeating: 0, count: columnCount)

        for (rowIndex, row) in allRows.enumerated() {
            let isHeader = rowIndex == 0 && !headRow.isEmpty
            let attrs = isHeader ? headerMeasureAttrs : bodyMeasureAttrs
            for (colIndex, cell) in row.enumerated() where colIndex < columnCount {
                let cellWidth = (cell as NSString).size(withAttributes: attrs).width
                columnWidths[colIndex] = max(columnWidths[colIndex], cellWidth)
            }
        }

        // Cap column widths to prevent bleeding
        let maxWidth = Theme.Table.maxColumnWidth
        columnWidths = columnWidths.map { min($0, maxWidth) }

        // Build tab stops from measured widths
        let gap = Theme.Table.columnGap
        var tabStops: [NSTextTab] = []
        var offset: CGFloat = 0
        for colIndex in 0..<columnCount {
            if colIndex > 0 {
                offset += gap
                tabStops.append(NSTextTab(textAlignment: .left, location: offset))
            }
            offset += columnWidths[colIndex]
        }

        let tableParagraphStyle = NSMutableParagraphStyle()
        tableParagraphStyle.lineHeightMultiple = Theme.Markdown.lineHeightMultiple
        tableParagraphStyle.tabStops = tabStops

        // Build tab-separated rows, truncating cells that exceed column width
        for (rowIndex, row) in allRows.enumerated() {
            let isHeader = rowIndex == 0 && !headRow.isEmpty
            let font = isHeader ? headerFont : baseFont
            let measureAttrs: [NSAttributedString.Key: Any] = [.font: font]

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: bodyColor,
                .paragraphStyle: tableParagraphStyle,
            ]

            let cells = (0..<columnCount).map { i -> String in
                let text = i < row.count ? row[i] : ""
                return Self.truncateToFit(text, maxWidth: columnWidths[i], attributes: measureAttrs)
            }
            let lineText = cells.joined(separator: "\t") + "\n"
            result.append(NSAttributedString(string: lineText, attributes: attrs))
        }

        // Remove trailing newline from last row and add spacing
        if result.length > 0 && result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }

        if table.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitTableHead(_ tableHead: Markdown.Table.Head) -> NSAttributedString {
        return defaultVisit(tableHead)
    }

    mutating func visitTableBody(_ tableBody: Markdown.Table.Body) -> NSAttributedString {
        return defaultVisit(tableBody)
    }

    mutating func visitTableRow(_ tableRow: Markdown.Table.Row) -> NSAttributedString {
        return defaultVisit(tableRow)
    }

    mutating func visitTableCell(_ tableCell: Markdown.Table.Cell) -> NSAttributedString {
        return defaultVisit(tableCell)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in strikethrough.children {
            result.append(visit(child))
        }
        result.applyStrikethrough()
        return result
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = baseFont

        for listItem in unorderedList.listItems {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]

            let listItemParagraphStyle = NSMutableParagraphStyle()
            listItemParagraphStyle.lineHeightMultiple = Theme.Markdown.lineHeightMultiple

            let baseLeftMargin = Theme.Markdown.listBaseLeftMargin
            let leftMarginOffset = baseLeftMargin + (Theme.Markdown.listDepthIndent * CGFloat(unorderedList.listDepth))
            let spacingFromIndex = Theme.Markdown.listItemSpacing
            let bulletWidth = ceil(NSAttributedString(string: "\u{2022}", attributes: [.font: font]).size().width)
            let firstTabLocation = leftMarginOffset + bulletWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex

            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]
            listItemParagraphStyle.headIndent = secondTabLocation

            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = font
            listItemAttributes[.foregroundColor] = bodyColor
            listItemAttributes[.listDepth] = unorderedList.listDepth

            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString
            listItemAttributedString.insert(NSAttributedString(string: "\t\u{2022}\t", attributes: listItemAttributes), at: 0)

            result.append(listItemAttributedString)
        }

        if unorderedList.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }

        return result
    }

    mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in listItem.children {
            result.append(visit(child))
        }
        if listItem.hasSuccessor {
            result.append(.singleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, listItem) in orderedList.listItems.enumerated() {
            var listItemAttributes: [NSAttributedString.Key: Any] = [:]

            let font = baseFont
            let numeralFont = PlatformFont.monospacedDigitSystemFont(ofSize: baseFontSize, weight: .regular)

            let listItemParagraphStyle = NSMutableParagraphStyle()
            listItemParagraphStyle.lineHeightMultiple = Theme.Markdown.lineHeightMultiple

            let baseLeftMargin = Theme.Markdown.listBaseLeftMargin
            let leftMarginOffset = baseLeftMargin + (Theme.Markdown.listDepthIndent * CGFloat(orderedList.listDepth))

            let highestNumberInList = orderedList.childCount
            let numeralColumnWidth = ceil(NSAttributedString(string: "\(highestNumberInList).", attributes: [.font: numeralFont]).size().width)

            let spacingFromIndex = Theme.Markdown.listItemSpacing
            let firstTabLocation = leftMarginOffset + numeralColumnWidth
            let secondTabLocation = firstTabLocation + spacingFromIndex

            listItemParagraphStyle.tabStops = [
                NSTextTab(textAlignment: .right, location: firstTabLocation),
                NSTextTab(textAlignment: .left, location: secondTabLocation)
            ]
            listItemParagraphStyle.headIndent = secondTabLocation

            listItemAttributes[.paragraphStyle] = listItemParagraphStyle
            listItemAttributes[.font] = font
            listItemAttributes[.foregroundColor] = bodyColor
            listItemAttributes[.listDepth] = orderedList.listDepth

            let listItemAttributedString = visit(listItem).mutableCopy() as! NSMutableAttributedString

            var numberAttributes = listItemAttributes
            numberAttributes[.font] = numeralFont
            listItemAttributedString.insert(NSAttributedString(string: "\t\(index + 1).\t", attributes: numberAttributes), at: 0)

            result.append(listItemAttributedString)
        }

        if orderedList.hasSuccessor {
            result.append(orderedList.isContainedInList
                ? .singleNewline(withFontSize: baseFontSize)
                : .doubleNewline(withFontSize: baseFontSize))
        }

        return result
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let children = Array(blockQuote.children)
        let vPad = Theme.Quote.backgroundVerticalPad

        // Always insert a spacing newline before the quote so the background
        // has room to render. paragraphSpacingBefore is ignored on the very
        // first paragraph in a text view, so even the first element needs this.
        result.append(.singleNewline(withFontSize: baseFontSize))

        for (index, child) in children.enumerated() {
            var quoteAttributes: [NSAttributedString.Key: Any] = [:]

            let quoteParagraphStyle = NSMutableParagraphStyle()
            quoteParagraphStyle.lineHeightMultiple = Theme.Quote.lineHeightMultiple
            let baseLeftMargin = Theme.Quote.baseLeftMargin
            let leftMarginOffset = baseLeftMargin + (Theme.Quote.depthIndent * CGFloat(blockQuote.quoteDepth))

            quoteParagraphStyle.firstLineHeadIndent = leftMarginOffset
            quoteParagraphStyle.headIndent = leftMarginOffset

            // First child: top padding to match background
            quoteParagraphStyle.paragraphSpacingBefore = index == 0 ? vPad : Theme.Quote.paragraphSpacingBefore
            // Last child: bottom padding to match background
            if index == children.count - 1 {
                quoteParagraphStyle.paragraphSpacing = vPad
            }

            quoteAttributes[.paragraphStyle] = quoteParagraphStyle
            quoteAttributes[.font] = baseFont
            quoteAttributes[.quoteDepth] = blockQuote.quoteDepth

            let quoteAttributedString = visit(child).mutableCopy() as! NSMutableAttributedString
            quoteAttributedString.addAttribute(.foregroundColor, value: quoteColor)

            // Apply paragraph style to full range so all lines indent
            quoteAttributedString.addAttribute(.paragraphStyle, value: quoteParagraphStyle)
            quoteAttributedString.addAttribute(.quoteDepth, value: blockQuote.quoteDepth)

            result.append(quoteAttributedString)
        }

        // Single trailing newline gives the background room to render.
        // The quote's last paragraph already has paragraphSpacing = vPad.
        result.append(.singleNewline(withFontSize: baseFontSize))

        return result
    }

    mutating func visitImage(_ image: Image) -> NSAttributedString {
        guard let source = image.source, !source.isEmpty else {
            let alt = image.plainText.isEmpty ? "image" : image.plainText
            return NSAttributedString(string: "[\(alt)]", attributes: [
                .font: baseFont,
                .foregroundColor: linkColor
            ])
        }

        let attachment = ScalableImageAttachment()
        attachment.imageURL = source

        // Parse #dim=WxH fragment for pre-sizing
        if let fragment = URLComponents(string: source)?.fragment,
           fragment.hasPrefix("dim=") {
            let dims = fragment.dropFirst(4).split(separator: "x")
            if dims.count == 2,
               let w = Double(dims[0]),
               let h = Double(dims[1]),
               w > 0, h > 0 {
                attachment.originalSize = CGSize(width: w, height: h)
            }
        }

        // Scale to fit available width (will be updated in PostCell if needed)
        let maxWidth = maxImageWidth
        if let orig = attachment.originalSize {
            let scale = min(maxWidth / orig.width, 1.0)
            let scaledW = orig.width * scale
            let scaledH = orig.height * scale
            attachment.bounds = CGRect(x: 0, y: 0, width: scaledW, height: scaledH)
        } else {
            // Default placeholder size for images without dimensions
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: maxWidth * Theme.Markdown.defaultImageAspect)
        }

        attachment.image = ScalableImageAttachment.placeholderImage

        let result = NSMutableAttributedString(attachment: attachment)
        if image.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}", attributes: [
            .font: baseFont,
            .foregroundColor: PlatformColor.separatorColor
        ])
        if thematicBreak.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSAttributedString {
        return NSAttributedString(string: " ", attributes: [.font: baseFont])
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
        return .singleNewline(withFontSize: baseFontSize)
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> NSAttributedString {
        // Strip HTML tags and render as plain text
        let stripped = html.rawHTML.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let result = NSMutableAttributedString(string: stripped.trimmingCharacters(in: .whitespacesAndNewlines), attributes: [
            .font: baseFont,
            .foregroundColor: bodyColor
        ])
        if html.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitInlineHTML(_ html: InlineHTML) -> NSAttributedString {
        // Strip HTML tags
        let stripped = html.rawHTML.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return NSAttributedString(string: stripped, attributes: [
            .font: baseFont,
            .foregroundColor: bodyColor
        ])
    }
}

// MARK: - Extensions

extension NSMutableAttributedString {
    func applyEmphasis() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? PlatformFont else { return }
            addAttribute(.font, value: font.apply(newTraits: .italic), range: range)
        }
    }

    func applyStrong() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? PlatformFont else { return }
            addAttribute(.font, value: font.apply(newTraits: .bold), range: range)
        }
    }

    func applyLink(withURL url: URL?, color: PlatformColor) {
        addAttribute(.foregroundColor, value: color)
        if let url {
            addAttribute(.link, value: url)
        }
    }

    func applyHeading(withLevel level: Int, baseFontSize: CGFloat) {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? PlatformFont else { return }
            let headingSize = baseFontSize + CGFloat(max(6 - level, 0)) * Theme.Markdown.headingBonusPerLevel
            addAttribute(.font, value: font.apply(newTraits: .bold, newPointSize: headingSize), range: range)
        }
    }

    func applyStrikethrough() {
        addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
    }
}

private extension PlatformFont {
    func apply(newTraits: PlatformFontTraits, newPointSize: CGFloat? = nil) -> PlatformFont {
        #if os(iOS)
        var existingTraits = fontDescriptor.symbolicTraits
        existingTraits.insert(newTraits)
        guard let newDescriptor = fontDescriptor.withSymbolicTraits(existingTraits) else { return self }
        return PlatformFont(descriptor: newDescriptor, size: newPointSize ?? pointSize)
        #else
        var existingTraits = fontDescriptor.symbolicTraits
        existingTraits.insert(newTraits)
        let newDescriptor = fontDescriptor.withSymbolicTraits(existingTraits)
        return PlatformFont(descriptor: newDescriptor, size: newPointSize ?? pointSize) ?? self
        #endif
    }
}

extension ListItemContainer {
    var listDepth: Int {
        var index = 0
        var currentElement = parent
        while currentElement != nil {
            if currentElement is ListItemContainer { index += 1 }
            currentElement = currentElement?.parent
        }
        return index
    }
}

extension BlockQuote {
    var quoteDepth: Int {
        var index = 0
        var currentElement = parent
        while currentElement != nil {
            if currentElement is BlockQuote { index += 1 }
            currentElement = currentElement?.parent
        }
        return index
    }
}

extension NSAttributedString.Key {
    static let listDepth = NSAttributedString.Key("ListDepth")
    static let quoteDepth = NSAttributedString.Key("QuoteDepth")
    static let inlineCode = NSAttributedString.Key("InlineCode")
    static let codeBlock = NSAttributedString.Key("CodeBlock")
    static let richLink = NSAttributedString.Key("RichLink")
    static let videoURL = NSAttributedString.Key("VideoURL")
}

private extension NSMutableAttributedString {
    func addAttribute(_ name: NSAttributedString.Key, value: Any) {
        addAttribute(name, value: value, range: NSRange(location: 0, length: length))
    }
}

extension Markup {
    var hasSuccessor: Bool {
        guard let childCount = parent?.childCount else { return false }
        return indexInParent < childCount - 1
    }

    var isContainedInList: Bool {
        var currentElement = parent
        while currentElement != nil {
            if currentElement is ListItemContainer { return true }
            currentElement = currentElement?.parent
        }
        return false
    }
}

extension NSAttributedString {
    static func singleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: [.font: PlatformFont.systemFont(ofSize: fontSize, weight: .regular)])
    }

    static func doubleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(string: "\n\n", attributes: [.font: PlatformFont.systemFont(ofSize: fontSize, weight: .regular)])
    }
}

// MARK: - Syntax Highlighting

/// Applies regex-based syntax highlighting to code block attributed strings.
enum SyntaxHighlighter {

    private static func color(hex: String) -> PlatformColor {
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        return PlatformColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }

    private static let keywordColor = color(hex: Theme.SyntaxHighlight.keyword)
    private static let stringColor = color(hex: Theme.SyntaxHighlight.string)
    private static let commentColor = color(hex: Theme.SyntaxHighlight.comment)
    private static let numberColor = color(hex: Theme.SyntaxHighlight.number)
    private static let typeColor = color(hex: Theme.SyntaxHighlight.type)
    private static let attributeColor = color(hex: Theme.SyntaxHighlight.attribute)

    // Language keyword sets
    private static let swiftKeywords: Set<String> = [
        "import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
        "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
        "return", "break", "continue", "throw", "throws", "try", "catch", "do",
        "public", "private", "internal", "fileprivate", "open", "static", "final",
        "override", "mutating", "async", "await", "actor", "some", "any",
        "self", "Self", "super", "nil", "true", "false", "in", "where", "as", "is",
        "typealias", "associatedtype", "init", "deinit", "subscript", "convenience",
        "lazy", "weak", "unowned", "willSet", "didSet", "get", "set",
        "inout", "defer", "fallthrough", "indirect", "nonisolated", "sending",
    ]

    private static let jsKeywords: Set<String> = [
        "function", "var", "let", "const", "if", "else", "for", "while", "do",
        "return", "break", "continue", "switch", "case", "default", "throw", "try",
        "catch", "finally", "new", "delete", "typeof", "instanceof", "in", "of",
        "class", "extends", "super", "this", "import", "export", "from", "as",
        "async", "await", "yield", "true", "false", "null", "undefined", "void",
        "static", "get", "set", "constructor",
    ]

    private static let pythonKeywords: Set<String> = [
        "def", "class", "if", "elif", "else", "for", "while", "return", "import",
        "from", "as", "try", "except", "finally", "raise", "with", "pass", "break",
        "continue", "and", "or", "not", "is", "in", "lambda", "yield", "global",
        "nonlocal", "assert", "del", "True", "False", "None", "async", "await",
        "self",
    ]

    private static let rubyKeywords: Set<String> = [
        "def", "end", "class", "module", "if", "elsif", "else", "unless", "case",
        "when", "while", "until", "for", "do", "begin", "rescue", "ensure", "raise",
        "return", "yield", "block_given?", "require", "include", "extend", "attr_accessor",
        "attr_reader", "attr_writer", "self", "super", "nil", "true", "false",
        "and", "or", "not", "in", "then", "puts", "print",
    ]

    private static let genericKeywords: Set<String> = [
        "if", "else", "for", "while", "return", "break", "continue", "switch",
        "case", "default", "class", "function", "var", "let", "const", "import",
        "true", "false", "null", "nil", "void", "new", "this", "self", "super",
        "try", "catch", "throw", "public", "private", "static", "final",
    ]

    private static func keywords(for language: String?) -> Set<String> {
        switch language?.lowercased() {
        case "swift": return swiftKeywords
        case "javascript", "js", "typescript", "ts", "jsx", "tsx": return jsKeywords
        case "python", "py": return pythonKeywords
        case "ruby", "rb": return rubyKeywords
        default: return genericKeywords
        }
    }

    /// Highlight patterns in order: comments, strings, numbers, keywords, types.
    /// Earlier matches take priority (won't be overwritten).
    static func highlight(_ attrString: NSMutableAttributedString, language: String?, font: PlatformFont) {
        let code = attrString.string
        let fullRange = NSRange(location: 0, length: attrString.length)
        var colored = IndexSet() // tracks already-colored character indices

        // Helper to apply color only to uncolored ranges
        func applyColor(_ color: PlatformColor, range: NSRange) {
            let requested = IndexSet(integersIn: range.location..<(range.location + range.length))
            let uncolored = requested.subtracting(colored)
            for r in uncolored.rangeView {
                attrString.addAttribute(.foregroundColor, value: color, range: NSRange(location: r.lowerBound, length: r.count))
            }
            colored.formUnion(requested)
        }

        func applyPattern(_ pattern: String, color: PlatformColor, options: NSRegularExpression.Options = []) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            for match in regex.matches(in: code, range: fullRange) {
                applyColor(color, range: match.range)
            }
        }

        // 1. Comments (highest priority)
        applyPattern(#"//[^\n]*"#, color: commentColor)                    // single-line
        applyPattern(#"/\*[\s\S]*?\*/"#, color: commentColor, options: .dotMatchesLineSeparators) // multi-line
        applyPattern(#"#[^\n]*"#, color: commentColor)                     // Python/Ruby/shell

        // 2. Strings
        applyPattern(#""""[\s\S]*?""""#, color: stringColor, options: .dotMatchesLineSeparators) // triple-quote
        applyPattern(#""(?:[^"\\]|\\.)*""#, color: stringColor)            // double-quoted
        applyPattern(#"'(?:[^'\\]|\\.)*'"#, color: stringColor)            // single-quoted
        applyPattern(#"`(?:[^`\\]|\\.)*`"#, color: stringColor)            // backtick (JS template)

        // 3. Numbers
        applyPattern(#"\b(?:0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|\d+\.?\d*(?:[eE][+-]?\d+)?)\b"#, color: numberColor)

        // 4. Keywords
        let kws = keywords(for: language)
        if !kws.isEmpty {
            let escaped = kws.map { NSRegularExpression.escapedPattern(for: $0) }
            let pattern = "\\b(?:" + escaped.joined(separator: "|") + ")\\b"
            applyPattern(pattern, color: keywordColor)
        }

        // 5. Types (capitalized identifiers)
        applyPattern(#"\b[A-Z][a-zA-Z0-9]*\b"#, color: typeColor)

        // 6. Attributes/decorators (@something)
        applyPattern(#"@\w+"#, color: attributeColor)

        _ = fullRange // suppress unused warning
    }
}

// MARK: - Quote Bar Layout Manager

/// Custom layout manager that draws styled backgrounds for blockquotes
/// (`.quoteDepth` attribute) and code blocks (`.codeBlock` attribute).
final class QuoteBarLayoutManager: NSLayoutManager {

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        #if os(iOS)
        guard let textStorage = textStorage, let context = UIGraphicsGetCurrentContext() else { return }
        #else
        guard let textStorage = textStorage, let context = NSGraphicsContext.current?.cgContext else { return }
        #endif

        let characterRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        #if os(iOS)
        let containerWidth = textContainers.first?.size.width ?? 0
        #else
        let containerWidth = textContainers.first?.containerSize.width ?? 0
        #endif

        // --- Blockquotes ---
        textStorage.enumerateAttribute(.quoteDepth, in: characterRange, options: []) { value, attrRange, _ in
            guard let depth = value as? Int, depth >= 0 else { return }

            let rects = lineFragmentRects(forCharacterRange: attrRange)
            guard !rects.isEmpty else { return }

            let fullRect = rects.reduce(rects[0]) { $0.union($1) }
            let vPad = Theme.Quote.backgroundVerticalPad
            let cornerRadius = Theme.Quote.backgroundCornerRadius

            // Full-width background
            let bgRect = CGRect(
                x: origin.x,
                y: fullRect.minY + origin.y - vPad,
                width: containerWidth,
                height: fullRect.height + vPad * 2
            )
            context.saveGState()
            context.setFillColor(PlatformColor.separatorColor.withAlphaComponent(Theme.Quote.backgroundOpacity).cgColor)
            fillRoundedRect(bgRect, cornerRadius: cornerRadius, in: context)
            context.restoreGState()

            // Vertical bar
            let barWidth = Theme.Quote.barWidth
            let barRect = CGRect(
                x: origin.x + Theme.Quote.barInset,
                y: bgRect.minY,
                width: barWidth,
                height: bgRect.height
            )
            context.setFillColor(PlatformColor.separatorColor.cgColor)
            fillRoundedRect(barRect, cornerRadius: barWidth / 2, in: context)
        }

        // --- Code blocks ---
        textStorage.enumerateAttribute(.codeBlock, in: characterRange, options: []) { value, attrRange, _ in
            guard value != nil else { return }

            let rects = lineFragmentRects(forCharacterRange: attrRange)
            guard !rects.isEmpty else { return }

            let fullRect = rects.reduce(rects[0]) { $0.union($1) }
            let vPad = Theme.Markdown.codeBlockVerticalPadding
            let cornerRadius = Theme.Markdown.codeBlockCornerRadius

            let bgRect = CGRect(
                x: origin.x,
                y: fullRect.minY + origin.y - vPad,
                width: containerWidth,
                height: fullRect.height + vPad * 2
            )
            context.saveGState()
            context.setFillColor(PlatformColor.separatorColor.withAlphaComponent(Theme.Markdown.codeBlockBackgroundOpacity).cgColor)
            fillRoundedRect(bgRect, cornerRadius: cornerRadius, in: context)
            context.restoreGState()
        }

        // --- Inline code ---
        if let tc = textContainers.first {
            drawInlineCodeBackgrounds(textStorage: textStorage, characterRange: characterRange, textContainer: tc, origin: origin, context: context)
        }

        // --- Rich links ---
        textStorage.enumerateAttribute(.richLink, in: characterRange, options: []) { value, attrRange, _ in
            guard value != nil else { return }

            let rects = lineFragmentRects(forCharacterRange: attrRange)
            guard !rects.isEmpty else { return }

            let fullRect = rects.reduce(rects[0]) { $0.union($1) }
            let cornerRadius = Theme.RichLink.cornerRadius

            let bgRect = CGRect(
                x: origin.x,
                y: fullRect.minY + origin.y,
                width: containerWidth,
                height: fullRect.height
            )

            // Light border only
            context.saveGState()
            context.setStrokeColor(PlatformColor.separatorColor.withAlphaComponent(Theme.RichLink.borderOpacity).cgColor)
            context.setLineWidth(Theme.RichLink.borderWidth)
            #if os(iOS)
            let borderPath = UIBezierPath(roundedRect: bgRect, cornerRadius: cornerRadius)
            context.addPath(borderPath.cgPath)
            #else
            let borderPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
            context.addPath(borderPath.cgPath)
            #endif
            context.strokePath()
            context.restoreGState()
        }
    }

    // MARK: - Helpers

    private func lineFragmentRects(forCharacterRange attrRange: NSRange) -> [CGRect] {
        let glyphRange = self.glyphRange(forCharacterRange: attrRange, actualCharacterRange: nil)
        var rects: [CGRect] = []
        enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            rects.append(usedRect)
        }
        return rects
    }

    private func drawInlineCodeBackgrounds(textStorage: NSTextStorage, characterRange: NSRange, textContainer: NSTextContainer, origin: CGPoint, context: CGContext) {
        textStorage.enumerateAttribute(.inlineCode, in: characterRange, options: []) { (value: Any?, attrRange: NSRange, _: UnsafeMutablePointer<ObjCBool>) in
            guard value != nil else { return }

            let glyphRange = self.glyphRange(forCharacterRange: attrRange, actualCharacterRange: nil)
            let rect = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            let hPad = Theme.Markdown.inlineCodePaddingHorizontal
            let vPad = Theme.Markdown.inlineCodePaddingVertical
            let bgRect = CGRect(
                x: rect.minX + origin.x - hPad,
                y: rect.minY + origin.y - vPad,
                width: rect.width + hPad * 2,
                height: rect.height + vPad * 2
            )
            context.saveGState()
            context.setFillColor(PlatformColor.separatorColor.withAlphaComponent(Theme.Markdown.inlineCodeBackgroundOpacity).cgColor)
            self.fillRoundedRect(bgRect, cornerRadius: Theme.Markdown.inlineCodeCornerRadius, in: context)
            context.restoreGState()
        }
    }

    private func fillRoundedRect(_ rect: CGRect, cornerRadius: CGFloat, in context: CGContext) {
        #if os(iOS)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        #else
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        context.addPath(path.cgPath)
        #endif
        context.fillPath()
    }
}
