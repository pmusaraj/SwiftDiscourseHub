import SwiftUI
import Textual

// MARK: - Discourse Style

struct DiscourseStyle: StructuredText.Style {
    let inlineStyle: InlineStyle = InlineStyle()
        .code(.monospaced, .backgroundColor(.secondary.opacity(Theme.PostBody.inlineCodeBgOpacity)))
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
    func makeBody(configuration: Configuration) -> some View {
        let level = min(configuration.headingLevel, 6)
        let scale = Theme.PostBody.headingFontScales[level - 1]

        configuration.label
            .textual.fontScale(scale)
            .textual.lineSpacing(.fontScaled(Theme.PostBody.headingLineSpacing))
            .textual.blockSpacing(.fontScaled(top: Theme.PostBody.headingBlockSpacingTop, bottom: Theme.PostBody.headingBlockSpacingBottom))
            .fontWeight(.bold)
    }
}

// MARK: - Paragraph

struct DiscourseParagraphStyle: StructuredText.ParagraphStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textual.fontScale(Theme.PostBody.paragraphFontScale)
            .textual.lineSpacing(.fontScaled(Theme.PostBody.paragraphLineSpacing))
            .textual.blockSpacing(.fontScaled(top: Theme.PostBody.paragraphBlockSpacingTop))
    }
}

// MARK: - Block Quote

struct DiscourseBlockQuoteStyle: StructuredText.BlockQuoteStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .textual.lineSpacing(.fontScaled(Theme.PostBody.blockQuoteLineSpacing))
            .textual.padding(.fontScaled(Theme.PostBody.blockQuotePadding))
            .background {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(Theme.PostBody.blockQuoteBgOpacity))
                    Rectangle()
                        .fill(Color.secondary.opacity(Theme.PostBody.blockQuoteBarOpacity))
                        .frame(width: Theme.PostBody.blockQuoteBarWidth, alignment: .leading)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.PostBody.blockQuoteCornerRadius))
            }
    }
}

// MARK: - Code Block

struct DiscourseCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        Overflow {
            configuration.label
                .textual.lineSpacing(.fontScaled(Theme.PostBody.codeBlockLineSpacing))
                .textual.fontScale(Theme.PostBody.codeBlockFontScale)
                .fixedSize(horizontal: false, vertical: true)
                .monospaced()
                .padding(.vertical, Theme.PostBody.codeBlockPaddingVertical)
                .padding(.horizontal, Theme.PostBody.codeBlockPaddingHorizontal)
        }
        .background(Color.secondary.opacity(Theme.PostBody.codeBlockBgOpacity))
        .clipShape(.rect(cornerRadius: Theme.PostBody.codeBlockCornerRadius))
        .textual.blockSpacing(.fontScaled(top: Theme.PostBody.codeBlockBlockSpacingTop, bottom: 0))
    }
}
