#if DEBUG
import SwiftUI

// MARK: - PostCell Preview Wrapper (iOS)

#if os(iOS)
import UIKit

/// Wraps a UIKit PostCell for use in SwiftUI previews.
private struct PostCellPreview: UIViewRepresentable {
    let post: Post
    let markdown: String?
    let baseURL: String
    let availableWidth: CGFloat
    var isLiked: Bool = false

    private static let sizeCache = PostCellSizeCache()

    func makeUIView(context: Context) -> PostCell {
        let cell = PostCell(frame: CGRect(x: 0, y: 0, width: availableWidth, height: 200))
        configure(cell)
        return cell
    }

    func updateUIView(_ cell: PostCell, context: Context) {
        configure(cell)
    }

    private func configure(_ cell: PostCell) {
        let pn = post.postNumber ?? 0
        var measured: PostCellSizeCache.MeasuredPost?
        if let md = markdown {
            measured = Self.sizeCache.measure(postNumber: pn, markdown: md, availableWidth: availableWidth)
        }
        cell.configure(post: post, measured: measured, baseURL: baseURL, isLiked: isLiked, availableWidth: availableWidth)
    }

    /// Returns the measured height for sizing the preview frame.
    static func measuredHeight(postNumber: Int, markdown: String?, availableWidth: CGFloat) -> CGFloat {
        guard let md = markdown else { return 200 }
        let measured = sizeCache.measure(postNumber: postNumber, markdown: md, availableWidth: availableWidth)
        return measured.totalHeight
    }
}
#endif

// MARK: - TopicRowView

#Preview("Topic Row") {
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(PreviewData.allTopics) { topic in
                TopicRowView(
                    topic: topic,
                    users: PreviewData.users,
                    categories: PreviewData.categories,
                    baseURL: PreviewData.baseURL
                )
                .padding(.horizontal)
            }
        }
    }
    .frame(width: 400, height: 700)
}

// MARK: - Topic View

#if os(iOS)
#Preview("Topic View") {
    TopicViewPreview()
        .frame(width: 393, height: 900)
}

private struct TopicViewPreview: View {
    @State private var composerText = ""

    private static let previewWidth: CGFloat = 393

