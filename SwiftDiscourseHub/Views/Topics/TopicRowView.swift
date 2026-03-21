import SwiftUI

struct TopicRowView: View {
    let topic: Topic
    let users: [DiscourseUser]
    let categories: [DiscourseCategory]
    let baseURL: String
    var contentWidth: CGFloat = .infinity

    private var hasUnread: Bool {
        guard let lastRead = topic.lastReadPostNumber, lastRead > 0,
              let highest = topic.highestPostNumber, highest > lastRead else { return false }
        return true
    }

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
            let value = Double(count) / 1000
            return value.formatted(.number.precision(.fractionLength(1))) + "k"
        }
        return "\(count)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.topicRowHorizontal) {
            // Avatar
            if contentWidth >= 250 {
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
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.topicRowVertical) {
                // Title + status icons
                HStack(spacing: 4) {
                    if topic.pinned == true {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if topic.closed == true {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if topic.archived == true {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if topic.visible == false {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(topic.title ?? "Untitled")
                        .font(Theme.Fonts.topicTitle)
                        .lineLimit(Theme.LineLimit.topicTitle)
                    if hasUnread {
                        Circle()
                            .fill(.blue.opacity(0.6))
                            .frame(width: 8, height: 8)
                    }
                }

                // Category + time + reply count
                HStack(spacing: Theme.Spacing.metadataItems) {
                    if let cat = category, let name = cat.name {
                        CategoryBadgeView(name: name, color: cat.color)
                    }
                    if contentWidth >= 250 {
                        RelativeTimeText(dateString: topic.lastPostedAt ?? topic.createdAt, concise: true)
                            .font(Theme.Fonts.metadata)
                    }
                    Spacer()
                    if let replies = formatCount((topic.postsCount ?? 0) - 1) {
                        statLabel(replies, systemImage: "bubble.left")
                            .font(Theme.Fonts.statCount)
                            .foregroundStyle(.secondary)
                    }
                }

                // Excerpt
                if let excerpt = topic.excerpt, !excerpt.isEmpty {
                    Text(excerpt.replacing(/<[^>]+>/, with: ""))
                        .font(Theme.Fonts.topicExcerpt)
                        .foregroundStyle(.secondary)
                        .lineLimit(Theme.LineLimit.topicExcerpt)
                }
            }
        }
        .padding(.vertical, Theme.Padding.topicRowVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func statLabel(_ text: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: systemImage)
                .font(Theme.Fonts.statCount.weight(.regular).leading(.tight))
                .scaleEffect(1.2)
            Text(text)
        }
    }
}
