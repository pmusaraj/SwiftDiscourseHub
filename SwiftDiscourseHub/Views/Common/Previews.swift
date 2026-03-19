#if DEBUG
import SwiftUI
import Textual

// MARK: - Sample Data

enum PreviewData {
    static let baseURL = "https://meta.discourse.org"

    static let sampleMarkdown = """
    This is a paragraph with **bold text**, *italic text*, and `inline code`. \
    Here's a [link to Discourse](https://discourse.org).

    ## Features

    Discourse has many great features:

    - Real-time updates
    - Rich **Markdown** support
    - Categories and tags
      - Nested list items work too

    ### Code Example

    ```ruby
    class TopicCreator
      def initialize(user, opts = {})
        @user = user
        @opts = opts
      end

      def create
        Topic.new(@opts)
      end
    end
    ```

    > This is a block quote. It can contain **formatted text** and even
    > multiple lines of content.

    Here's a numbered list:

    1. First item
    2. Second item
    3. Third item

    ---

    | Column A | Column B | Column C |
    |----------|----------|----------|
    | Cell 1   | Cell 2   | Cell 3   |
    | Cell 4   | Cell 5   | Cell 6   |

    And a final paragraph with some more text to show line spacing.
    """

    static let shortMarkdown = """
    I think this is a great idea! We should definitely consider adding \
    support for **dark mode** in the next release.

    Here's what I'd suggest:

    1. Start with the color palette
    2. Update the CSS variables
    3. Test across browsers
    """

    static let topic = Topic(
        id: 1,
        title: "How to customize the look and feel of your Discourse forum",
        fancyTitle: nil,
        slug: "how-to-customize",
        postsCount: 42,
        replyCount: 41,
        highestPostNumber: 45,
        createdAt: "2025-12-15T10:30:00.000Z",
        lastPostedAt: "2026-03-14T08:15:00.000Z",
        bumped: true,
        bumpedAt: nil,
        archetype: "regular",
        unseen: false,
        pinned: false,
        excerpt: "A comprehensive guide to theming your Discourse instance with custom colors, fonts, and layouts.",
        visible: true,
        closed: false,
        archived: false,
        views: 1234,
        likeCount: 56,
        categoryId: 1,
        posters: [Poster(extras: "Original Poster", description: "Original Poster", userId: 1)],
        imageUrl: nil
    )

    static let topic2 = Topic(
        id: 2,
        title: "Welcome to our community!",
        fancyTitle: nil,
        slug: "welcome",
        postsCount: 5,
        replyCount: 4,
        highestPostNumber: 5,
        createdAt: "2026-01-10T14:00:00.000Z",
        lastPostedAt: "2026-03-10T09:00:00.000Z",
        bumped: nil,
        bumpedAt: nil,
        archetype: "regular",
        unseen: true,
        pinned: true,
        excerpt: nil,
        visible: true,
        closed: false,
        archived: false,
        views: 89,
        likeCount: 12,
        categoryId: 2,
        posters: [Poster(extras: "Original Poster", description: nil, userId: 2)],
        imageUrl: nil
    )

    static let topic3 = Topic(
        id: 3,
        title: "Performance improvements in Ember.js rendering pipeline",
        fancyTitle: nil,
        slug: "performance-improvements",
        postsCount: 18,
        replyCount: 17,
        highestPostNumber: 20,
        createdAt: "2026-02-20T09:00:00.000Z",
        lastPostedAt: "2026-03-12T16:45:00.000Z",
        bumped: true,
        bumpedAt: nil,
        archetype: "regular",
        unseen: false,
        pinned: false,
        excerpt: "We've been working on reducing initial render time by 40% through lazy component hydration.",
        visible: true,
        closed: false,
        archived: false,
        views: 567,
        likeCount: 34,
        categoryId: 1,
        posters: [Poster(extras: "Original Poster", description: nil, userId: 1)],
        imageUrl: nil
    )

    static let topic4 = Topic(
        id: 4,
        title: "CSS not loading after upgrade to latest stable",
        fancyTitle: nil,
        slug: "css-not-loading",
        postsCount: 7,
        replyCount: 6,
        highestPostNumber: 7,
        createdAt: "2026-03-13T11:20:00.000Z",
        lastPostedAt: "2026-03-16T22:00:00.000Z",
        bumped: true,
        bumpedAt: nil,
        archetype: "regular",
        unseen: true,
        pinned: false,
        excerpt: nil,
        visible: true,
        closed: false,
        archived: false,
        views: 42,
        likeCount: 2,
        categoryId: 3,
        posters: [Poster(extras: "Original Poster", description: nil, userId: 3)],
        imageUrl: nil
    )

