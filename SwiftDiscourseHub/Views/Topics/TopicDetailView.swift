import SwiftUI
import Nuke
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "TopicDetail")

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

    @State private var dataSource = PostStreamDataSource()
    @State private var isLoading = true
    @State private var isJumping = false
    @State private var error: String?
    @State private var contentWidth: CGFloat = 0
    @State private var composerText = ""
    @State private var showComposer = false
    @State private var likedPostIds: Set<Int> = []
    @State private var readTracker = TopicReadTracker()
    @State private var showFooter = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollToPostId: Int?
    @State private var scrollAnchor: UnitPoint = .bottom

    @Environment(\.apiClient) private var apiClient
    @Environment(ToastManager.self) private var toastManager

    private var topicURL: URL? {
        URLHelpers.resolveURL("/t/\(topicId)", baseURL: baseURL)
    }

    private var lastReadPostNumber: Int? {
        dataSource.topicDetail?.currentPostNumber
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
            } else if !dataSource.items.isEmpty {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        postStreamContent
                            .padding(.top, 1) // prevent content from underlapping header

                        if let topic {
                            topicHeader(topic)
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
                let highest = topic?.highestPostNumber ?? dataSource.topicDetail?.highestPostNumber ?? 0
                readTracker.start(topicId: topicId, baseURL: baseURL, apiClient: apiClient, highestPostNumber: highest)
            }
        }
        .onDisappear {
            readTracker.stop()
            dataSource.stopPrefetching()
        }
        .navigationDestination(for: LinkedTopicDestination.self) { dest in
            TopicDetailView(topicId: dest.topicId, site: site, categories: categories)
        }
    }

    // MARK: - Post Stream Content (platform-specific)

    @ViewBuilder
    private var postStreamContent: some View {
        #if os(iOS)
        PostStreamCollectionView(
            items: dataSource.items,
            postMarkdown: dataSource.postMarkdown,
            avatarLookup: dataSource.avatarLookup,
            baseURL: baseURL,
            contentWidth: contentWidth,
            topicId: topicId,
            likedPostIds: likedPostIds,
            isAuthenticated: site.isAuthenticated,
            isLoadingOlder: dataSource.isLoadingOlder,
            isLoadingNewer: dataSource.isLoadingNewer,
            scrollToPostId: scrollToPostId,
            scrollAnchor: scrollAnchor == .center ? .centeredVertically : .bottom,
            onLike: { post in
                await toggleLike(post: post)
            },
            onQuote: { text, post in
                quoteText(text, from: post)
            },
            onScrollToPost: { postNumber in
                scrollToPostNumber(postNumber)
            },
            onPostAppeared: { post in
                if let pn = post.postNumber {
                    readTracker.postAppeared(pn)
                }
                handlePostAppeared(post)
            },
            onPostDisappeared: { post in
                if let pn = post.postNumber {
                    readTracker.postDisappeared(pn)
                }
            },
            onScrollChange: { offset, contentHeight, containerHeight in
                handleScrollChange(offset: offset, contentHeight: contentHeight, containerHeight: containerHeight)
            }
        )
        #else
        macOSPostStream
        #endif
    }

    // MARK: - macOS Fallback (SwiftUI ScrollView)

    #if os(macOS)
    private var macOSPostStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(dataSource.items) { item in
                        switch item {
                        case .post(let post):
                            macOSPostRow(post)
                        case .placeholder(_, let count):
                            placeholderRow(count: count)
                        }
                    }

                    if dataSource.isLoadingNewer {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    Spacer().frame(height: 100)
                }
            }
            .scrollIndicators(.never)
            .onChange(of: scrollToPostId) {
                if let target = scrollToPostId {
                    withAnimation {
                        proxy.scrollTo(target, anchor: scrollAnchor)
                    }
                    scrollToPostId = nil
                    scrollAnchor = .bottom
                }
            }
        }
    }

    @ViewBuilder
    private func macOSPostRow(_ post: Post) -> some View {
        if post.isSmallAction {
            SmallActionView(post: post)
                .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
        } else {
            PostView(
                post: post,
                baseURL: baseURL,
                markdown: dataSource.postMarkdown[post.postNumber ?? 0],
                contentWidth: contentWidth,
                isLiked: likedPostIds.contains(post.id) || post.hasLiked,
                isWhisper: post.isWhisper,
                currentTopicId: topicId,
                avatarLookup: dataSource.avatarLookup,
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
                handlePostAppeared(post)
            }
            .onDisappear {
                if let pn = post.postNumber {
                    readTracker.postDisappeared(pn)
                }
            }
    }
    #endif

    // MARK: - Load Triggers

    private func handlePostAppeared(_ post: Post) {
        guard let idx = dataSource.postIndex(of: post.id) else { return }
        let postCount = dataSource.postCount
        let threshold = PostStreamDataSource.prefetchThreshold

        // Near the bottom — load newer
        if idx >= postCount - threshold {
            if idx >= postCount - 3 {
                log.info("[appear] near-bottom post \(post.id) (idx=\(idx)/\(postCount)) — triggering loadNewer")
                Task { await dataSource.loadNewer() }
            }
        }

        // Near the top — front-load older
        if idx < threshold, dataSource.canLoadOlder, !dataSource.isLoadingOlder {
            log.info("[appear] near-top post \(post.id) (idx=\(idx)/\(postCount)) — triggering loadOlder")
            Task { await dataSource.loadOlder() }
        }
    }

    // MARK: - Scroll Footer Visibility

    private func handleScrollChange(offset: CGFloat, contentHeight: CGFloat, containerHeight: CGFloat) {
        let newOffset = offset
        let delta = newOffset - lastScrollOffset
        let atBottom = !dataSource.hasMore && offset + containerHeight >= contentHeight - 20

        if newOffset <= 0 || atBottom {
            if !showFooter {
                withAnimation(.easeInOut(duration: 0.2)) { showFooter = true }
            }
            lastScrollOffset = newOffset
            return
        }
        if delta > 40 {
            if showFooter {
                withAnimation(.easeInOut(duration: 0.2)) { showFooter = false }
            }
            lastScrollOffset = newOffset
        } else if delta < -40 {
            if !showFooter {
                withAnimation(.easeInOut(duration: 0.2)) { showFooter = true }
            }
            lastScrollOffset = newOffset
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
                        if let lastPostNum = dataSource.topicDetail?.highestPostNumber, lastPostNum > 1 {
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
        if let item = dataSource.items.first(where: {
            if case .post(let p) = $0 { return p.postNumber == postNumber }
            return false
        }), case .post(let post) = item {
            scrollAnchor = .center
            scrollToPostId = post.id
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
            if let scrollId = try await dataSource.refreshAfterPost() {
                scrollToPostId = scrollId
            }
        } catch {
            await loadTopic()
        }
    }

    // MARK: - Initial load

    private func loadTopic() async {
        isLoading = true
        error = nil
        showFooter = true
        lastScrollOffset = 0
        scrollToPostId = nil

        dataSource.configure(apiClient: apiClient, baseURL: baseURL, topicId: topicId)

        do {
            try await dataSource.loadInitial()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Jump to Post

    private func jumpToPost(number targetPostNumber: Int) async {
        guard !isJumping else { return }
        isJumping = true

        if let postId = await dataSource.jumpToPost(number: targetPostNumber) {
            try? await Task.sleep(for: .milliseconds(500))
            scrollAnchor = .center
            scrollToPostId = postId
        } else {
            toastManager.show("Failed to jump to post", style: .error)
        }

        isJumping = false
    }
}

private struct ScrollGeometryInfo: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}
