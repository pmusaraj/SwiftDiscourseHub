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
    }

    // MARK: - Spacing (HStack / VStack gaps)

    enum Spacing {
        static let topicRowHorizontal: CGFloat = 10
        static let topicRowVertical: CGFloat = 4
        static let topicRowStats: CGFloat = 12
        static let metadataItems: CGFloat = 6
        static let postContentVertical: CGFloat = 8
        static let postHeaderHorizontal: CGFloat = 8
        static let postAuthorVertical: CGFloat = 1
        static let postNameItems: CGFloat = 4
        static let postFooterHorizontal: CGFloat = 16
        static let categoryBadgeHorizontal: CGFloat = 4
    }

    // MARK: - Padding

    enum Padding {
        static let topicFilterVertical: CGFloat = 8
        static let topicRowVertical: CGFloat = 4
        static let categoryFilterBottom: CGFloat = 4
        static let categoryBadgeHorizontal: CGFloat = 6
        static let categoryBadgeVertical: CGFloat = 2
    }

    // MARK: - Avatars

    enum Avatar {
        static let topicListDisplay: CGFloat = 40
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
        static let categoryName = 1
    }
}