    static let topic5 = Topic(
        id: 5,
        title: "What's everyone working on this week?",
        fancyTitle: nil,
        slug: "whats-everyone-working-on",
        postsCount: 31,
        replyCount: 30,
        highestPostNumber: 35,
        createdAt: "2026-03-10T08:00:00.000Z",
        lastPostedAt: "2026-03-17T06:30:00.000Z",
        bumped: true,
        bumpedAt: nil,
        archetype: "regular",
        unseen: false,
        pinned: false,
        excerpt: "Weekly thread for sharing what you're building, learning, or experimenting with.",
        visible: true,
        closed: false,
        archived: false,
        views: 890,
        likeCount: 45,
        categoryId: 2,
        posters: [Poster(extras: "Original Poster", description: nil, userId: 2)],
        imageUrl: nil
    )

    static let topic6 = Topic(
        id: 6,
        title: "Proposal: Native mobile push notifications via Firebase",
        fancyTitle: nil,
        slug: "proposal-native-push",
        postsCount: 12,
        replyCount: 11,
        highestPostNumber: 12,
        createdAt: "2026-03-05T15:00:00.000Z",
        lastPostedAt: "2026-03-15T10:00:00.000Z",
        bumped: true,
        bumpedAt: nil,
        archetype: "regular",
        unseen: false,
        pinned: false,
        excerpt: nil,
        visible: true,
        closed: false,
        archived: false,
        views: 312,
        likeCount: 28,
        categoryId: 1,
        posters: [Poster(extras: "Original Poster", description: nil, userId: 3)],
        imageUrl: nil
    )

    static let allTopics = [topic, topic2, topic3, topic4, topic5, topic6]

    // MARK: - Discover Sites

    static let discoverSites: [DiscoverSite] = [
        DiscoverSite(id: 1, title: "Meta Discourse", featuredLink: "https://meta.discourse.org",
                     excerpt: "<p>The official community for Discourse, the open-source discussion platform. Get help, share feedback, and discuss features.</p>",
                     logoUrl: nil, activeUsers30Days: 2450, topics30Days: 580, tags: ["open-source", "support"]),
        DiscoverSite(id: 2, title: "Swift Forums", featuredLink: "https://forums.swift.org",
                     excerpt: "<p>The Swift programming language community. Discuss proposals, share code, and collaborate on the future of Swift.</p>",
                     logoUrl: nil, activeUsers30Days: 1800, topics30Days: 320, tags: ["technology", "open-source"]),
        DiscoverSite(id: 3, title: "Rust Users", featuredLink: "https://users.rust-lang.org",
                     excerpt: nil,
                     logoUrl: nil, activeUsers30Days: 950, topics30Days: 210, tags: ["technology"]),
        DiscoverSite(id: 4, title: "Elixir Forum", featuredLink: "https://elixirforum.com",
                     excerpt: "<p>Pair programming with the Elixir community. Ask questions, share projects, and learn about Phoenix, LiveView, and more.</p>",
                     logoUrl: nil, activeUsers30Days: 720, topics30Days: 150, tags: ["technology"]),
        DiscoverSite(id: 5, title: "NixOS Discourse", featuredLink: "https://discourse.nixos.org",
                     excerpt: nil,
                     logoUrl: nil, activeUsers30Days: nil, topics30Days: nil, tags: ["open-source"]),
        DiscoverSite(id: 6, title: "Keyboard Maestro", featuredLink: "https://forum.keyboardmaestro.com",
                     excerpt: "<p>Community forum for Keyboard Maestro, the powerful macOS automation tool. Share macros and get help with workflows.</p>",
                     logoUrl: nil, activeUsers30Days: 310, topics30Days: 45, tags: ["interests"]),
    ]

