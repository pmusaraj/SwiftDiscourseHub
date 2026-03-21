import SwiftUI

struct PostView: View {
    let post: Post
    let baseURL: String
    let markdown: String?
    var contentWidth: CGFloat = 0
    var isLiked: Bool = false
    var isWhisper: Bool = false
    var currentTopicId: Int = 0
    var avatarLookup: [String: String] = [:]
    var onLike: (() async -> Void)?
    var onQuote: ((String) -> Void)?
    var onScrollToPost: ((Int) -> Void)?

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
                    if let username = post.username {
                        Text("@\(username)")
                            .font(Theme.Fonts.metadata)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if isWhisper {
                    Label("Whisper", systemImage: "eye.slash.fill")
                        .font(Theme.Fonts.metadataSmall)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 4) {
                    RelativeTimeText(dateString: post.createdAt)
                    if let pn = post.postNumber {
                        Text("·")
                        Text("#\(pn)")
                    }
                }
                .font(Theme.Fonts.metadata)
                .foregroundStyle(.secondary)
            }

            Spacer().frame(height: Theme.Spacing.postHeaderToBody)

            // Content
            if let md = markdown {
                Text(md)
                    .font(Theme.Fonts.postBody)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
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
            .font(Theme.Fonts.statCount)
            .imageScale(.large)
        }
        .padding(.vertical, Theme.Padding.postVertical)
        .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
        .background(isWhisper ? Color.orange.opacity(0.04) : Color.clear)
    }

    private var likeCountDisplay: String {
        var count = post.likeCount
        if isLiked && !post.hasLiked { count += 1 }
        if !isLiked && post.hasLiked { count -= 1 }
        return count > 0 ? "\(count)" : ""
    }
}
