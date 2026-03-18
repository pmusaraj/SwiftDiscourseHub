import SwiftUI
import Textual

// MARK: - Discourse Style

struct DiscourseStyle: StructuredText.Style {
    let inlineStyle: InlineStyle = InlineStyle()
        .code(.monospaced, .backgroundColor(.secondary.opacity(0.12)))
        .strong(.fontWeight(.semibold))
        .link(.foregroundColor(.accentColor))

    let headingStyle = DiscourseHeadingStyle()
    let paragraphStyle = DiscourseParagraphStyle()
    let blockQuoteStyle = DiscourseBlockQuoteStyle()
    let codeBlockStyle = DiscourseCodeBlockStyle()
    let listItemStyle: StructuredText.DefaultListItemStyle = .default
    let unorderedListMarker: StructuredText.SymbolListMarker = .disc
    let orderedListMarker: StructuredText.DecimalListMarker = .decimal
    let tableStyle: StructuredText.DefaultTableStyle = .default
    let tableCellStyle: StructuredText.DefaultTableCellStyle = .default
    let thematicBreakStyle: StructuredText.DividerThematicBreakStyle = .divider
}

// MARK: - Heading

struct DiscourseHeadingStyle: StructuredText.HeadingStyle {
    private static let fontScales: [CGFloat] = [2.0, 1.6, 1.4, 1.2, 1.1, 1.0]

    func makeBody(configuration: Configuration) -> some View {
        let level = min(configuration.headingLevel, 6)
        let scale = Self.fontScales[level - 1]

        configuration.label
            .textual.fontScale(scale)
            .textual.lineSpacing(.fontScaled(0.15))
            .textual.blockSpacing(.fontScaled(top: 1.4, bottom: 0.6))
            .fontWeight(.bold)
    }
}

// MARK: - Paragraph

struct DiscourseParagraphStyle: StructuredText.ParagraphStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.fontScale(1.2)
            .textual.lineSpacing(.fontScaled(0.5))
            .textual.blockSpacing(.fontScaled(top: 0.6))
    }
}

// MARK: - Block Quote

struct DiscourseBlockQuoteStyle: StructuredText.BlockQuoteStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .textual.lineSpacing(.fontScaled(0.3))
            .textual.padding(.fontScaled(0.8))
            .background {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.06))
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 4, alignment: .leading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
    }
}

// MARK: - Code Block

struct DiscourseCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        Overflow {
            configuration.label
                .textual.lineSpacing(.fontScaled(0.35))
                .textual.fontScale(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .monospaced()
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
        }
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .textual.blockSpacing(.fontScaled(top: 0.8, bottom: 0))
    }
}