    static let smallActionPosts: [Post] = [
        Post(id: 101, username: "codinghorror", name: nil, avatarTemplate: nil,
             createdAt: "2026-03-15T10:00:00.000Z", cooked: nil, postNumber: nil,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "closed.enabled"),
        Post(id: 102, username: "sam", name: nil, avatarTemplate: nil,
             createdAt: "2026-03-15T11:00:00.000Z", cooked: nil, postNumber: nil,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: false, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "closed.disabled"),
        Post(id: 103, username: "eviltrout", name: nil, avatarTemplate: nil,
             createdAt: "2026-03-15T12:00:00.000Z", cooked: nil, postNumber: nil,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: false, moderator: true, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "archived.enabled"),
        Post(id: 104, username: "codinghorror", name: nil, avatarTemplate: nil,
             createdAt: "2026-03-15T13:00:00.000Z", cooked: nil, postNumber: nil,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "pinned.enabled"),
        Post(id: 105, username: "sam", name: nil, avatarTemplate: nil,
             createdAt: "2026-03-15T14:00:00.000Z", cooked: nil, postNumber: nil,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: false, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "visible.disabled"),
        Post(id: 106, username: "eviltrout", name: nil, avatarTemplate: nil,
             createdAt: "2026-03-15T15:00:00.000Z", cooked: nil, postNumber: nil,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: false, moderator: true, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "tags_changed"),
        Post(id: 107, username: "codinghorror", name: nil, avatarTemplate: nil,
             createdAt: "2026-03-15T16:00:00.000Z", cooked: nil, postNumber: nil,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "split_topic"),
    ]

    static let users = [
        DiscourseUser(id: 1, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil),
        DiscourseUser(id: 2, username: "sam", name: "Sam Saffron", avatarTemplate: nil),
        DiscourseUser(id: 3, username: "eviltrout", name: "Robin Ward", avatarTemplate: nil),
    ]

    static let categories = [
        DiscourseCategory(id: 1, name: "Feature", slug: "feature", color: "25AAE2", textColor: "FFFFFF", topicCount: 100, postCount: 500, description: nil, descriptionText: nil, topicUrl: nil, subcategoryIds: nil, uploadedLogo: nil, parentCategoryId: nil, position: 0, subcategoryList: nil),
        DiscourseCategory(id: 2, name: "General", slug: "general", color: "0088CC", textColor: "FFFFFF", topicCount: 200, postCount: 1000, description: nil, descriptionText: nil, topicUrl: nil, subcategoryIds: nil, uploadedLogo: nil, parentCategoryId: nil, position: 1, subcategoryList: nil),
        DiscourseCategory(id: 3, name: "Bug", slug: "bug", color: "E45735", textColor: "FFFFFF", topicCount: 50, postCount: 300, description: nil, descriptionText: nil, topicUrl: nil, subcategoryIds: nil, uploadedLogo: nil, parentCategoryId: nil, position: 2, subcategoryList: nil),
    ]

    static let post = Post(
        id: 1,
        username: "codinghorror",
        name: "Jeff Atwood",
        avatarTemplate: nil,
        createdAt: "2025-12-15T10:30:00.000Z",
        cooked: nil,
        postNumber: 1,
        postType: 1,
        replyCount: 5,
        readsCount: 100,
        score: 10.5,
        yours: false,
        topicId: 1,
        admin: true,
        moderator: false,
        staff: true,
        actionsSummary: [ActionSummary(id: 2, count: 12, acted: false)],
        replyToPostNumber: nil,
        actionCode: nil
    )

    static let post2 = Post(
        id: 2,
        username: "sam",
        name: "Sam Saffron",
        avatarTemplate: nil,
        createdAt: "2025-12-16T14:20:00.000Z",
        cooked: nil,
        postNumber: 2,
        postType: 1,
        replyCount: 2,
        readsCount: 80,
        score: 5.0,
        yours: false,
        topicId: 1,
        admin: false,
        moderator: false,
        staff: false,
        actionsSummary: [ActionSummary(id: 2, count: 3, acted: false)],
        replyToPostNumber: 1,
        actionCode: nil
    )
}

// MARK: - PostContentView

#Preview("Post Content — Full") {
    ScrollView {
        PostContentView(markdown: PreviewData.sampleMarkdown, baseURL: PreviewData.baseURL)
            .padding()
    }
    .frame(width: 600, height: 700)
}

#Preview("Post Content — Short") {
    PostContentView(markdown: PreviewData.shortMarkdown, baseURL: PreviewData.baseURL)
        .padding()
        .frame(width: 500)
}

// MARK: - PostView

