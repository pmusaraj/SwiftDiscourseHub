import SwiftUI
import Nuke
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "PostStream")

/// Data source for the post stream. Loads posts via the topic JSON endpoint
/// and manages a window of loaded posts with bidirectional progressive loading.
@Observable
@MainActor
final class PostStreamDataSource {

    // MARK: - Configuration

    private let rawPageSize = 100
    static let loadChunkSize = 20

    // MARK: - Public State

    private(set) var items: [StreamItem] = []
    var postMarkdown: [Int: String] = [:]
    var postOneboxes: [Int: [DiscourseMarkdownPreprocessor.OneboxInfo]] = [:]
    var postCooked: [Int: String] = [:]
    var avatarLookup: [String: String] = [:]
    var topicDetail: TopicDetailResponse?
    private(set) var isLoadingOlder = false
    private(set) var isLoadingNewer = false

    // MARK: - Stream Metadata

    /// Full ordered list of post IDs for the topic (from the API's post_stream.stream).
    private(set) var stream: [Int] = []
    /// Set of post IDs currently in the window.
    private(set) var loadedPostIds: Set<Int> = []
    /// Index into `stream` of the first post in the window.
    private(set) var windowStart: Int = 0
    /// Index into `stream` one past the last post in the window (exclusive).
    private(set) var windowEnd: Int = 0
    /// Raw markdown pages already fetched.
    private var loadedRawPages: Set<Int> = []

    // MARK: - Dependencies

    private var apiClient: DiscourseAPIClient!
    private var baseURL: String = ""
    private var topicId: Int = 0
    private let prefetcher = ImagePrefetcher(destination: .diskCache)

    // MARK: - Computed

    var hasMore: Bool { loadedPostIds.count < stream.count }
    var canLoadOlder: Bool { windowStart > 0 }
    var canLoadNewer: Bool { windowEnd < stream.count }

    /// Number of post items (not placeholders) in the window.
    var postCount: Int {
        items.count(where: { if case .post = $0 { return true }; return false })
    }

    /// Highest post number among loaded posts.
    var highestLoadedPostNumber: Int {
        items.compactMap { if case .post(let p) = $0 { return p.postNumber }; return nil }.max() ?? 0
    }

    // MARK: - Setup

    func configure(apiClient: DiscourseAPIClient, baseURL: String, topicId: Int) {
        self.apiClient = apiClient
        self.baseURL = baseURL
        self.topicId = topicId
    }

    func reset() {
        items = []
        stream = []
        loadedPostIds = []
        postMarkdown = [:]
        postCooked = [:]
        avatarLookup = [:]
        windowStart = 0
        windowEnd = 0
        loadedRawPages = []
        topicDetail = nil
        isLoadingOlder = false
        isLoadingNewer = false
    }

    // MARK: - Initial Load

    /// Loads the topic from the beginning (post #1).
    func loadInitial() async throws {
        try await loadInitial(nearPost: nil)
    }

    /// Loads the topic near a specific post number.
    /// If `nearPost` is nil or 1, loads from the beginning.
    /// Returns the post ID to scroll to, if a specific post was requested.
    @discardableResult
    func loadInitial(nearPost postNumber: Int?) async throws -> Int? {
        reset()

        let useNear = postNumber != nil && postNumber! > 1

        if useNear {
            log.info("[loadInitial] topic=\(self.topicId) near=#\(postNumber!)")
        } else {
            log.info("[loadInitial] topic=\(self.topicId)")
        }

        // Fetch topic JSON and raw markdown concurrently
        let rawPage = useNear ? max(1, (postNumber! - 1) / rawPageSize + 1) : 1
        let client = apiClient!
        let bURL = baseURL
        let tId = topicId
        let nearPN = postNumber

        async let detailTask: TopicDetailResponse = {
            if useNear {
                return try await client.fetchTopic(baseURL: bURL, topicId: tId, nearPost: nearPN!)
            } else {
                return try await client.fetchTopic(baseURL: bURL, topicId: tId)
            }
        }()

        async let rawTask: String? = {
            try? await client.fetchTopicRaw(baseURL: bURL, topicId: tId, page: rawPage)
        }()

        let detail = try await detailTask
        let rawText = await rawTask

        topicDetail = detail
        stream = detail.postStream?.stream ?? []

        // Process raw markdown before setting items so the first render has content
        if let rawText {
            loadedRawPages.insert(rawPage)
            processRawText(rawText)
        }

        let posts = detail.postStream?.posts ?? []
        let sorted = posts.sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }
        registerPosts(sorted)
        items = sorted.map { .post($0) }