    private var posts: [Post] {[
        // #1 — OP with rich markdown (code, lists, blockquote)
        PreviewData.post,
        // #2 — short reply with emojis
        PreviewData.post2,
        // #3 — moderator reply with nested quotes + code
        Post(id: 3, username: "eviltrout", name: "Robin Ward", avatarTemplate: nil,
             createdAt: "2025-12-17T09:15:00.000Z", cooked: nil, postNumber: 3,
             postType: 1, replyCount: 1, readsCount: 60, score: 3.0, yours: false,
             topicId: 1, admin: false, moderator: true, staff: true,
             actionsSummary: [ActionSummary(id: 2, count: 5, acted: false)],
             replyToPostNumber: nil, actionCode: nil),
        // #4 — small action: topic closed
        Post(id: 6, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
             createdAt: "2025-12-17T12:00:00.000Z", cooked: nil, postNumber: 4,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "closed.enabled"),
        // #5 — reply with images
        Post(id: 4, username: "sam", name: "Sam Saffron", avatarTemplate: nil,
             createdAt: "2025-12-18T16:40:00.000Z", cooked: nil, postNumber: 5,
             postType: 1, replyCount: 0, readsCount: 45, score: 2.0, yours: false,
             topicId: 1, admin: false, moderator: false, staff: false,
             actionsSummary: [ActionSummary(id: 2, count: 1, acted: true)],
             replyToPostNumber: 3, actionCode: nil),
        // #6 — markdown table
        Post(id: 14, username: "sam", name: "Sam Saffron", avatarTemplate: nil,
             createdAt: "2025-12-18T17:30:00.000Z", cooked: nil, postNumber: 6,
             postType: 1, replyCount: 1, readsCount: 55, score: 3.5, yours: false,
             topicId: 1, admin: false, moderator: false, staff: false,
             actionsSummary: [ActionSummary(id: 2, count: 4, acted: false)],
             replyToPostNumber: nil, actionCode: nil),
        // #7 — rich links (URLs on own lines)
        Post(id: 15, username: "eviltrout", name: "Robin Ward", avatarTemplate: nil,
             createdAt: "2025-12-19T09:00:00.000Z", cooked: nil, postNumber: 7,
             postType: 1, replyCount: 0, readsCount: 70, score: 4.0, yours: false,
             topicId: 1, admin: false, moderator: true, staff: true,
             actionsSummary: [ActionSummary(id: 2, count: 8, acted: false)],
             replyToPostNumber: nil, actionCode: nil),
        // #8 — whisper (staff-only, with emojis)
        Post(id: 9, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
             createdAt: "2025-12-19T10:00:00.000Z", cooked: nil, postNumber: 8,
             postType: 4, replyCount: 0, readsCount: 5, score: 0.5, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: nil),
        // #9 — small action: tags changed
        Post(id: 10, username: "sam", name: "Sam Saffron", avatarTemplate: nil,
             createdAt: "2025-12-19T11:00:00.000Z", cooked: nil, postNumber: 9,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: false, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "tags_changed"),
        // #10 — emoji-heavy reply
        Post(id: 11, username: "sam", name: "Sam Saffron", avatarTemplate: nil,
             createdAt: "2025-12-19T14:30:00.000Z", cooked: nil, postNumber: 10,
             postType: 1, replyCount: 0, readsCount: 40, score: 2.0, yours: false,
             topicId: 1, admin: false, moderator: false, staff: false,
             actionsSummary: [ActionSummary(id: 2, count: 2, acted: false)],
             replyToPostNumber: 7, actionCode: nil),
        // #11 — quote + images combined
        Post(id: 12, username: "eviltrout", name: "Robin Ward", avatarTemplate: nil,
             createdAt: "2025-12-20T08:00:00.000Z", cooked: nil, postNumber: 11,
             postType: 1, replyCount: 0, readsCount: 35, score: 1.5, yours: false,
             topicId: 1, admin: false, moderator: true, staff: true,
             actionsSummary: [], replyToPostNumber: 5, actionCode: nil),
        // #12 — small action: pinned
        Post(id: 13, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
             createdAt: "2025-12-20T09:00:00.000Z", cooked: nil, postNumber: 12,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "pinned.enabled"),
        // #13 — own final post
        Post(id: 5, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
             createdAt: "2025-12-20T11:00:00.000Z", cooked: nil, postNumber: 13,
             postType: 1, replyCount: 0, readsCount: 30, score: 1.5, yours: true,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: [], replyToPostNumber: nil, actionCode: nil),
    ]}

    private let markdowns: [Int: String] = [
        1: PreviewData.sampleMarkdown,
        2: PreviewData.emojiMarkdown,
        3: PreviewData.quoteMarkdown,
        5: PreviewData.imageMarkdown,
        6: PreviewData.tableMarkdown,
        7: PreviewData.richLinkMarkdown,
        8: PreviewData.whisperMarkdown,
        10: PreviewData.shortMarkdown,
        11: PreviewData.richMarkdown,
        13: """
        Everything looks great! Merging this now. 🎉

        Thanks everyone for the thorough review and feedback. 👏
        """,
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Topic header
            VStack(alignment: .leading, spacing: Theme.Spacing.topicHeaderVertical) {
                Text(PreviewData.topic.title ?? "Untitled")
                    .font(Theme.Fonts.topicHeaderTitle)
                    .lineLimit(Theme.LineLimit.topicHeaderTitle)

                HStack(spacing: Theme.Spacing.topicHeaderMetadata) {
                    CategoryBadgeView(name: "Feature", color: "25AAE2")

                    Label("^[\(12) reply](inflect: true)", systemImage: "bubble.left.and.bubble.right")

                    Spacer()

                    Menu {
                        Button { } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }
                        Button { } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.plain)
                }
                .font(Theme.Fonts.metadata)
                .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)

            Divider()

