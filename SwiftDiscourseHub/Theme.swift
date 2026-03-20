import SwiftUI



private let _isTablet: Bool = {
    #if os(iOS)
    MainActor.assumeIsolated { UIDevice.current.userInterfaceIdiom == .pad }
    #else
    false
    #endif
}()

enum Theme {

    static let isTablet: Bool = _isTablet

    // MARK: - Fonts

    enum Fonts {
        static let topicTitle: Font = isTablet ? .headline.bold() : .title3.bold()
        static let topicExcerpt: Font = isTablet ? .subheadline : .body
        static let postAuthorName: Font = isTablet ? .subheadline.bold() : .body.bold()
        static let postBody: Font = isTablet ? .subheadline : .body
        static let metadata: Font = isTablet ? .subheadline : .body
        static let metadataSmall: Font = .caption
        static let statCount: Font = isTablet ? .caption : .subheadline
        static let topicHeaderTitle: Font = isTablet ? .title3.bold() : .title2.bold()
        static let sidebarIcon: Font = .title3
        static let siteIconFallback: Font = .title2.bold()
        static let discoverSiteTitle: Font = isTablet ? .headline.bold() : .title3.bold()
        static let discoverSiteDescription: Font = isTablet ? .subheadline : .body
        static let discoverSiteStats: Font = isTablet ? .subheadline : .body
        static let discoverCategory: Font = isTablet ? .caption : .subheadline
        static let categoryListTitle: Font = isTablet ? .subheadline.bold() : .headline
        static let categoryListDescription: Font = isTablet ? .caption : .subheadline
        static let categoryListStats: Font = .caption
    }

    // MARK: - Spacing (HStack / VStack gaps)

    enum Spacing {
        static let topicRowHorizontal: CGFloat = 10
        static let topicRowVertical: CGFloat = 10
        static let topicRowStats: CGFloat = 12
        static let metadataItems: CGFloat = 6
        static let postContentVertical: CGFloat = 8
        static let postHeaderToBody: CGFloat = 16
        static let postBodyToFooter: CGFloat = 16
        static let placeholderVertical: CGFloat = 20
        static let postHeaderHorizontal: CGFloat = 8
        static let postAuthorVertical: CGFloat = 1
        static let postNameItems: CGFloat = 4
        static let postFooterHorizontal: CGFloat = 16
        static let categoryBadgeHorizontal: CGFloat = 4
        static let topicHeaderVertical: CGFloat = 8
        static let topicHeaderMetadata: CGFloat = 12
    }

    // MARK: - Padding

    enum Padding {
        static let topicFilterVertical: CGFloat = 16
        static let topicRowVertical: CGFloat = 8
        static let categoryFilterBottom: CGFloat = 4
        static let categoryBadgeHorizontal: CGFloat = 6
        static let categoryBadgeVertical: CGFloat = 2
        static let postVertical: CGFloat = 18
        static let postHorizontalCompact: CGFloat = 24
        static let postHorizontalRegular: CGFloat = 48
        static let regularWidthBreakpoint: CGFloat = 700

        static func postHorizontal(for width: CGFloat) -> CGFloat {
            width > regularWidthBreakpoint ? postHorizontalRegular : postHorizontalCompact
        }
    }

    // MARK: - Avatars

    enum Avatar {
        static let topicListDisplay: CGFloat = 36
        static let topicListFetch: Int = 80
        static let postDisplay: CGFloat = 36
        static let postFetch: Int = 90
    }

    // MARK: - Category Badge

    enum CategoryBadge {
        static let dotSize: CGFloat = 8
        static let defaultColor = "808080"
        static let backgroundOpacity: Double = 0.1
    }

    // MARK: - Line Limits

    enum LineLimit {
        static let topicTitle = 2
        static let topicExcerpt = 2
        static let topicHeaderTitle = 3
        static let categoryName = 1
    }

    // MARK: - Sidebar

    enum Sidebar {
        static let width: CGFloat = 180
        static let iconSize: CGFloat = 32
        static let discoverButtonSize: CGFloat = 32
        static let iconCornerRadius: CGFloat = 8
        static let iconBorderWidth: CGFloat = 2
        static let iconFallbackOpacity: Double = 0.2
        static let iconSpacing: CGFloat = 4
        static let paddingVertical: CGFloat = 10
        static let paddingHorizontal: CGFloat = 10
        static let iconPadding: CGFloat = 2
    }

    // MARK: - Discover

    enum Discover {
        static let siteIconSize: CGFloat = 44
        static let siteIconCornerRadius: CGFloat = 10
        static let actionIconFont: Font = .title
        static let detailIconSize: CGFloat = 64
        static let detailIconCornerRadius: CGFloat = 14
        static let tagPaddingH: CGFloat = 10
        static let tagPaddingV: CGFloat = 4
    }

    // MARK: - Post Body (Textual/Markdown rendering)

    enum PostBody {
        // Paragraph
        static let paragraphFontScale: CGFloat = isTablet ? 1.0 : 1.2
        static let paragraphLineSpacing: CGFloat = 0.35
        static let paragraphBlockSpacingTop: CGFloat = 0.9

        // Headings
        static let headingFontScales: [CGFloat] = isTablet ? [1.7, 1.4, 1.2, 1.0, 0.95, 0.9] : [2.0, 1.6, 1.4, 1.2, 1.1, 1.0]
        static let headingLineSpacing: CGFloat = 0.15
        static let headingBlockSpacingTop: CGFloat = 1.4
        static let headingBlockSpacingBottom: CGFloat = 0.6

        // Block quote
        static let blockQuoteLineSpacing: CGFloat = 0.3
        static let blockQuotePadding: CGFloat = 0.8
        static let blockQuoteBarWidth: CGFloat = 4
        static let blockQuoteBgOpacity: Double = 0.06
        static let blockQuoteBarOpacity: Double = 0.3
        static let blockQuoteCornerRadius: CGFloat = 4

        // Code block
        static let codeBlockFontScale: CGFloat = 1
        static let codeBlockLineSpacing: CGFloat = 0.5
        static let codeBlockPaddingVertical: CGFloat = 16
        static let codeBlockPaddingHorizontal: CGFloat = 16
        static let codeBlockBgOpacity: Double = 0.06
        static let codeBlockCornerRadius: CGFloat = 6
        static let codeBlockBlockSpacingTop: CGFloat = 0.8

        // Inline code
        static let inlineCodeBgOpacity: Double = 0.12
    }

    // MARK: - Selection

    enum Selection {
        static let highlightOpacity: Double = 0.1
    }

    // MARK: - Panel Shadows

    enum PanelShadow {
        static let width: CGFloat = 12
        static let edgeOpacity: Double = 0.06
        static let midOpacity: Double = 0.02
        static let shadowColor: Color = .black
        static let shadowOpacity: Double = 0.04
        static let shadowRadius: CGFloat = 6
        static let shadowX: CGFloat = 2
    }

    // MARK: - Toolbar

    enum Toolbar {
        static let bottomShadowHeight: CGFloat = PanelShadow.width
        static let bottomShadowOpacity: Double = PanelShadow.shadowOpacity
    }
}
