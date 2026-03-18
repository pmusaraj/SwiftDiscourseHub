import SwiftUI

struct PostView: View {
    let post: Post
    let baseURL: String
    let markdown: String?
    var contentWidth: CGFloat = 0
    var isLiked: Bool = false
    var onLike: (() async -> Void)?
    var onQuote: ((String) -> Void)?

    @State private var isLiking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + username + date
            HStack(spacing: Theme.Spacing.postHeaderHorizontal) {
                CachedAsyncImage(
                    url: URLHelpers.avatarURL(template: post.avatarTemplate, size: Theme.Avatar.postFetch, baseURL: baseURL)
                ) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: Theme.Avatar.postDisplay, height: Theme.Avatar.postDisplay)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.postAuthorVertical) {
                    HStack(spacing: Theme.Spacing.postNameItems) {
                        Text(post.name ?? post.username ?? "Unknown")
                            .font(Theme.Fonts.postAuthorName)
                        if post.staff == true {
                            Image(systemName: "shield.fill")
                                .font(Theme.Fonts.metadataSmall)
                                .foregroundStyle(.blue)
                        }
                    }
                    HStack(spacing: Theme.Spacing.postNameItems) {
                        if let username = post.username {
                            Text("@\(username)")
                                .font(Theme.Fonts.metadata)
                                .foregroundStyle(.secondary)
                        }
                        Text("·")
                            .foregroundStyle(.secondary)
                        RelativeTimeText(dateString: post.createdAt)
                            .font(Theme.Fonts.metadata)
                    }
                }
                Spacer()

                if let postNumber = post.postNumber {
                    Text("#\(postNumber)")
                        .font(Theme.Fonts.metadata)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer().frame(height: Theme.Spacing.postHeaderToBody)

            // Content
            if let md = markdown {
                PostContentView(markdown: md, baseURL: baseURL)
                    .contextMenu {
                        if let onQuote {
                            Button {
                                let plainText = md
                                    .replacing(/!\[.*?\]\(.*?\)/, with: "[image]")
                                onQuote(plainText)
                            } label: {
                                Label("Quote in Reply", systemImage: "text.quote")
                            }
                        }
                    }
            } else if let cooked = post.cooked, !cooked.isEmpty {
                Text(cooked)
                    .font(Theme.Fonts.postBody)
            }

            Spacer().frame(height: Theme.Spacing.postBodyToFooter)

            // Footer: likes + replies
            HStack(spacing: Theme.Spacing.postFooterHorizontal) {
                if let onLike {
                    Button {
                        guard !isLiking else { return }
                        isLiking = true
                        Task {
                            await onLike()
                            isLiking = false
                        }
                    } label: {
                        Label(
                            "\(likeCountDisplay)",
                            systemImage: isLiked ? "heart.fill" : "heart"
                        )
                        .foregroundStyle(isLiked ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLiking)
                    #if os(macOS)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    #endif
                } else if post.likeCount > 0 {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .foregroundStyle(.secondary)
                }

                if let replies = post.replyCount, replies > 0 {
                    Label("\(replies)", systemImage: "arrowshape.turn.up.left")
                        .foregroundStyle(.secondary)
                }
            }
            .font(Theme.Fonts.metadata)
        }
        .padding(.vertical, Theme.Padding.postVertical)
        .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
    }

    private var likeCountDisplay: String {
        var count = post.likeCount
        if isLiked && !post.hasLiked { count += 1 }
        if !isLiked && post.hasLiked { count -= 1 }
        return count > 0 ? "\(count)" : ""
    }
}