            // Posts
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(posts) { post in
                        if post.postType == 3 {
                            SmallActionView(post: post)
                                .padding(.horizontal)
                        } else {
                            let pn = post.postNumber ?? 0
                            let md = markdowns[pn]
                            VStack(spacing: 0) {
                                if post.isWhisper {
                                    HStack {
                                        Image(systemName: Theme.Whisper.iconName)
                                            .font(Theme.Whisper.iconFont)
                                            .foregroundStyle(Theme.Whisper.iconColor)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                                PostCellPreview(
                                    post: post,
                                    markdown: md,
                                    baseURL: PreviewData.baseURL,
                                    availableWidth: Self.previewWidth,
                                    isLiked: post.hasLiked
                                )
                                .frame(height: PostCellPreview.measuredHeight(
                                    postNumber: pn,
                                    markdown: md,
                                    availableWidth: Self.previewWidth
                                ))
                            }
                            .opacity(post.isWhisper ? Theme.Whisper.postOpacity : 1.0)
                        }
                    }
                }
            }
            .scrollIndicators(.never)

            // Composer
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 10)

                TextEditor(text: $composerText)
                    .frame(height: 52)
                    .font(.body)
                    .padding(.horizontal, 8)
                    .scrollContentBackground(.hidden)

                HStack {
                    Label("Attach", systemImage: "paperclip")
                        .labelStyle(.iconOnly)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)

                    Spacer()

                    Button {
                    } label: {
                        Label("Reply", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(8)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 12))
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }
}
#else
#Preview("Topic View") {
    MacOSTopicViewPreview()
        .frame(width: 700, height: 900)
}

private struct MacOSTopicViewPreview: View {
    private let postSamples: [(Post, String)] = [
        (PreviewData.post, PreviewData.sampleMarkdown),
        (PreviewData.post2, PreviewData.emojiMarkdown),
        (Post(id: 3, username: "eviltrout", name: "Robin Ward", avatarTemplate: nil,
              createdAt: "2025-12-17T09:15:00.000Z", cooked: nil, postNumber: 3,
              postType: 1, replyCount: 1, readsCount: 60, score: 3.0, yours: false,
              topicId: 1, admin: false, moderator: true, staff: true,
              actionsSummary: [ActionSummary(id: 2, count: 5, acted: false)],
              replyToPostNumber: nil, actionCode: nil),
         PreviewData.tableMarkdown),
        (Post(id: 4, username: "sam", name: "Sam Saffron", avatarTemplate: nil,
              createdAt: "2025-12-18T16:40:00.000Z", cooked: nil, postNumber: 4,
              postType: 1, replyCount: 0, readsCount: 45, score: 2.0, yours: false,
              topicId: 1, admin: false, moderator: false, staff: false,
              actionsSummary: [ActionSummary(id: 2, count: 1, acted: true)],
              replyToPostNumber: 3, actionCode: nil),
         PreviewData.richLinkMarkdown),
        (Post(id: 9, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
              createdAt: "2025-12-19T10:00:00.000Z", cooked: nil, postNumber: 5,
              postType: 4, replyCount: 0, readsCount: 5, score: 0.5, yours: false,
              topicId: 1, admin: true, moderator: false, staff: true,
              actionsSummary: nil, replyToPostNumber: nil, actionCode: nil),
         PreviewData.whisperMarkdown),
        (Post(id: 8, username: "eviltrout", name: "Robin Ward", avatarTemplate: nil,
              createdAt: "2025-12-19T09:00:00.000Z", cooked: nil, postNumber: 6,
              postType: 1, replyCount: 2, readsCount: 70, score: 4.0, yours: false,
              topicId: 1, admin: false, moderator: true, staff: true,
              actionsSummary: [ActionSummary(id: 2, count: 8, acted: false)],
              replyToPostNumber: nil, actionCode: nil),
         PreviewData.richMarkdown),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(postSamples, id: \.0.id) { post, markdown in
                    PostView(
                        post: post,
                        baseURL: PreviewData.baseURL,
                        markdown: markdown,
                        contentWidth: 700,
                        isWhisper: post.isWhisper
                    )
                    Divider()
                }
            }
        }
    }
}
#endif

#endif