#Preview("Post View — Staff") {
    ScrollView {
        PostView(post: PreviewData.post, baseURL: PreviewData.baseURL, markdown: PreviewData.sampleMarkdown, contentWidth: 600)
        Divider()
        PostView(post: PreviewData.post2, baseURL: PreviewData.baseURL, markdown: PreviewData.shortMarkdown, contentWidth: 600)
    }
    .frame(width: 600, height: 800)
}

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

// MARK: - CategoryBadgeView

#Preview("Category Badges") {
    HStack(spacing: 12) {
        CategoryBadgeView(name: "Feature", color: "25AAE2")
        CategoryBadgeView(name: "Bug", color: "E45735")
        CategoryBadgeView(name: "General", color: "0088CC")
        CategoryBadgeView(name: "Support", color: "808080")
    }
    .padding()
}

// MARK: - Topic Header (standalone)

#Preview("Topic Header") {
    VStack(spacing: 0) {
        TopicHeaderPreview()
        Divider()
        Spacer()
    }
    .frame(width: 600, height: 200)
}

private struct TopicHeaderPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PreviewData.topic.title ?? "Untitled")
                .font(Theme.Fonts.topicHeaderTitle)
                .lineLimit(Theme.LineLimit.topicHeaderTitle)

            HStack(spacing: Theme.Spacing.topicHeaderMetadata) {
                CategoryBadgeView(name: "Feature", color: "25AAE2")

                Label {
                    RelativeTimeText(dateString: PreviewData.topic.createdAt)
                } icon: {
                    Image(systemName: "calendar")
                }

                Spacer()

                Label("41 replies", systemImage: "bubble.left.and.bubble.right")
            }
            .font(Theme.Fonts.metadata)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

// MARK: - Topic View

#Preview("Topic View") {
    TopicViewPreview()
        .frame(width: 700, height: 900)
}

private struct TopicViewPreview: View {
    @State private var composerText = ""

    private var posts: [Post] {[
        PreviewData.post,
        PreviewData.post2,
        Post(id: 3, username: "eviltrout", name: "Robin Ward", avatarTemplate: nil,
             createdAt: "2025-12-17T09:15:00.000Z", cooked: nil, postNumber: 3,
             postType: 1, replyCount: 1, readsCount: 60, score: 3.0, yours: false,
             topicId: 1, admin: false, moderator: true, staff: true,
             actionsSummary: [ActionSummary(id: 2, count: 5, acted: false)], replyToPostNumber: nil, actionCode: nil),
        // Small action: topic closed
        Post(id: 6, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
             createdAt: "2025-12-17T12:00:00.000Z", cooked: nil, postNumber: 4,
             postType: 3, replyCount: nil, readsCount: nil, score: nil, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: "closed.enabled"),
        Post(id: 4, username: "sam", name: "Sam Saffron", avatarTemplate: nil,
             createdAt: "2025-12-18T16:40:00.000Z", cooked: nil, postNumber: 5,
             postType: 1, replyCount: 0, readsCount: 45, score: 2.0, yours: false,
             topicId: 1, admin: false, moderator: false, staff: false,
             actionsSummary: [ActionSummary(id: 2, count: 1, acted: true)], replyToPostNumber: 3, actionCode: nil),
        // Whisper post
        Post(id: 7, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
             createdAt: "2025-12-18T17:00:00.000Z", cooked: nil, postNumber: 6,
             postType: 4, replyCount: 0, readsCount: 5, score: 0.5, yours: false,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: nil, replyToPostNumber: nil, actionCode: nil),
        Post(id: 5, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
             createdAt: "2025-12-19T11:00:00.000Z", cooked: nil, postNumber: 7,
             postType: 1, replyCount: 0, readsCount: 30, score: 1.5, yours: true,
             topicId: 1, admin: true, moderator: false, staff: true,
             actionsSummary: [], replyToPostNumber: nil, actionCode: nil),
    ]}

