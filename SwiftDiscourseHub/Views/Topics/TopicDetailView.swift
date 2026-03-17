import SwiftUI

struct TopicDetailView: View {
    let topicId: Int
    let site: DiscourseSite
    var topic: Topic?
    var categories: [DiscourseCategory] = []

    private var baseURL: String { site.baseURL }
    private var siteTitle: String { site.title }

    @State private var topicDetail: TopicDetailResponse?
    @State private var loadedPosts: [Post] = []
    @State private var postMarkdown: [Int: String] = [:]
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var error: String?
    @State private var contentWidth: CGFloat = 0
    @State private var composerText = ""
    @State private var showComposer = false
    @State private var likedPostIds: Set<Int> = []
    @State private var scrollTarget: Int?

    // Pagination state
    @State private var stream: [Int] = []
    @State private var loadedPostIds: Set<Int> = []
    @State private var rawPage = 1
    @State private var rawExhausted = false

    @Environment(\.apiClient) private var apiClient
    @Environment(ToastManager.self) private var toastManager
    #if os(macOS)
    @State private var keyMonitor: Any?
    #endif
    private let rawPageSize = 100
    private let jsonChunkSize = 20

    private var topicURL: URL? {
        URLHelpers.resolveURL("/t/\(topicId)", baseURL: baseURL)
    }

    private var hasMore: Bool {
        loadedPostIds.count < stream.count
    }

    private var category: DiscourseCategory? {
        guard let id = topic?.categoryId else { return nil }
        return categories.first { $0.id == id }
    }

    private var replyCount: Int {
        max((topic?.postsCount ?? 1) - 1, 0)
    }

