import SwiftUI
import Nuke

/// Represents an item in the displayed post stream.
enum StreamItem: Identifiable, Equatable {
    case post(Post)
    case placeholder(id: String, count: Int)

    var id: String {
        switch self {
        case .post(let post): "post-\(post.id)"
        case .placeholder(let id, _): id
        }
    }

    static func == (lhs: StreamItem, rhs: StreamItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct TopicDetailView: View {
    let topicId: Int
    let site: DiscourseSite
    var topic: Topic?
    var categories: [DiscourseCategory] = []

    private var baseURL: String { site.baseURL }

    @State private var topicDetail: TopicDetailResponse?
    @State private var streamItems: [StreamItem] = []
    @State private var postMarkdown: [Int: String] = [:]
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var isJumping = false
    @State private var error: String?
    @State private var contentWidth: CGFloat = 0
    @State private var composerText = ""
    @State private var showComposer = false
    @State private var likedPostIds: Set<Int> = []
    @State private var scrollTarget: Int?
    @State private var scrollAnchor: UnitPoint = .bottom
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
    private let prefetcher = ImagePrefetcher(destination: .diskCache)

    private var hasMore: Bool {
        loadedPostIds.count < stream.count
    }

    private var lastReadPostNumber: Int? {
        topicDetail?.currentPostNumber
    }

    private var category: DiscourseCategory? {
        guard let id = topic?.categoryId else { return nil }
        return categories.first { $0.id == id }
    }

    private var replyCount: Int {
        max((topic?.postsCount ?? 1) - 1, 0)
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
            } else if !streamItems.isEmpty {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(streamItems) { item in
                                    switch item {
                                    case .post(let post):
                                        postRow(post)
                                    case .placeholder(_, let count):
                                        placeholderRow(count: count)
                                    }
                                }

                                if isLoadingMore {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                }

                                Spacer().frame(height: 100)
                            }
                        }
                        .scrollIndicators(.never)
                    #if os(iOS)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    #endif
                        .safeAreaInset(edge: .top, spacing: 0) {
                            if let topic {
                                topicHeader(topic)
                            }
                        }
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
                                    proxy.scrollTo(target, anchor: scrollAnchor)
                                }
                                scrollTarget = nil
                                scrollAnchor = .bottom
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        let hideFooter = !showFooter && !showComposer
                        AuthFooterBar(
                            site: site,
                            topicId: topicId,
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
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            if showComposer {
                NotificationCenter.default.post(name: .composerDidShow, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            NotificationCenter.default.post(name: .composerDidHide, object: nil)
        }
        #endif
        .task(id: topicId) {
            await loadTopic()
            if site.isAuthenticated {
                let highest = topic?.highestPostNumber ?? topicDetail?.highestPostNumber ?? 0
                readTracker.start(topicId: topicId, baseURL: baseURL, apiClient: apiClient, highestPostNumber: highest)
            }
        }
        .onDisappear {
            readTracker.stop()
            prefetcher.stopPrefetching()
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

                Label("^[\(replyCount) reply](inflect: true)", systemImage: "bubble.left.and.bubble.right")

                Spacer()

                if let url = topicURL {
                    Menu {
                        if site.isAuthenticated, let postNum = lastReadPostNumber, postNum > 1 {
                            Button {
                                Task { await jumpToPost(number: postNum) }
                            } label: {
                                Label("Jump to Post #\(postNum)", systemImage: "bookmark")
                            }
                        }
                        if let lastPostNum = topicDetail?.highestPostNumber, lastPostNum > 1 {
                            Button {
                                Task { await jumpToPost(number: lastPostNum) }
                            } label: {
                                Label("Jump to Last Post", systemImage: "arrow.down.to.line")
                            }
                        }
                        Divider()
                        Button {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #else
                            UIApplication.shared.open(url)
                            #endif
                        } label: {
                            Label("Open in Safari", systemImage: "safari")
                        }
                        ShareLink(item: url)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .scaleEffect(1.25)
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
        .background(.ultraThinMaterial)
    }

    // MARK: - Post Row

    @ViewBuilder
    private func postRow(_ post: Post) -> some View {
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
        Divider()
        Color.clear.frame(height: 0)
            .id(post.id)
            .onAppear {
                if let pn = post.postNumber {
                    readTracker.postAppeared(pn)
                }
                if case .post(let lastPost) = streamItems.last, lastPost.id == post.id {
                    Task { await loadMorePosts() }
                }
            }
            .onDisappear {
                if let pn = post.postNumber {
                    readTracker.postDisappeared(pn)
                }
            }
    }

    private func placeholderRow(count: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                Text("^[\(count) earlier post](inflect: true)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.placeholderVertical)
            .background(Color.blue.opacity(0.07))
            Divider()
        }
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
        if let item = streamItems.first(where: {
            if case .post(let p) = $0 { return p.postNumber == postNumber }
            return false
        }), case .post(let post) = item {
            scrollAnchor = .center
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
            let detail = try await apiClient.fetchTopic(baseURL: baseURL, topicId: topicId)
            topicDetail = detail
            stream = detail.postStream?.stream ?? []

            let missingIds = stream.filter { !loadedPostIds.contains($0) }
            guard !missingIds.isEmpty else { return }

            let response = try await apiClient.fetchTopicPosts(
                baseURL: baseURL, topicId: topicId, postIds: missingIds
            )
            appendPosts(response.postStream.posts)

            if let lastNewPost = response.postStream.posts.last,
               let postNumber = lastNewPost.postNumber {
                let rawText = try await apiClient.fetchTopicRaw(
                    baseURL: baseURL, topicId: topicId, postNumber: postNumber
                )
                let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
                postMarkdown[postNumber] = preprocessor.process(rawText)
            }

            if case .post(let lastPost) = streamItems.last {
                scrollTarget = lastPost.id
            }
        } catch {
            await loadTopic()
        }
    }

    // MARK: - Initial load

    private func loadTopic() async {
        isLoading = true
        error = nil
        streamItems = []
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
            registerPosts(initialPosts)
            streamItems = initialPosts.map { .post($0) }

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
        guard hasMore, !isLoadingMore, !isJumping else { return }
        isLoadingMore = true

        do {
            // Find next unloaded IDs in stream order after the last loaded post
            let lastLoadedIndex = streamItems.compactMap { item -> Int? in
                if case .post(let p) = item { return stream.firstIndex(of: p.id) }
                return nil
            }.max() ?? -1
            let nextIds = Array(stream.suffix(from: min(lastLoadedIndex + 1, stream.count)))
                .filter { !loadedPostIds.contains($0) }
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
                let highestLoadedPostNumber = streamItems.compactMap {
                    if case .post(let p) = $0 { return p.postNumber }
                    return nil
                }.max() ?? 0
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

    private func registerPosts(_ posts: [Post]) {
        var urls: [URL] = []
        for post in posts {
            loadedPostIds.insert(post.id)
            if let username = post.username, let template = post.avatarTemplate {
                avatarLookup[username] = template
                if let url = URLHelpers.avatarURL(template: template, size: 80, baseURL: baseURL) {
                    urls.append(url)
                }
            }
        }
        if !urls.isEmpty {
            prefetcher.startPrefetching(with: urls)
        }
    }

    private func appendPosts(_ newPosts: [Post]) {
        let filtered = newPosts.filter { !loadedPostIds.contains($0.id) }
        registerPosts(filtered)
        streamItems.append(contentsOf: filtered.map { .post($0) })
    }

    // MARK: - Jump to Post

    private func jumpToPost(number targetPostNumber: Int) async {
        // If already loaded, just scroll to it
        if let item = streamItems.first(where: {
            if case .post(let p) = $0 { return p.postNumber == targetPostNumber }
            return false
        }), case .post(let post) = item {
            scrollAnchor = .center
            scrollTarget = post.id
            return
        }

        guard !isJumping else { return }
        isJumping = true

        do {
            // Find the target post's position in the stream
            // Post numbers roughly correspond to stream indices (1-indexed),
            // but deletions can cause gaps. Estimate the index.
            let estimatedIdx = min(max(targetPostNumber - 1, 0), stream.count - 1)

            // Gather post IDs: up to 10 before target, the target area, up to 10 after
            let startIdx = max(0, estimatedIdx - 10)
            let endIdx = min(stream.count, estimatedIdx + 11)
            let postIdsToFetch = Array(stream[startIdx..<endIdx])
                .filter { !loadedPostIds.contains($0) }

            guard !postIdsToFetch.isEmpty else {
                isJumping = false
                return
            }

            // Fetch posts and raw markdown in parallel
            async let postsResponse = apiClient.fetchTopicPosts(
                baseURL: baseURL, topicId: topicId, postIds: postIdsToFetch
            )
            let rawPage = (targetPostNumber - 1) / rawPageSize + 1
            async let rawResponse = apiClient.fetchTopicRaw(
                baseURL: baseURL, topicId: topicId, page: rawPage
            )

            let fetchedPosts = try await postsResponse.postStream.posts
            let rawText = try await rawResponse
            processRawText(rawText)

            // Register the new posts
            registerPosts(fetchedPosts)

            // Build the new stream items:
            // 1. Existing items (initial posts)
            // 2. Placeholder for the gap
            // 3. Fetched posts around the target
            let existingPostIds = Set(streamItems.compactMap { item -> Int? in
                if case .post(let p) = item { return p.id }
                return nil
            })
            let newPosts = fetchedPosts.filter { !existingPostIds.contains($0.id) }
                .sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }

            guard !newPosts.isEmpty else {
                isJumping = false
                return
            }

            // Calculate how many posts are in the gap between existing and new
            let lastExistingPostNumber = streamItems.compactMap { item -> Int? in
                if case .post(let p) = item { return p.postNumber }
                return nil
            }.max() ?? 0
            let firstNewPostNumber = newPosts.first?.postNumber ?? 0
            let gapCount = max(0, firstNewPostNumber - lastExistingPostNumber - 1)

            // Insert placeholder + new posts
            if gapCount > 0 {
                streamItems.append(.placeholder(
                    id: "gap-\(lastExistingPostNumber)-\(firstNewPostNumber)",
                    count: gapCount
                ))
            }
            streamItems.append(contentsOf: newPosts.map { .post($0) })

            // Wait for layout, then scroll to the target post
            try? await Task.sleep(for: .milliseconds(500))
            scrollAnchor = .center
            if let targetPost = newPosts.first(where: { $0.postNumber == targetPostNumber }) {
                scrollTarget = targetPost.id
            } else if let closest = newPosts.min(by: {
                abs(($0.postNumber ?? 0) - targetPostNumber) < abs(($1.postNumber ?? 0) - targetPostNumber)
            }) {
                scrollTarget = closest.id
            }
        } catch {
            toastManager.show("Failed to jump to post", style: .error)
        }

        isJumping = false
    }

    private func processRawText(_ rawText: String) {
        let rawPosts = RawTopicParser.parse(rawText)
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
        var imageURLs: [URL] = []
        for rawPost in rawPosts {
            let processed = preprocessor.process(rawPost.markdown)
            postMarkdown[rawPost.postNumber] = processed
            imageURLs.append(contentsOf: Self.extractImageURLs(from: processed, baseURL: baseURL))
        }
        if !imageURLs.isEmpty {
            prefetcher.startPrefetching(with: imageURLs)
        }
    }

    private static func extractImageURLs(from markdown: String, baseURL: String) -> [URL] {
        // Match ![alt](url) or ![alt](url#dim=WxH)
        guard let regex = try? NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#) else { return [] }
        let range = NSRange(markdown.startIndex..., in: markdown)
        return regex.matches(in: markdown, range: range).compactMap { match in
            guard let urlRange = Range(match.range(at: 1), in: markdown) else { return nil }
            var urlString = String(markdown[urlRange])
            // Strip #dim=WxH fragment for prefetching the actual image
            if let fragmentIdx = urlString.firstIndex(of: "#") {
                urlString = String(urlString[..<fragmentIdx])
            }
            if urlString.hasPrefix("http") {
                return URL(string: urlString)
            }
            return URL(string: urlString, relativeTo: URL(string: baseURL))?.absoluteURL
        }
    }
}

private struct ScrollGeometryInfo: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}