    private let markdowns: [Int: String] = [
        1: PreviewData.sampleMarkdown,
        2: PreviewData.shortMarkdown,
        3: """
        Great points @sam! I'd also recommend looking into the `ThemeModifier` API \
        which gives you fine-grained control over individual components.

        ```javascript
        api.modifyClass("component:topic-list-item", {
          pluginId: "my-theme",
          didInsertElement() {
            this.element.style.borderLeft = "3px solid var(--tertiary)";
          }
        });
        ```
        """,
        // 4 is a small action — no markdown
        5: """
        > Great points @sam!

        Thanks @eviltrout! That's exactly what I was looking for. \
        The `ThemeModifier` approach is much cleaner than what I had before.

        One follow-up question: does this work with **child themes** as well?
        """,
        6: """
        *This is a staff-only note: the user's account was flagged for review \
        but it looks like a false positive. Clearing the flag now.*
        """,
        7: """
        Yes, child themes inherit all modifiers from the parent. You can also \
        override specific modifiers in the child theme if needed.

        See the [theme documentation](https://meta.discourse.org/t/themes) for more details.
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

                    Label {
                        RelativeTimeText(dateString: PreviewData.topic.createdAt)
                    } icon: {
                        Image(systemName: "calendar")
                    }

                    Spacer()

                    Label("^[\(41) reply](inflect: true)", systemImage: "bubble.left.and.bubble.right")
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
                        PostView(
                            post: post,
                            baseURL: PreviewData.baseURL,
                            markdown: markdowns[post.postNumber ?? 0],
                            contentWidth: 700,
                            isLiked: post.hasLiked
                        )
                        .id(post.id)
                        if post.id != posts.last?.id {
                            Divider()
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

// MARK: - Small Actions

#Preview("Small Actions") {
    VStack(spacing: 0) {
        ForEach(PreviewData.smallActionPosts) { post in
            SmallActionView(post: post)
            Divider()
        }
    }
    .padding(.horizontal)
    .frame(width: 500)
}

// MARK: - Whisper Post

#Preview("Whisper Post") {
    PostView(
        post: Post(
            id: 200, username: "codinghorror", name: "Jeff Atwood", avatarTemplate: nil,
            createdAt: "2026-03-15T10:00:00.000Z", cooked: nil, postNumber: 3,
            postType: 4, replyCount: 0, readsCount: 5, score: 0.5, yours: false,
            topicId: 1, admin: true, moderator: false, staff: true,
            actionsSummary: nil, replyToPostNumber: nil, actionCode: nil
        ),
        baseURL: PreviewData.baseURL,
        markdown: "*Staff note: this user's account was reviewed and cleared.*",
        contentWidth: 500,
        isWhisper: true
    )
    .frame(width: 500)
}

// MARK: - Rich Links

#Preview("Rich Links") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHub Repo").font(.caption).foregroundStyle(.secondary)
            RichLinkView(info: OneboxInfo(
                url: "https://github.com/discourse/discourse",
                title: "GitHub - discourse/discourse: A platform for community discussion",
                description: "A platform for community discussion. Free, open, simple.",
                imageURL: "https://opengraph.githubassets.com/1/discourse/discourse",
                faviconURL: "https://github.githubassets.com/favicons/favicon.svg",
                siteName: "GitHub"
            ))

            Text("Generic Website").font(.caption).foregroundStyle(.secondary)
            RichLinkView(info: OneboxInfo(
                url: "https://discourse.org/",
                title: "Discourse is the place to build civilized communities",
                description: "Discourse is modern forum software for meaningful discussions, support, and teamwork that gives your online community everything it needs in one place.",
                imageURL: nil,
                faviconURL: nil,
                siteName: "Discourse - Civilized Discussion"
            ))

            Text("Minimal (title only)").font(.caption).foregroundStyle(.secondary)
            RichLinkView(info: OneboxInfo(
                url: "https://www.google.com/",
                title: "Google",
                description: nil,
                imageURL: nil,
                faviconURL: nil,
                siteName: nil
            ))
        }
        .padding()
    }
    .frame(width: 500, height: 700)
}

#Preview("Post with Rich Link") {
    ScrollView {
        PostView(
            post: Post(
                id: 300, username: "sam", name: "Sam Saffron", avatarTemplate: nil,
                createdAt: "2026-03-16T09:00:00.000Z",
                cooked: """
                <p>Check out the source code:</p>
                <aside class="onebox githubrepo" data-onebox-src="https://github.com/discourse/discourse">
                  <header class="source">
                      <a href="https://github.com/discourse/discourse" target="_blank">github.com</a>
                  </header>
                  <article class="onebox-body">
                    <img src="https://opengraph.githubassets.com/1/discourse/discourse" class="thumbnail" width="690" height="344">
                    <h3><a href="https://github.com/discourse/discourse" target="_blank">GitHub - discourse/discourse: A platform for community discussion</a></h3>
                    <p>A platform for community discussion. Free, open, simple.</p>
                  </article>
                </aside>
                <p>It's fully open source!</p>
                """,
                postNumber: 1,
                postType: 1, replyCount: 3, readsCount: 50, score: 8.0, yours: false,
                topicId: 1, admin: false, moderator: false, staff: true,
                actionsSummary: [ActionSummary(id: 2, count: 7, acted: false)],
                replyToPostNumber: nil, actionCode: nil
            ),
            baseURL: PreviewData.baseURL,
            markdown: """
            Check out the source code:

            https://github.com/discourse/discourse

            It's fully open source!
            """,
            contentWidth: 500
        )
    }
    .frame(width: 500, height: 500)
}

// MARK: - Discover Site Card

#Preview("Discover Site Card") {
    HStack(spacing: 16) {
        DiscoverSiteCard(
            site: PreviewData.discoverSites[0],
            isAdded: false,
            strippedExcerpt: "The official community for Discourse, the open-source discussion platform.",
            onAdd: {}
        )
        DiscoverSiteCard(
            site: PreviewData.discoverSites[2],
            isAdded: true,
            strippedExcerpt: "",
            onAdd: {}
        )
    }
    .padding()
    .frame(width: 600)
}

// MARK: - Discover Grid

#Preview("Discover Grid") {
    DiscoverGridPreview()
        .frame(width: 700, height: 600)
}

private struct DiscoverGridPreview: View {
    private func stripHTML(_ html: String?) -> String {
        guard let html else { return "" }
        return html.replacing(/<[^>]+>/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                ForEach(PreviewData.discoverSites) { site in
                    DiscoverSiteCard(
                        site: site,
                        isAdded: site.id == 3,
                        strippedExcerpt: stripHTML(site.excerpt),
                        onAdd: {}
                    )
                }
            }
            .padding(16)
        }
        .scrollIndicators(.never)
    }
}

// MARK: - Topic Filter Bar

#Preview("Topic Filter Bar") {
    TopicFilterBarPreview()
        .padding()
}

private struct TopicFilterBarPreview: View {
    @State private var filter: TopicFilter = .latest

    var body: some View {
        HStack(spacing: 6) {
            Picker("", selection: $filter) {
                ForEach(TopicFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: Theme.Sidebar.iconCornerRadius)
                    .fill(Color(hex: "25AAE2").opacity(0.2))
                Text("M")
                    .font(Theme.Fonts.siteIconFallback)
                    .foregroundStyle(Color(hex: "25AAE2"))
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Sidebar.iconCornerRadius))
        }
    }
}

// MARK: - Sidebar

#Preview("Sidebar") {
    SidebarPreview()
        .frame(height: 500)
}

private struct SidebarPreview: View {
    @State private var selectedIndex = 0

    private let sites = [
        ("Meta", "M", "25AAE2", "pmusaraj"),
        ("Swift Forums", "S", "F05138", nil as String?),
        ("Rust Users", "R", "DEA584", nil as String?),
        ("Hacker News", "H", "FF6600", "hn_user"),
    ]

    var body: some View {
        VStack(spacing: Theme.Sidebar.iconSpacing) {
            ForEach(Array(sites.enumerated()), id: \.offset) { index, site in
                let isSelected = index == selectedIndex
                Button {
                    selectedIndex = index
                } label: {
                    HStack(spacing: 8) {
                        siteIcon(letter: site.1, color: site.2, isSelected: isSelected)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(site.0)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .lineLimit(1)

                            if let username = site.3 {
                                Text("@\(username)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(isSelected ? Color.accentColor.opacity(0.12) : .clear)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .frame(width: Theme.Sidebar.discoverButtonSize, height: Theme.Sidebar.discoverButtonSize)

                Text("Discover")
                    .font(.subheadline)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Sidebar.paddingVertical)
        .padding(.horizontal, Theme.Sidebar.paddingHorizontal)
        .frame(width: Theme.Sidebar.width)
    }

    private func siteIcon(letter: String, color: String, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Sidebar.iconCornerRadius)
                .fill(Color(hex: color).opacity(0.2))
            Text(letter)
                .font(Theme.Fonts.siteIconFallback)
                .foregroundStyle(Color(hex: color))
        }
        .frame(width: Theme.Sidebar.iconSize, height: Theme.Sidebar.iconSize)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Sidebar.iconCornerRadius))
    }
}
#endif