        // Determine window bounds from the stream
        let returnedIds = Set(sorted.map(\.id))
        let firstStreamIdx = stream.firstIndex(where: { returnedIds.contains($0) }) ?? 0
        let lastStreamIdx = stream.lastIndex(where: { returnedIds.contains($0) }).map({ $0 + 1 }) ?? stream.count

        windowStart = firstStreamIdx
        windowEnd = lastStreamIdx

        if useNear {
            return sorted.first(where: { $0.postNumber == postNumber })?.id
                ?? sorted.last?.id
        }
        return nil
    }

    // MARK: - Jump to Post

    /// Replaces the current window with posts around the target post number.
    /// Uses `/t/{id}.json?post_number=N` which returns ~20 posts near the target
    /// in a single request (Discourse's `filter_posts_near`).
    func jumpToPost(number targetPostNumber: Int) async -> Int? {
        // If already in window, just return the ID
        if let item = items.first(where: {
            if case .post(let p) = $0 { return p.postNumber == targetPostNumber }
            return false
        }), case .post(let post) = item {
            return post.id
        }

        do {
            log.info("[jumpToPost] target=#\(targetPostNumber), fetching via /t/\(self.topicId).json?post_number=\(targetPostNumber)")

            // Fetch topic JSON and raw markdown concurrently
            let targetPage = max(1, (targetPostNumber - 1) / rawPageSize + 1)

            let alreadyLoaded = loadedRawPages.contains(targetPage)
            let client = apiClient!
            let bURL = baseURL
            let tId = topicId

            async let detailTask = client.fetchTopic(baseURL: bURL, topicId: tId, nearPost: targetPostNumber)
            async let rawTask: String? = {
                if alreadyLoaded { return nil }
                return try? await client.fetchTopicRaw(baseURL: bURL, topicId: tId, page: targetPage)
            }()

            let detail = try await detailTask
            let rawText = await rawTask

            topicDetail = detail
            stream = detail.postStream?.stream ?? []

            // Process raw markdown before setting items
            if let rawText {
                loadedRawPages.insert(targetPage)
                processRawText(rawText)
            }

            let posts = detail.postStream?.posts ?? []
            let sorted = posts.sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }

            guard !sorted.isEmpty else { return nil }

            let returnedIds = Set(sorted.map(\.id))
            let firstStreamIdx = stream.firstIndex(where: { returnedIds.contains($0) }) ?? 0
            let lastStreamIdx = stream.lastIndex(where: { returnedIds.contains($0) }).map({ $0 + 1 }) ?? stream.count

            // Replace the entire window
            loadedPostIds.removeAll()
            loadedRawPages.removeAll()
            if let rawText { loadedRawPages.insert(targetPage) }
            registerPosts(sorted)
            items = sorted.map { .post($0) }

            windowStart = firstStreamIdx
            windowEnd = lastStreamIdx

            log.info("[jumpToPost] window=[\(self.windowStart)..\(self.windowEnd)], items=\(self.items.count)")

            return sorted.first(where: { $0.postNumber == targetPostNumber })?.id
                ?? sorted.last?.id
        } catch {
            log.error("[jumpToPost] error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Progressive Loading

    /// Loads older posts (prepend) from the stream before the current window.
    func loadOlder() async {
        guard canLoadOlder, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        let chunkSize = Self.loadChunkSize
        let newStart = max(0, windowStart - chunkSize)
        let postIds = Array(stream[newStart..<windowStart])
        guard !postIds.isEmpty else { return }

        log.info("[loadOlder] fetching \(postIds.count) posts, stream[\(newStart)..\(self.windowStart)]")

        do {
            // Fetch posts and raw markdown concurrently
            let client = apiClient!
            let bURL = baseURL
            let tId = topicId

            // Determine which raw pages we need for these posts
            // Post numbers aren't known yet, but we can estimate from stream position
            let estimatedFirstPostNum = newStart + 1
            let neededPage = max(1, (estimatedFirstPostNum - 1) / rawPageSize + 1)
            let needsRaw = !loadedRawPages.contains(neededPage)

            async let postsTask = client.fetchTopicPosts(baseURL: bURL, topicId: tId, postIds: postIds)
            async let rawTask: String? = {
                guard needsRaw else { return nil }
                return try? await client.fetchTopicRaw(baseURL: bURL, topicId: tId, page: neededPage)
            }()

            let response = try await postsTask
            let rawText = await rawTask

            // Process raw markdown before updating items
            if let rawText {
                loadedRawPages.insert(neededPage)
                processRawText(rawText)
            }

            let newPosts = response.postStream.posts
                .filter { !loadedPostIds.contains($0.id) }
                .sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }

            guard !newPosts.isEmpty else { return }

            registerPosts(newPosts)
            items.insert(contentsOf: newPosts.map { .post($0) }, at: 0)
            windowStart = newStart

            log.info("[loadOlder] prepended \(newPosts.count) posts, window=[\(self.windowStart)..\(self.windowEnd)]")
        } catch {
            log.error("[loadOlder] error: \(error.localizedDescription)")
        }
    }

    /// Loads newer posts (append) from the stream after the current window.
    func loadNewer() async {
        guard canLoadNewer, !isLoadingNewer else { return }
        isLoadingNewer = true
        defer { isLoadingNewer = false }

        let chunkSize = Self.loadChunkSize
        let newEnd = min(stream.count, windowEnd + chunkSize)
        let postIds = Array(stream[windowEnd..<newEnd])
        guard !postIds.isEmpty else { return }

        log.info("[loadNewer] fetching \(postIds.count) posts, stream[\(self.windowEnd)..\(newEnd)]")

        do {
            let client = apiClient!
            let bURL = baseURL
            let tId = topicId

            // Estimate post numbers for raw page calculation
            let estimatedLastPostNum = newEnd
            let neededPage = max(1, (estimatedLastPostNum - 1) / rawPageSize + 1)
            let needsRaw = !loadedRawPages.contains(neededPage)

            async let postsTask = client.fetchTopicPosts(baseURL: bURL, topicId: tId, postIds: postIds)
            async let rawTask: String? = {
                guard needsRaw else { return nil }
                return try? await client.fetchTopicRaw(baseURL: bURL, topicId: tId, page: neededPage)
            }()

            let response = try await postsTask
            let rawText = await rawTask

            if let rawText {
                loadedRawPages.insert(neededPage)
                processRawText(rawText)
            }

            let newPosts = response.postStream.posts
                .filter { !loadedPostIds.contains($0.id) }
                .sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }

            guard !newPosts.isEmpty else { return }

            registerPosts(newPosts)
            items.append(contentsOf: newPosts.map { .post($0) })
            windowEnd = newEnd

            log.info("[loadNewer] appended \(newPosts.count) posts, window=[\(self.windowStart)..\(self.windowEnd)]")
        } catch {
            log.error("[loadNewer] error: \(error.localizedDescription)")
        }
    }

    // MARK: - Append After Posting

    func refreshAfterPost() async throws -> Int? {
        let detail = try await apiClient.fetchTopic(baseURL: baseURL, topicId: topicId)
        topicDetail = detail
        stream = detail.postStream?.stream ?? []

        let missingIds = stream.filter { !loadedPostIds.contains($0) }
        guard !missingIds.isEmpty else { return nil }

        let response = try await apiClient.fetchTopicPosts(
            baseURL: baseURL, topicId: topicId, postIds: missingIds
        )
        let newPosts = response.postStream.posts.filter { !loadedPostIds.contains($0.id) }
        registerPosts(newPosts)
        items.append(contentsOf: newPosts.map { .post($0) })
        windowEnd = stream.count

        // Fetch raw markdown for the last new post
        if let lastPost = newPosts.last, let pn = lastPost.postNumber {
            let rawText = try await apiClient.fetchTopicRaw(
                baseURL: baseURL, topicId: topicId, postNumber: pn
            )
            let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
            let processed = preprocessor.processWithOneboxes(rawText, cooked: lastPost.cooked)
            postMarkdown[pn] = processed.markdown
            if !processed.oneboxes.isEmpty { postOneboxes[pn] = processed.oneboxes }
        }

        if case .post(let last) = items.last {
            return last.id
        }
        return nil
    }

    // MARK: - Helpers

    func registerPosts(_ posts: [Post]) {
        var urls: [URL] = []
        for post in posts {
            loadedPostIds.insert(post.id)
            if let pn = post.postNumber, let cooked = post.cooked {
                postCooked[pn] = cooked
            }
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

    func processRawText(_ rawText: String) {
        let rawPosts = RawTopicParser.parse(rawText)
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
        var imageURLs: [URL] = []
        for rawPost in rawPosts {
            let cooked = postCooked[rawPost.postNumber]
            let processed = preprocessor.processWithOneboxes(rawPost.markdown, cooked: cooked)
            postMarkdown[rawPost.postNumber] = processed.markdown
            if !processed.oneboxes.isEmpty { postOneboxes[rawPost.postNumber] = processed.oneboxes }
            imageURLs.append(contentsOf: extractImageURLs(from: processed.markdown))
        }
        if !imageURLs.isEmpty {
            prefetcher.startPrefetching(with: imageURLs)
        }
    }

    private func extractImageURLs(from markdown: String) -> [URL] {
        guard let regex = try? NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#) else { return [] }
        let range = NSRange(markdown.startIndex..., in: markdown)
        return regex.matches(in: markdown, range: range).compactMap { match in
            guard let urlRange = Range(match.range(at: 1), in: markdown) else { return nil }
            var urlString = String(markdown[urlRange])
            if let fragmentIdx = urlString.firstIndex(of: "#") {
                urlString = String(urlString[..<fragmentIdx])
            }
            if urlString.hasPrefix("http") {
                return URL(string: urlString)
            }
            return URL(string: urlString, relativeTo: URL(string: baseURL))?.absoluteURL
        }
    }

    func stopPrefetching() {
        prefetcher.stopPrefetching()
    }

    // MARK: - Read Tracking

    /// Sends read timings for all loaded posts to mark them as read.
    /// Uses a minimal timing value (1000ms per post) — just enough for Discourse to register.
    /// Call once when leaving a topic to avoid excessive API calls.
    func sendTimings() async {
        guard apiClient != nil, topicId > 0 else { return }

        var timings: [Int: Int] = [:]
        for item in items {
            if case .post(let post) = item, let pn = post.postNumber {
                timings[pn] = 1000
            }
        }
        guard !timings.isEmpty else { return }

        let topicTime = min(timings.count * 1000, 60000)
        do {
            try await apiClient.postTimings(
                baseURL: baseURL,
                topicId: topicId,
                topicTime: topicTime,
                timings: timings
            )
            log.debug("Sent timings for \(timings.count) posts in topic \(self.topicId)")
        } catch {
            log.error("Failed to send timings: \(error.localizedDescription)")
        }
    }

    // MARK: - Test Helpers

    func configureForTesting(
        stream: [Int],
        posts: [Post],
        windowStart: Int,
        windowEnd: Int
    ) {
        self.stream = stream
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.items = posts.map { .post($0) }
        self.loadedPostIds = Set(posts.map(\.id))
    }

    @discardableResult
    func simulateJumpToPost(number targetPostNumber: Int, fetchedPosts: [Post]) -> Int? {
        if let item = items.first(where: {
            if case .post(let p) = $0 { return p.postNumber == targetPostNumber }
            return false
        }), case .post(let post) = item {
            return post.id
        }

        let estimatedIdx = min(max(targetPostNumber - 1, 0), stream.count - 1)
        let endIdx = min(stream.count, estimatedIdx + 1)
        let startIdx = max(0, endIdx - 20)

        let sorted = fetchedPosts.sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }

        loadedPostIds.removeAll()
        registerPosts(sorted)
        items = sorted.map { .post($0) }

        windowStart = startIdx
        windowEnd = endIdx

        return sorted.first(where: { $0.postNumber == targetPostNumber })?.id
            ?? sorted.last?.id
    }
}
