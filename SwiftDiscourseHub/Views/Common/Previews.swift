#if DEBUG
import SwiftUI

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

    static let quoteMarkdown = """
    > **codinghorror:**
    > I think we should reconsider the approach to theme modifiers.
    > The current API is too complex for most plugin developers.

    I agree with this! The `ThemeModifier` API should be simpler.

    > **sam:**
    > We could add a convenience wrapper that handles the common cases.

    That's exactly what I had in mind. Here's a quick example:

    ```javascript
    api.modifyTheme("my-theme", {
      borderLeft: "3px solid var(--tertiary)"
    });
    ```
    """

    static let imageMarkdown = """
    Check out the new dashboard design:

    ![Dashboard screenshot](https://meta.discourse.org/uploads/default/original/3X/a/b/abc123.png#dim=690x400)

    And here's the mobile view:

    ![Mobile view](https://meta.discourse.org/uploads/default/original/3X/d/e/def456.png#dim=400x700)

    Let me know what you think of the layout!
    """

    static let richMarkdown = """
    Great news everyone! The new release is out.

    > **eviltrout:**
    > When can we expect the migration guide?

    The guide is ready. Here's a screenshot of the new settings panel:

    ![Settings](https://meta.discourse.org/uploads/default/original/3X/g/h/ghi789.png#dim=600x350)

    Key changes:

    1. **Improved** sidebar navigation
    2. New **dark mode** toggle
    3. Better mobile responsiveness

    > This is a simple blockquote without attribution,
    > showing how plain quotes render.

    See the [full changelog](https://meta.discourse.org/t/changelog) for details.
    """

    static let emojiMarkdown = """
    Hey everyone! 🎉 Just shipped the new release! 🚀

    A few notes:

    - Performance is way better now 💨
    - Dark mode finally works 🌙
    - Fixed that annoying bug with notifications 🔔

    Big thanks to @sam and @eviltrout for the reviews 👏 Let's keep the momentum going! 💪
    """

    static let tableMarkdown = """
    Here's a comparison of the rendering approaches we tested:

    | Approach | iOS | macOS | Performance | Rich Content |
    |----------|-----|-------|-------------|--------------|
    | SwiftUI Text | ✅ | ✅ | Fast | Limited |
    | NSAttributedString | ✅ | ✅ | Fast | Good |
    | WKWebView | ✅ | ✅ | Slow | Full |
    | Textual | ✅ | ✅ | Medium | Good |

    The NSAttributedString approach with Markdownosaur gave us the best balance of performance and rendering quality.
    """

    static let richLinkMarkdown = """
    For anyone interested, here are the relevant discussions:

    https://meta.discourse.org/t/improve-rendering-pipeline/12345

    The RFC for the new theme system is also worth reading:

    https://meta.discourse.org/t/rfc-theme-system-v2/67890

    And the original proposal that started it all:

    https://meta.discourse.org/t/native-mobile-apps/11111
    """

    static let whisperMarkdown = """
    *Staff note:* this user's account was flagged for review but it looks like a false positive. Clearing the flag now.

    Previous flags:
    - 2025-12-01: spam report (dismissed)
    - 2025-12-10: off-topic (dismissed)

    No action needed. 👍
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
        imageUrl: nil,
        lastReadPostNumber: nil
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
        imageUrl: nil,
        lastReadPostNumber: nil
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
        imageUrl: nil,
        lastReadPostNumber: nil
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
        imageUrl: nil,
        lastReadPostNumber: nil
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
        imageUrl: nil,
        lastReadPostNumber: nil
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
        imageUrl: nil,
        lastReadPostNumber: nil
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
        DiscourseCategory(id: 1, name: "Feature", slug: "feature", color: "25AAE2", textColor: "FFFFFF", topicCount: 100, postCount: 500, description: nil, descriptionText: nil, topicUrl: nil, subcategoryIds: nil, uploadedLogo: nil, parentCategoryId: nil, position: 0, subcategoryList: nil, notificationLevel: 3),
        DiscourseCategory(id: 2, name: "General", slug: "general", color: "0088CC", textColor: "FFFFFF", topicCount: 200, postCount: 1000, description: nil, descriptionText: nil, topicUrl: nil, subcategoryIds: nil, uploadedLogo: nil, parentCategoryId: nil, position: 1, subcategoryList: nil, notificationLevel: 1),
        DiscourseCategory(id: 3, name: "Bug", slug: "bug", color: "E45735", textColor: "FFFFFF", topicCount: 50, postCount: 300, description: nil, descriptionText: nil, topicUrl: nil, subcategoryIds: nil, uploadedLogo: nil, parentCategoryId: nil, position: 2, subcategoryList: nil, notificationLevel: nil),
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

// MARK: - Category Badges

#Preview("Category Badges") {
    HStack(spacing: 12) {
        CategoryBadgeView(name: "Feature", color: "25AAE2")
        CategoryBadgeView(name: "Bug", color: "E45735")
        CategoryBadgeView(name: "General", color: "0088CC")
        CategoryBadgeView(name: "Support", color: "808080")
    }
    .padding()
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
