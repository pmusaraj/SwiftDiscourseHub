import SwiftUI

struct TopicDetailView: View {
    let topicId: Int
    let baseURL: String

    @State private var topicDetail: TopicDetailResponse?
    @State private var loadedPosts: [Post] = []
    @State private var postMarkdown: [Int: String] = [:]
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var error: String?

    // Pagination state
    @State private var stream: [Int] = []           // all post IDs in topic
    @State private var loadedPostIds: Set<Int> = []  // post IDs we have metadata for
    @State private var rawPage = 1                   // next raw page to fetch
    @State private var rawExhausted = false          // no more raw pages

    private let apiClient = DiscourseAPIClient()
    private let rawPageSize = 100
    private let jsonChunkSize = 20

    private var topicURL: URL? {
        URLHelpers.resolveURL("/t/\(topicId)", baseURL: baseURL)
    }

    private var hasMore: Bool {
        loadedPostIds.count < stream.count
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(loadedPosts) { post in
                            PostView(
                                post: post,
                                baseURL: baseURL,
                                markdown: postMarkdown[post.postNumber ?? 0]
                            )
                            Divider()
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
            } else {
                ContentUnavailableView("No Posts", systemImage: "text.bubble")
            }
        }
        .navigationTitle(topicDetail?.title ?? "Topic")
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
        .task(id: topicId) {
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

            // Initial JSON posts (first ~20)
            let initialPosts = detail.postStream?.posts ?? []
            loadedPosts = initialPosts
            for post in initialPosts {
                loadedPostIds.insert(post.id)
            }

            // Initial raw markdown (first ~100 posts)
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
            // Find next batch of post IDs from stream that we haven't loaded
            let nextIds = stream.filter { !loadedPostIds.contains($0) }
            let batch = Array(nextIds.prefix(jsonChunkSize))

            guard !batch.isEmpty else {
                isLoadingMore = false
                return
            }

            // Fetch JSON metadata for next batch
            async let jsonResponse = apiClient.fetchTopicPosts(
                baseURL: baseURL, topicId: topicId, postIds: batch
            )

            // Also fetch next raw page if needed
            let needsMoreRaw: Bool = {
                guard !rawExhausted else { return false }
                // Check if any of the batch post IDs lack markdown
                // We fetch raw proactively when we're about to run out
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
            // Don't set error for pagination failures — just stop loading
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: avatar + username + date
            HStack(spacing: 8) {
                CachedAsyncImage(
                    url: URLHelpers.avatarURL(template: post.avatarTemplate, size: 90, baseURL: baseURL)
                ) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(post.name ?? post.username ?? "Unknown")
                            .font(.subheadline.bold())
                        if post.staff == true {
                            Image(systemName: "shield.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    HStack(spacing: 4) {
                        if let username = post.username {
                            Text("@\(username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("·")
                            .foregroundStyle(.secondary)
                        RelativeTimeText(dateString: post.createdAt)
                            .font(.caption)
                    }
                }
                Spacer()

                if let postNumber = post.postNumber {
                    Text("#\(postNumber)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Content — rendered from raw markdown, fallback to cooked HTML
            if let md = markdown {
                PostContentView(markdown: md, baseURL: baseURL)
            } else if let cooked = post.cooked, !cooked.isEmpty {
                Text(cooked)
                    .font(.body)
            }

            // Footer: likes + replies
            HStack(spacing: 16) {
                if post.likeCount > 0 {
                    Label("\(post.likeCount)", systemImage: "heart")
                }
                if let replies = post.replyCount, replies > 0 {
                    Label("\(replies)", systemImage: "arrowshape.turn.up.left")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
