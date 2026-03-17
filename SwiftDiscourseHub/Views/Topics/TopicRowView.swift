import SwiftUI

struct TopicRowView: View {
    let topic: Topic
    let users: [DiscourseUser]
    let categories: [DiscourseCategory]
    let baseURL: String

    private var originalPoster: DiscourseUser? {
        guard let poster = topic.posters?.first(where: { $0.extras?.contains("Original") == true }) ?? topic.posters?.first,
              let userId = poster.userId else { return nil }
        return users.first { $0.id == userId }
    }

    private var category: DiscourseCategory? {
        guard let catId = topic.categoryId else { return nil }
        return categories.first { $0.id == catId }
    }

    private func formatCount(_ count: Int?) -> String? {
        guard let count, count > 0 else { return nil }
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.topicRowHorizontal) {
            // Avatar
            CachedAsyncImage(
                url: URLHelpers.avatarURL(template: originalPoster?.avatarTemplate, size: Theme.Avatar.topicListFetch, baseURL: baseURL)
            ) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: Theme.Avatar.topicListDisplay, height: Theme.Avatar.topicListDisplay)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: Theme.Spacing.topicRowVertical) {
                // Title
                Text(topic.title ?? "Untitled")
                    .font(Theme.Fonts.topicTitle)
                    .lineLimit(Theme.LineLimit.topicTitle)

                // Category + time
                HStack(spacing: Theme.Spacing.metadataItems) {
                    if let cat = category, let name = cat.name {
                        CategoryBadgeView(name: name, color: cat.color)
                    }
                    RelativeTimeText(dateString: topic.lastPostedAt ?? topic.createdAt)
                        .font(Theme.Fonts.metadata)
                }

                // Excerpt
                if let excerpt = topic.excerpt, !excerpt.isEmpty {
                    Text(excerpt.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                        .font(Theme.Fonts.topicExcerpt)
                        .foregroundStyle(.secondary)
                        .lineLimit(Theme.LineLimit.topicExcerpt)
                }

                // Stats
                HStack(spacing: Theme.Spacing.topicRowStats) {
                    if let posts = formatCount(topic.postsCount) {
                        Label(posts, systemImage: "bubble.left")
                    }
                    if let views = formatCount(topic.views) {
                        Label(views, systemImage: "eye")
                    }
                    if let likes = formatCount(topic.likeCount) {
                        Label(likes, systemImage: "heart")
                    }
                }
                .font(Theme.Fonts.metadata)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Padding.topicRowVertical)
    }
}
