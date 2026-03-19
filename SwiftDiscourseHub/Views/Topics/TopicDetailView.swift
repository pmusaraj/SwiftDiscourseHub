import SwiftUI

struct TopicDetailView: View {
    let topicId: Int
    let site: DiscourseSite
    var topic: Topic?
    var categories: [DiscourseCategory] = []

    private var baseURL: String { site.baseURL }


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
    @State private var readTracker = TopicReadTracker()
    @State private var showFooter = true
    @State private var lastScrollOffset: CGFloat = 0

    // Pagination state
    @State private var stream: [Int] = []
    @State private var loadedPostIds: Set<Int> = []
    @State private var rawPage = 1
    @State private var rawExhausted = false

    @Environment(\.apiClient) private var apiClient
    @Environment(ToastManager.self) private var toastManager
    private let rawPageSize = 100
    private let jsonChunkSize = 20

    private var topicURL: URL? {
        URLHelpers.resolveURL("/t/\(topicId)", baseURL: baseURL)
    }

    @State private var avatarLookup: [String: String] = [:]

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
                                    if post.isSmallAction {
                                        SmallActionView(post: post)
                                            .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
                                    } else {
                                        PostView(
                                            post: post,
                                            baseURL: baseURL,
                                            markdown: postMarkdown[post.postNumber ?? 0],
                                            contentWidth: contentWidth,
                                            isLiked: likedPostIds.contains(post.id) || post.hasLiked,
                                            isWhisper: post.isWhisper,
                                            currentTopicId: topicId,
                                            avatarLookup: avatarLookup,
                                            onLike: post.canLike ? {
                                                guard site.isAuthenticated else {
                                                    toastManager.show("Please login to like this post", style: .info)
                                                    return
                                                }
                                                await toggleLike(post: post)
                                            } : nil,
                                            onQuote: { selectedText in
                                                quoteText(selectedText, from: post)
                                            },
                                            onScrollToPost: { postNumber in
                                                scrollToPostNumber(postNumber)
                                            }
                                        )
                                    }
                                    if post.id != loadedPosts.last?.id {
                                        Divider()
                                    }
                                    Color.clear.frame(height: 0)
                                        .id(post.id)
                                        .onAppear {
                                            if let pn = post.postNumber {
                                                readTracker.postAppeared(pn)
                                            }
                                            if post.id == loadedPosts.last?.id {
                                                Task { await loadMorePosts() }
                                            }
                                        }
                                        .onDisappear {
                                            if let pn = post.postNumber {
                                                readTracker.postDisappeared(pn)
                                            }
                                        }
                                }

                                if isLoadingMore {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }

                                Spacer().frame(height: 60)
                            }
                        }
                        .scrollIndicators(.never)
                    #if os(iOS)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    #endif
                        .onScrollGeometryChange(for: ScrollGeometryInfo.self) { geometry in
                            ScrollGeometryInfo(
                                offset: geometry.contentOffset.y,
                                contentHeight: geometry.contentSize.height,
                                containerHeight: geometry.visibleRect.height
                            )
                        } action: { _, info in
                            let newOffset = info.offset
                            let delta = newOffset - lastScrollOffset
                            // At top or bottom (with all posts loaded) — always show
                            let atBottom = !hasMore && info.offset + info.containerHeight >= info.contentHeight - 20
                            if newOffset <= 0 || atBottom {
                                if !showFooter {
                                    withAnimation(.easeInOut(duration: 0.2)) { showFooter = true }
                                }
                                lastScrollOffset = newOffset
                                return
                            }
                            // Scrolling down — hide
                            if delta > 40 {
                                if showFooter {
                                    withAnimation(.easeInOut(duration: 0.2)) { showFooter = false }
                                }
                                lastScrollOffset = newOffset
                            }
                            // Scrolling up at least 40pt — show
                            else if delta < -40 {
                                if !showFooter {
                                    withAnimation(.easeInOut(duration: 0.2)) { showFooter = true }
                                }
                                lastScrollOffset = newOffset
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
                    .overlay(alignment: .bottom) {
                        let hideFooter = !showFooter && !showComposer
                        AuthFooterBar(
                            site: site,
                            topicId: topicId,
                            username: currentUsername,
                            composerText: $composerText,
                            showComposer: $showComposer
                        ) {
                            Task { await refreshAfterPost() }
                        }
                        .offset(y: hideFooter ? 100 : 0)
                        .opacity(hideFooter ? 0 : 1)
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
        .navigationTitle("")
        #if os(macOS)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar(removing: .title)
        #endif
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .navigationBar)
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .showReplyComposer)) { _ in
            guard site.hasApiKey, !showComposer else { return }
            showComposer = true
        }
        .onChange(of: showComposer) {
            #if !os(macOS)
            if showComposer {
                NotificationCenter.default.post(name: .composerDidShow, object: nil)
            } else {
                NotificationCenter.default.post(name: .composerDidHide, object: nil)
            }
            #endif
        }
        .task(id: topicId) {
            await loadTopic()
            if site.isAuthenticated {
                let highest = topic?.highestPostNumber ?? loadedPosts.compactMap(\.postNumber).max() ?? 0
                readTracker.start(topicId: topicId, baseURL: baseURL, apiClient: apiClient, highestPostNumber: highest)
            }
        }
        .onDisappear {
            readTracker.stop()
        }
        .navigationDestination(for: LinkedTopicDestination.self) { dest in
            TopicDetailView(topicId: dest.topicId, site: site, categories: categories)
        }
    }

    // MARK: - Topic Header

    @ViewBuilder
    private func topicHeader(_ topic: Topic) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.topicHeaderVertical) {
            HStack(spacing: 6) {
                if topic.pinned == true {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                }
                if topic.closed == true {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                if topic.archived == true {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(.secondary)
                }
                if topic.visible == false {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(.secondary)
                }
                Text(topic.title ?? "Untitled")
                    .font(Theme.Fonts.topicHeaderTitle)
                    .lineLimit(Theme.LineLimit.topicHeaderTitle)
            }

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

                Label("^[\(replyCount) reply](inflect: true)", systemImage: "bubble.left.and.bubble.right")

                Spacer()

                if let url = topicURL {
                    Button {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    } label: {
                        Image(systemName: "safari")
                    }
                    .buttonStyle(.plain)
                    .help("Open in Safari")

                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(Theme.Fonts.metadata)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 0)
        .padding(.bottom, Theme.Padding.postVertical)
        .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

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

    private func scrollToPostNumber(_ postNumber: Int) {
        if let post = loadedPosts.first(where: { $0.postNumber == postNumber }) {
            scrollTarget = post.id
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
        showFooter = true
        lastScrollOffset = 0
        avatarLookup = [:]

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
                if let username = post.username, let template = post.avatarTemplate {
                    avatarLookup[username] = template
                }
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
            if let username = post.username, let template = post.avatarTemplate {
                avatarLookup[username] = template
            }
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

private struct ScrollGeometryInfo: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}
