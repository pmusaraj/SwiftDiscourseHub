//
//  Markdownosaur.swift
//  Based on https://github.com/christianselig/Markdownosaur
//  Modified for SwiftDiscourseHub — customized fonts, colors, and image handling.
//

#if os(iOS)
import UIKit
import Markdown

/// NSTextAttachment subclass that stores image URL and original size for async loading.
final class ScalableImageAttachment: NSTextAttachment {
    var imageURL: String?
    var originalSize: CGSize?
}

struct Markdownosaur: MarkupVisitor {
    let baseFont: UIFont
    let bodyColor: UIColor
    let codeColor: UIColor
    let codeBgColor: UIColor
    let linkColor: UIColor
    let quoteColor: UIColor
    /// Maximum width for inline images (set to body content width).
    var maxImageWidth: CGFloat = 300

    init(
        baseFont: UIFont = .preferredFont(forTextStyle: .body),
        bodyColor: UIColor = .label,
        codeColor: UIColor = .label,
        codeBgColor: UIColor = .secondarySystemFill,
        linkColor: UIColor = .systemBlue,
        quoteColor: UIColor = .secondaryLabel,
        maxImageWidth: CGFloat = 300
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

    mutating func attributedString(from document: Document) -> NSAttributedString {
        return visit(document)
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
            .foregroundColor: bodyColor
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
        let codeFont = UIFont.monospacedSystemFont(ofSize: baseFontSize * 0.9, weight: .regular)
        return NSAttributedString(string: inlineCode.code, attributes: [
            .font: codeFont,
            .foregroundColor: codeColor,
            .backgroundColor: codeBgColor
        ])
    }

    func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let codeFont = UIFont.monospacedSystemFont(ofSize: baseFontSize * 0.9, weight: .regular)
        let result = NSMutableAttributedString(string: codeBlock.code, attributes: [
            .font: codeFont,
            .foregroundColor: codeColor,
            .backgroundColor: codeBgColor
        ])
        if codeBlock.hasSuccessor {
            result.append(.singleNewline(withFontSize: baseFontSize))
        }
        return result
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

            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(unorderedList.listDepth))
            let spacingFromIndex: CGFloat = 8.0
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
            let numeralFont = UIFont.monospacedDigitSystemFont(ofSize: baseFontSize, weight: .regular)

            let listItemParagraphStyle = NSMutableParagraphStyle()

            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(orderedList.listDepth))

            let highestNumberInList = orderedList.childCount
            let numeralColumnWidth = ceil(NSAttributedString(string: "\(highestNumberInList).", attributes: [.font: numeralFont]).size().width)

            let spacingFromIndex: CGFloat = 8.0
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

        for child in blockQuote.children {
            var quoteAttributes: [NSAttributedString.Key: Any] = [:]

            let quoteParagraphStyle = NSMutableParagraphStyle()
            let baseLeftMargin: CGFloat = 15.0
            let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(blockQuote.quoteDepth))

            quoteParagraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: leftMarginOffset)]
            quoteParagraphStyle.headIndent = leftMarginOffset

            quoteAttributes[.paragraphStyle] = quoteParagraphStyle
            quoteAttributes[.font] = baseFont
            quoteAttributes[.quoteDepth] = blockQuote.quoteDepth

            let quoteAttributedString = visit(child).mutableCopy() as! NSMutableAttributedString
            quoteAttributedString.insert(NSAttributedString(string: "\t", attributes: quoteAttributes), at: 0)
            quoteAttributedString.addAttribute(.foregroundColor, value: quoteColor)

            result.append(quoteAttributedString)
        }

        if blockQuote.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }

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
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: maxWidth * 0.56)
        }

        // Placeholder tint
        attachment.image = UIImage()

        let result = NSMutableAttributedString(attachment: attachment)
        if image.hasSuccessor {
            result.append(.doubleNewline(withFontSize: baseFontSize))
        }
        return result
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}", attributes: [
            .font: baseFont,
            .foregroundColor: UIColor.separator
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
            guard let font = value as? UIFont else { return }
            addAttribute(.font, value: font.apply(newTraits: .traitItalic), range: range)
        }
    }

    func applyStrong() {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            addAttribute(.font, value: font.apply(newTraits: .traitBold), range: range)
        }
    }

    func applyLink(withURL url: URL?, color: UIColor) {
        addAttribute(.foregroundColor, value: color)
        if let url {
            addAttribute(.link, value: url)
        }
    }

    func applyHeading(withLevel level: Int, baseFontSize: CGFloat) {
        enumerateAttribute(.font, in: NSRange(location: 0, length: length), options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let headingSize = baseFontSize + CGFloat(max(6 - level, 0)) * 2
            addAttribute(.font, value: font.apply(newTraits: .traitBold, newPointSize: headingSize), range: range)
        }
    }

    func applyStrikethrough() {
        addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
    }
}

private extension UIFont {
    func apply(newTraits: UIFontDescriptor.SymbolicTraits, newPointSize: CGFloat? = nil) -> UIFont {
        var existingTraits = fontDescriptor.symbolicTraits
        existingTraits.insert(newTraits)
        guard let newDescriptor = fontDescriptor.withSymbolicTraits(existingTraits) else { return self }
        return UIFont(descriptor: newDescriptor, size: newPointSize ?? pointSize)
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
        NSAttributedString(string: "\n", attributes: [.font: UIFont.systemFont(ofSize: fontSize, weight: .regular)])
    }

    static func doubleNewline(withFontSize fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(string: "\n\n", attributes: [.font: UIFont.systemFont(ofSize: fontSize, weight: .regular)])
    }
}
#endif
