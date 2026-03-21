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
            .backgroundColor: codeBgColor
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

        for child in blockQuote.children {
            var quoteAttributes: [NSAttributedString.Key: Any] = [:]

            let quoteParagraphStyle = NSMutableParagraphStyle()
            quoteParagraphStyle.lineHeightMultiple = Theme.Quote.lineHeightMultiple
            let baseLeftMargin = Theme.Quote.baseLeftMargin
            let leftMarginOffset = baseLeftMargin + (Theme.Quote.depthIndent * CGFloat(blockQuote.quoteDepth))

            quoteParagraphStyle.firstLineHeadIndent = leftMarginOffset
            quoteParagraphStyle.headIndent = leftMarginOffset
            quoteParagraphStyle.paragraphSpacingBefore = Theme.Quote.paragraphSpacingBefore

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
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: maxWidth * Theme.Markdown.defaultImageAspect)
        }

        // Placeholder tint
        attachment.image = PlatformImage()

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
    static let codeBlock = NSAttributedString.Key("CodeBlock")
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