    private var currentUsername: String? {
        loadedPosts.first(where: { $0.yours == true })?.username
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading topic...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ErrorStateView(title: "Failed to Load", message: error) {
                    Task { await loadTopic() }
                }
            } else if !loadedPosts.isEmpty {
                VStack(spacing: 0) {
                    if let topic {
                        topicHeader(topic)
                        Divider()
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(loadedPosts) { post in
                                    PostView(
                                        post: post,
                                        baseURL: baseURL,
                                        markdown: postMarkdown[post.postNumber ?? 0],
                                        contentWidth: contentWidth,
                                        isLiked: likedPostIds.contains(post.id) || post.hasLiked,
                                        onLike: post.canLike ? { await toggleLike(post: post) } : nil,
                                        onQuote: { selectedText in
                                            quoteText(selectedText, from: post)
                                        }
                                    )
                                    .id(post.id)
                                    if post.id != loadedPosts.last?.id {
                                        Divider()
                                    }
                                    Color.clear.frame(height: 0)
                                        .onAppear {
                                            if post.id == loadedPosts.last?.id {
                                                Task { await loadMorePosts() }
                                            }
                                        }
                                }

                                if isLoadingMore {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }
                            }
                        }
                        .onChange(of: scrollTarget) {
                            if let target = scrollTarget {
                                withAnimation {
                                    proxy.scrollTo(target, anchor: .bottom)
                                }
                                scrollTarget = nil
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        AuthFooterBar(
                            site: site,
                            topicId: topicId,
                            username: currentUsername,
                            composerText: $composerText,
                            showComposer: $showComposer
                        ) {
                            Task { await refreshAfterPost() }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    contentWidth = newWidth
                }
            } else {
                ContentUnavailableView("No Posts", systemImage: "text.bubble")
            }
        }
        .navigationTitle(siteTitle)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let url = topicURL {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    } label: {
                        Image(systemName: "safari")
                    }
                    .help("Open in Safari")
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url)
                }
            }
        }
        #if os(macOS)
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
        .onChange(of: topicId) { removeKeyMonitor(); installKeyMonitor() }
        #endif
        .task(id: topicId) {
            await loadTopic()
        }
    }

    // MARK: - Topic Header

    @ViewBuilder
    private func topicHeader(_ topic: Topic) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.topicHeaderVertical) {
            Text(topic.title ?? "Untitled")
                .font(Theme.Fonts.topicHeaderTitle)
                .lineLimit(Theme.LineLimit.topicHeaderTitle)

            HStack(spacing: Theme.Spacing.topicHeaderMetadata) {
                if let cat = category {
                    CategoryBadgeView(name: cat.name ?? "Unknown", color: cat.color)
                }

                if let createdAt = topic.createdAt {
                    Label {
                        RelativeTimeText(dateString: createdAt)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }

                Spacer()

                Label("\(replyCount) \(replyCount == 1 ? "reply" : "replies")", systemImage: "bubble.left.and.bubble.right")
            }
            .font(Theme.Fonts.metadata)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Padding.postVertical)
        .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    // MARK: - Key Monitor

    #if os(macOS)
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle "r" with no modifiers, and only when composer is hidden
            // and the first responder is not a text input field
            guard event.characters == "r",
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [],
                  site.hasApiKey,
                  !showComposer,
                  !isFirstResponderTextInput() else {
                return event
            }
            showComposer = true
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func isFirstResponderTextInput() -> Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else { return false }
        return firstResponder is NSTextView || firstResponder is NSTextField
    }
    #endif

    // MARK: - Actions

    private func toggleLike(post: Post) async {
        let alreadyLiked = likedPostIds.contains(post.id) || post.hasLiked
        do {
            if alreadyLiked {
                try await apiClient.unlikePost(baseURL: baseURL, postId: post.id)
                likedPostIds.remove(post.id)
            } else {
                try await apiClient.likePost(baseURL: baseURL, postId: post.id)
                likedPostIds.insert(post.id)
            }
        } catch {
            toastManager.show(error.localizedDescription, style: .error)
        }
    }

    private func quoteText(_ text: String, from post: Post) {
        let quote = MarkdownFormatter.quoteReply(
            text: text,
            username: post.username ?? "unknown",
            topicId: topicId,
            postNumber: post.postNumber ?? 1
        )
        composerText += quote
        showComposer = true
    }

    // MARK: - Refresh after posting

    private func refreshAfterPost() async {
        do {
            // Re-fetch topic to get updated stream with the new post
            let detail = try await apiClient.fetchTopic(baseURL: baseURL, topicId: topicId)
            topicDetail = detail
            stream = detail.postStream?.stream ?? []

            // Find post IDs we don't have yet
            let missingIds = stream.filter { !loadedPostIds.contains($0) }
            guard !missingIds.isEmpty else { return }

            // Fetch the new posts
            let response = try await apiClient.fetchTopicPosts(
                baseURL: baseURL, topicId: topicId, postIds: missingIds
            )
            appendPosts(response.postStream.posts)

            // Fetch raw markdown for new posts
            if let lastNewPost = response.postStream.posts.last,
               let postNumber = lastNewPost.postNumber {
                let rawText = try await apiClient.fetchTopicRaw(
                    baseURL: baseURL, topicId: topicId, postNumber: postNumber
                )
                let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
                postMarkdown[postNumber] = preprocessor.process(rawText)
            }

            // Scroll to the newly added post
            if let lastId = loadedPosts.last?.id {
                scrollTarget = lastId
            }
        } catch {
            // Fall back to full reload if incremental refresh fails
            await loadTopic()
        }
    }

    // MARK: - Initial load

    private func loadTopic() async {
        isLoading = true
        error = nil
        loadedPosts = []
        postMarkdown = [:]
        loadedPostIds = []
        rawPage = 1
        rawExhausted = false

        do {
            async let jsonResponse = apiClient.fetchTopic(baseURL: baseURL, topicId: topicId)
            async let rawResponse = apiClient.fetchTopicRaw(baseURL: baseURL, topicId: topicId, page: 1)

            let detail = try await jsonResponse
            topicDetail = detail
            stream = detail.postStream?.stream ?? []

            let initialPosts = detail.postStream?.posts ?? []
            loadedPosts = initialPosts
            for post in initialPosts {
                loadedPostIds.insert(post.id)
            }

            let rawText = try await rawResponse
            processRawText(rawText)
            rawPage = 2
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load more

    private func loadMorePosts() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true

        do {
            let nextIds = stream.filter { !loadedPostIds.contains($0) }
            let batch = Array(nextIds.prefix(jsonChunkSize))

            guard !batch.isEmpty else {
                isLoadingMore = false
                return
            }

            async let jsonResponse = apiClient.fetchTopicPosts(
                baseURL: baseURL, topicId: topicId, postIds: batch
            )

            let needsMoreRaw: Bool = {
                guard !rawExhausted else { return false }
                let highestLoadedPostNumber = loadedPosts.last?.postNumber ?? 0
                let rawCoverage = rawPage * rawPageSize
                return highestLoadedPostNumber + jsonChunkSize > rawCoverage - 20
            }()

            if needsMoreRaw {
                async let rawResponse = apiClient.fetchTopicRaw(
                    baseURL: baseURL, topicId: topicId, page: rawPage
                )
                let posts = try await jsonResponse
                appendPosts(posts.postStream.posts)

                let rawText = try await rawResponse
                if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rawExhausted = true
                } else {
                    processRawText(rawText)
                    rawPage += 1
                }
            } else {
                let posts = try await jsonResponse
                appendPosts(posts.postStream.posts)
            }
        } catch {
            // Don't set error for pagination failures
        }
        isLoadingMore = false
    }

    // MARK: - Helpers

    private func appendPosts(_ newPosts: [Post]) {
        for post in newPosts where !loadedPostIds.contains(post.id) {
            loadedPostIds.insert(post.id)
            loadedPosts.append(post)
        }
    }

    private func processRawText(_ rawText: String) {
        let rawPosts = RawTopicParser.parse(rawText)
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
        for rawPost in rawPosts {
            postMarkdown[rawPost.postNumber] = preprocessor.process(rawPost.markdown)
        }
    }
}

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
        VStack(alignment: .leading, spacing: Theme.Spacing.postContentVertical) {
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

            // Content
            if let md = markdown {
                PostContentView(markdown: md, baseURL: baseURL)
                    .contextMenu {
                        if let onQuote {
                            Button {
                                // Quote the full post content when right-clicking
                                let plainText = md
                                    .replacingOccurrences(of: "\\!\\[.*?\\]\\(.*?\\)", with: "[image]", options: .regularExpression)
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
