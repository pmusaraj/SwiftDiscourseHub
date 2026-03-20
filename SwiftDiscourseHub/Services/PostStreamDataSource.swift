import SwiftUI
import Nuke
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "PostStream")

/// Signal-inspired windowed data source for bidirectional post stream loading.
/// Maintains a sliding window of up to `maxWindowSize` posts, trimming from
/// the opposite end when loading in one direction pushes past the cap.
@Observable
@MainActor
final class PostStreamDataSource {

    // MARK: - Configuration

    static let maxWindowSize = 400
    private let loadChunkSize = 20
    private let rawPageSize = 100
    /// Number of posts from the window edge that triggers pre-loading.
    static let prefetchThreshold = 10

    // MARK: - Public State

    private(set) var items: [StreamItem] = []
    private(set) var isLoadingNewer = false
    private(set) var isLoadingOlder = false
    private(set) var canLoadOlder = false
    private(set) var canLoadNewer = false
    var postMarkdown: [Int: String] = [:]
    var avatarLookup: [String: String] = [:]
    var topicDetail: TopicDetailResponse?

    // MARK: - Stream Metadata

    /// Full ordered list of post IDs for the topic (from the API's post_stream.stream).
    private(set) var stream: [Int] = []
    /// Set of post IDs currently in the window.
    private(set) var loadedPostIds: Set<Int> = []
    /// Index into `stream` of the first post in the window.
    private var windowStart: Int = 0
    /// Index into `stream` one past the last post in the window (exclusive).
    private var windowEnd: Int = 0
    /// Raw markdown pages already fetched.
    private var loadedRawPages: Set<Int> = []

    // MARK: - Dependencies

    private var apiClient: DiscourseAPIClient!
    private var baseURL: String = ""
    private var topicId: Int = 0
    private let prefetcher = ImagePrefetcher(destination: .diskCache)

    // MARK: - Computed

    var hasMore: Bool { loadedPostIds.count < stream.count }

    /// Returns the index of a post within the items array (posts only, ignoring placeholders).
    func postIndex(of postId: Int) -> Int? {
        var idx = 0
        for item in items {
            if case .post(let p) = item {
                if p.id == postId { return idx }
                idx += 1
            }
        }
        return nil
    }

    /// Number of post items (not placeholders) in the window.
    var postCount: Int {
        items.count(where: { if case .post = $0 { return true }; return false })
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
        avatarLookup = [:]
        windowStart = 0
        windowEnd = 0
        canLoadOlder = false
        canLoadNewer = false
        loadedRawPages = []
        topicDetail = nil
    }

    // MARK: - Initial Load

    func loadInitial() async throws {
        reset()
        log.info("[loadInitial] topic=\(self.topicId)")

        async let jsonResponse = apiClient.fetchTopic(baseURL: baseURL, topicId: topicId)
        async let rawResponse = apiClient.fetchTopicRaw(baseURL: baseURL, topicId: topicId, page: 1)

        let detail = try await jsonResponse
        topicDetail = detail
        stream = detail.postStream?.stream ?? []

        let initialPosts = detail.postStream?.posts ?? []
        registerPosts(initialPosts)
        items = initialPosts.map { .post($0) }

        windowStart = 0
        windowEnd = min(initialPosts.count, stream.count)
        canLoadOlder = false
        canLoadNewer = windowEnd < stream.count

        let rawText = try await rawResponse
        processRawText(rawText)
        loadedRawPages.insert(1)
    }

    // MARK: - Load Newer (downward / appending)

    func loadNewer() async {
        guard canLoadNewer, !isLoadingNewer else { return }
        isLoadingNewer = true
        defer { isLoadingNewer = false }

        do {
            let nextIds = stream[windowEnd...]
                .filter { !loadedPostIds.contains($0) }
            let batch = Array(nextIds.prefix(loadChunkSize))
            guard !batch.isEmpty else {
                canLoadNewer = false
                return
            }
            log.info("[loadNewer] fetching \(batch.count) posts, window=[\(self.windowStart)..\(self.windowEnd)]/\(self.stream.count)")

            let posts = try await fetchPostsWithRaw(ids: batch)
            let filtered = posts.filter { !loadedPostIds.contains($0.id) }
            registerPosts(filtered)
            items.append(contentsOf: filtered.map { .post($0) })

            if let lastId = filtered.last?.id, let idx = stream.firstIndex(of: lastId) {
                windowEnd = idx + 1
            }
            canLoadNewer = windowEnd < stream.count
            log.info("[loadNewer] done, \(filtered.count) added, window=[\(self.windowStart)..\(self.windowEnd)]")

            trimOlder()
        } catch {
            log.error("[loadNewer] error: \(error.localizedDescription)")
        }
    }

    // MARK: - Load Older (upward / prepending)
    // Prepends older posts. The caller must handle scroll position restoration.

    func loadOlder() async {
        guard canLoadOlder, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let olderIds = stream[0..<windowStart]
                .filter { !loadedPostIds.contains($0) }
            let batch = Array(olderIds.suffix(loadChunkSize))
            guard !batch.isEmpty else {
                canLoadOlder = false
                return
            }
            log.info("[loadOlder] fetching \(batch.count) posts, window=[\(self.windowStart)..\(self.windowEnd)]/\(self.stream.count)")

            let posts = try await fetchPostsWithRaw(ids: batch)
            let filtered = posts
                .filter { !loadedPostIds.contains($0.id) }
                .sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }
            registerPosts(filtered)

            let newItems = filtered.map { StreamItem.post($0) }
            items.insert(contentsOf: newItems, at: 0)

