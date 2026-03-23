import SwiftUI
import Nuke
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "TopicDetail")

/// Represents an item in the displayed post stream.
enum StreamItem: Identifiable, Hashable {
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct TopicDetailView: View {
    let topicId: Int
    let site: DiscourseSite
    var topic: Topic?
    var categories: [DiscourseCategory] = []
    var startPostNumber: Int?

    private var baseURL: String { site.baseURL }

    @State private var dataSource = PostStreamDataSource()
    @State private var isLoading = true
    @State private var isJumping = false
    @State private var error: String?
    @State private var contentWidth: CGFloat = 0
    @State private var composerText = ""
    @State private var showComposer = false
    @State private var likedPostIds: Set<Int> = []
    @State private var showFooter = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollToPostId: Int?
    @State private var scrollAnchor: UnitPoint = .bottom
    @State private var headerHeight: CGFloat = 0

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
                        if headerHeight > 0 {
                            postStreamContent
                        }

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
        .toolbar(.hidden, for: .navigationBar)
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
            await loadTopic(nearPost: startPostNumber)
        }
        .onDisappear {
            dataSource.stopPrefetching()
            if site.isAuthenticated {
                Task { await dataSource.sendTimings() }
            }
        }
        .navigationDestination(for: LinkedTopicDestination.self) { dest in
            TopicDetailView(topicId: dest.topicId, site: site, categories: categories)
        }
    }

    // MARK: - Post Stream Content (platform-specific)

    @ViewBuilder
    private var postStreamContent: some View {
        #if os(iOS)
        ChatLayoutPostStreamView(
            items: dataSource.items,
            postMarkdown: dataSource.postMarkdown,
            postOneboxes: dataSource.postOneboxes,
            avatarLookup: dataSource.avatarLookup,
            baseURL: baseURL,
            contentWidth: contentWidth,
            topicId: topicId,
            likedPostIds: likedPostIds,
            isAuthenticated: site.isAuthenticated,
            topInset: headerHeight,
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
            onLoadOlder: {
                Task { await dataSource.loadOlder() }
            },
            onLoadNewer: {
                Task { await dataSource.loadNewer() }
            },
            canLoadOlder: dataSource.canLoadOlder,
            canLoadNewer: dataSource.canLoadNewer,
            isLoadingOlder: dataSource.isLoadingOlder,
            isLoadingNewer: dataSource.isLoadingNewer,
            onScrollChange: { offset, contentHeight, containerHeight in
                handleScrollChange(offset: offset, contentHeight: contentHeight, containerHeight: containerHeight)
            },
            onScrollConsumed: {
                scrollToPostId = nil
                scrollAnchor = .bottom
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
                    // Clear the floating header
                    Spacer().frame(height: headerHeight)

                    ForEach(dataSource.items) { item in
                        switch item {
                        case .post(let post):
                            macOSPostRow(post)
                        case .placeholder(_, let count):
                            placeholderRow(count: count)
                        }
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
                oneboxes: dataSource.postOneboxes[post.postNumber ?? 0] ?? [],
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
                let items = dataSource.items
                let postItem = StreamItem.post(post)
                guard let idx = items.firstIndex(of: postItem) else { return }
                // Load newer when within 3 posts of the end
                if idx >= items.count - 3, dataSource.canLoadNewer, !dataSource.isLoadingNewer {
                    Task { await dataSource.loadNewer() }
                }
                // Load older when within 3 posts of the start
                if idx <= 2, dataSource.canLoadOlder, !dataSource.isLoadingOlder {
                    Task { await dataSource.loadOlder() }
                }
            }
    }
    #endif

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
                        if let lastPostNum = dataSource.topicDetail?.highestPostNumber, lastPostNum > 1 {
                            Button {
                                Task { await jumpToPost(number: lastPostNum) }
                            } label: {
                                Label("Jump to Last Post", systemImage: "arrow.down.to.line")
                            }
                        }
                        Button {
                            Task { await jumpToPost(number: 25) }
                        } label: {
                            Label("Jump to Post #25", systemImage: "arrow.right.to.line")
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
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(Theme.Fonts.metadata)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 0)
        .padding(.bottom, 0)
        .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            headerHeight = newHeight
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

    private func loadTopic(nearPost postNumber: Int? = nil) async {
        isLoading = true
        error = nil
        showFooter = true
        lastScrollOffset = 0
        scrollToPostId = nil

        dataSource.configure(apiClient: apiClient, baseURL: baseURL, topicId: topicId)

        do {
            if let postId = try await dataSource.loadInitial(nearPost: postNumber) {
                scrollAnchor = .center
                scrollToPostId = postId
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Jump to Post

    private func jumpToPost(number targetPostNumber: Int) async {
        guard !isJumping else { return }

        // If the post is already loaded, just scroll to it — no network request needed
        if let item = dataSource.items.first(where: {
            if case .post(let p) = $0 { return p.postNumber == targetPostNumber }
            return false
        }), case .post(let post) = item {
            scrollAnchor = .center
            scrollToPostId = post.id
            return
        }

        isJumping = true

        if let postId = await dataSource.jumpToPost(number: targetPostNumber) {
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
