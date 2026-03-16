import SwiftUI

struct TopicDetailView: View {
    let topicId: Int
    let baseURL: String

    @State private var topicDetail: TopicDetailResponse?
    @State private var postMarkdown: [Int: String] = [:]
    @State private var isLoading = true
    @State private var error: String?

    private let apiClient = DiscourseAPIClient()

    private var topicURL: URL? {
        URLHelpers.resolveURL("/t/\(topicId)", baseURL: baseURL)
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
            } else if let detail = topicDetail, let posts = detail.postStream?.posts {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(posts) { post in
                            PostView(
                                post: post,
                                baseURL: baseURL,
                                markdown: postMarkdown[post.postNumber ?? 0]
                            )
                            Divider()
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

    private func loadTopic() async {
        isLoading = true
        error = nil
        do {
            async let jsonResponse = apiClient.fetchTopic(baseURL: baseURL, topicId: topicId)
            async let rawResponse = apiClient.fetchTopicRaw(baseURL: baseURL, topicId: topicId)

            let detail = try await jsonResponse
            topicDetail = detail

            // Parse raw markdown and resolve uploads
            let rawText = try await rawResponse
            let rawPosts = RawTopicParser.parse(rawText)

            let preprocessor = DiscourseMarkdownPreprocessor(baseURL: baseURL)

            // Collect all upload:// URLs across all posts
            var allUploadURLs: [String] = []
            for rawPost in rawPosts {
                allUploadURLs.append(contentsOf: DiscourseMarkdownPreprocessor.extractUploadShortURLs(from: rawPost.markdown))
            }
            let uniqueUploadURLs = Array(Set(allUploadURLs))

            // Batch-resolve uploads
            let uploadMapping = try? await apiClient.lookupUploadURLs(baseURL: baseURL, shortURLs: uniqueUploadURLs)

            // Build post number -> processed markdown mapping
            var markdownMap: [Int: String] = [:]
            for rawPost in rawPosts {
                var md = rawPost.markdown
                if let mapping = uploadMapping, !mapping.isEmpty {
                    md = DiscourseMarkdownPreprocessor.replaceUploadURLs(in: md, mapping: mapping)
                }
                md = preprocessor.process(md)
                markdownMap[rawPost.postNumber] = md
            }
            postMarkdown = markdownMap
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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