            if let firstId = filtered.first?.id, let idx = stream.firstIndex(of: firstId) {
                windowStart = idx
            }
            canLoadOlder = windowStart > 0
            log.info("[loadOlder] done, \(filtered.count) prepended, window=[\(self.windowStart)..\(self.windowEnd)]")

            trimNewer()
        } catch {
            log.error("[loadOlder] error: \(error.localizedDescription)")
        }
    }

    // MARK: - Jump to Post
    // Returns the post ID to scroll to, or nil on failure.

    func jumpToPost(number targetPostNumber: Int) async -> Int? {
        // If already in window, just return the ID
        if let item = items.first(where: {
            if case .post(let p) = $0 { return p.postNumber == targetPostNumber }
            return false
        }), case .post(let post) = item {
            return post.id
        }

        do {
            let estimatedIdx = min(max(targetPostNumber - 1, 0), stream.count - 1)
            let startIdx = max(0, estimatedIdx - 10)
            let endIdx = min(stream.count, estimatedIdx + 11)
            let idsToFetch = Array(stream[startIdx..<endIdx])
                .filter { !loadedPostIds.contains($0) }

            guard !idsToFetch.isEmpty else { return nil }

            let posts = try await fetchPostsWithRaw(ids: idsToFetch)
            let sorted = posts.sorted { ($0.postNumber ?? 0) < ($1.postNumber ?? 0) }
            registerPosts(sorted)

            // Rebuild window centered on target — no placeholders
            items = sorted.map { .post($0) }
            windowStart = startIdx
            windowEnd = endIdx
            canLoadOlder = windowStart > 0
            canLoadNewer = windowEnd < stream.count

            return sorted.first(where: { $0.postNumber == targetPostNumber })?.id
                ?? sorted.min(by: {
                    abs(($0.postNumber ?? 0) - targetPostNumber) < abs(($1.postNumber ?? 0) - targetPostNumber)
                })?.id
        } catch {
            return nil
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
        canLoadNewer = false

        // Fetch raw markdown for the last new post
        if let lastPost = newPosts.last, let pn = lastPost.postNumber {
            let rawText = try await apiClient.fetchTopicRaw(
                baseURL: baseURL, topicId: topicId, postNumber: pn
            )
            let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
            postMarkdown[pn] = preprocessor.process(rawText)
        }

        if case .post(let last) = items.last {
            return last.id
        }
        return nil
    }

    // MARK: - Trimming

    private func trimOlder() {
        let count = postCount
        guard count > Self.maxWindowSize else { return }

        let excess = count - Self.maxWindowSize
        var removed = 0
        while removed < excess, !items.isEmpty {
            if case .post(let p) = items.first {
                loadedPostIds.remove(p.id)
                if let idx = stream.firstIndex(of: p.id) {
                    windowStart = idx + 1
                }
                items.removeFirst()
                removed += 1
            } else {
                items.removeFirst()
            }
        }
        canLoadOlder = windowStart > 0
    }

    private func trimNewer() {
        let count = postCount
        guard count > Self.maxWindowSize else { return }

        let excess = count - Self.maxWindowSize
        var removed = 0
        while removed < excess, !items.isEmpty {
            if case .post(let p) = items.last {
                loadedPostIds.remove(p.id)
                if let idx = stream.firstIndex(of: p.id) {
                    windowEnd = idx
                }
                items.removeLast()
                removed += 1
            } else {
                items.removeLast()
            }
        }
        canLoadNewer = windowEnd < stream.count
    }

    // MARK: - Raw + JSON Fetching

    private func fetchPostsWithRaw(ids: [Int]) async throws -> [Post] {
        log.info("[fetch] POST /t/\(self.topicId)/posts.json post_ids=\(ids)")

        // Start JSON fetch
        async let postsResponse = apiClient.fetchTopicPosts(
            baseURL: baseURL, topicId: topicId, postIds: ids
        )

        // Figure out which raw pages we need (estimate post numbers from stream indices)
        let neededPages: Set<Int> = Set(ids.compactMap { id in
            guard let idx = stream.firstIndex(of: id) else { return nil }
            let estimatedPostNumber = idx + 1
            return (estimatedPostNumber - 1) / rawPageSize + 1
        })
        let pagesToFetch = neededPages.subtracting(loadedRawPages)

        if !pagesToFetch.isEmpty {
            log.info("[fetch] raw pages needed=\(pagesToFetch.sorted()), already loaded=\(self.loadedRawPages.sorted())")
        }

        // Fetch raw pages in parallel
        let tid = topicId
        await withTaskGroup(of: (Int, String?).self) { group in
            for page in pagesToFetch {
                group.addTask {
                    log.info("[fetch] GET /raw/\(tid)?page=\(page)")
                    let text = try? await self.apiClient.fetchTopicRaw(
                        baseURL: self.baseURL, topicId: self.topicId, page: page
                    )
                    return (page, text)
                }
            }
            for await (page, text) in group {
                if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    loadedRawPages.insert(page)
                    processRawText(text)
                    log.info("[fetch] raw page \(page) processed")
                }
            }
        }

        let posts = try await postsResponse.postStream.posts
        log.info("[fetch] got \(posts.count) posts from JSON")
        return posts
    }

    // MARK: - Helpers

    func registerPosts(_ posts: [Post]) {
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

    func processRawText(_ rawText: String) {
        let rawPosts = RawTopicParser.parse(rawText)
        let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)
        var imageURLs: [URL] = []
        for rawPost in rawPosts {
            let processed = preprocessor.process(rawPost.markdown)
            postMarkdown[rawPost.postNumber] = processed
            imageURLs.append(contentsOf: extractImageURLs(from: processed))
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
}
