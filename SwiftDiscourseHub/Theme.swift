import SwiftUI

enum Theme {

    // MARK: - Fonts

    enum Fonts {
        static let topicTitle: Font = .headline
        static let topicExcerpt: Font = .subheadline
        static let postAuthorName: Font = .subheadline.bold()
        static let postBody: Font = .body
        static let metadata: Font = .caption
        static let metadataSmall: Font = .caption2
        static let topicHeaderTitle: Font = .title2.bold()
        static let sidebarIcon: Font = .title3
        static let siteIconFallback: Font = .title2.bold()
        static let discoverSiteTitle: Font = .headline
        static let discoverSiteDescription: Font = .subheadline
        static let discoverSiteStats: Font = .caption
        static let discoverCategory: Font = .subheadline
        static let categoryListTitle: Font = .headline
        static let categoryListDescription: Font = .subheadline
        static let categoryListStats: Font = .caption
    }

    // MARK: - Spacing (HStack / VStack gaps)

    enum Spacing {
        static let topicRowHorizontal: CGFloat = 10
        static let topicRowVertical: CGFloat = 6
        static let topicRowStats: CGFloat = 12
        static let metadataItems: CGFloat = 6
        static let postContentVertical: CGFloat = 8
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
        static let postVertical: CGFloat = 16
        static let postHorizontalCompact: CGFloat = 16
        static let postHorizontalRegular: CGFloat = 32
        static let regularWidthBreakpoint: CGFloat = 600

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
        static let width: CGFloat = 80
        static let iconSize: CGFloat = 42
        static let discoverButtonSize: CGFloat = 42
        static let iconCornerRadius: CGFloat = 12
        static let iconBorderWidth: CGFloat = 2
        static let iconFallbackOpacity: Double = 0.2
        static let iconSpacing: CGFloat = 16
        static let paddingVertical: CGFloat = 10
        static let paddingHorizontal: CGFloat = 10
        static let iconPadding: CGFloat = 4
    }

    // MARK: - Discover

    enum Discover {
        static let siteIconSize: CGFloat = 44
        static let siteIconCornerRadius: CGFloat = 10
        static let actionIconFont: Font = .title2
        static let detailIconSize: CGFloat = 64
        static let detailIconCornerRadius: CGFloat = 14
        static let tagPaddingH: CGFloat = 10
        static let tagPaddingV: CGFloat = 4
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
