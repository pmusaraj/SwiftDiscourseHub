import Foundation

enum DiscourseAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case loginRequired
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
        case .loginRequired: return "This site requires login"
        case .httpError(let code): return "HTTP error \(code)"
        }
    }
}

actor DiscourseAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DiscourseAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscourseAPIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 403 {
                throw DiscourseAPIError.loginRequired
            }
            throw DiscourseAPIError.httpError(httpResponse.statusCode)
        }

        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            throw DiscourseAPIError.decodingError(error)
        }
    }

    private func buildURL(base: String, path: String) throws -> URL {
        let baseStr = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let url = URL(string: baseStr + path) else {
            throw DiscourseAPIError.invalidURL
        }
        return url
    }

    // MARK: - Public API

    func fetchBasicInfo(baseURL: String) async throws -> SiteBasicInfoResponse {
        let url = try buildURL(base: baseURL, path: "/site/basic-info.json")
        return try await fetch(SiteBasicInfoResponse.self, from: url)
    }

    func fetchLatestTopics(baseURL: String, page: Int = 0) async throws -> TopicListResponse {
        let path = page > 0 ? "/latest.json?page=\(page)" : "/latest.json"
        let url = try buildURL(base: baseURL, path: path)
        return try await fetch(TopicListResponse.self, from: url)
    }

    func fetchHotTopics(baseURL: String) async throws -> TopicListResponse {
        let url = try buildURL(base: baseURL, path: "/hot.json")
        return try await fetch(TopicListResponse.self, from: url)
    }

    func fetchCategories(baseURL: String) async throws -> CategoryListResponse {
        let url = try buildURL(base: baseURL, path: "/categories.json")
        return try await fetch(CategoryListResponse.self, from: url)
    }

    func fetchCategoryTopics(baseURL: String, categorySlug: String, categoryId: Int, page: Int = 0) async throws -> TopicListResponse {
        let path = page > 0
            ? "/c/\(categorySlug)/\(categoryId)/l/latest.json?page=\(page)"
            : "/c/\(categorySlug)/\(categoryId)/l/latest.json"
        let url = try buildURL(base: baseURL, path: path)
        return try await fetch(TopicListResponse.self, from: url)
    }

    func fetchMoreTopics(baseURL: String, moreTopicsUrl: String) async throws -> TopicListResponse {
        guard let url = URL(string: moreTopicsUrl.hasPrefix("http") ? moreTopicsUrl : (baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL) + (moreTopicsUrl.hasPrefix("/") ? moreTopicsUrl : "/" + moreTopicsUrl)) else {
            throw DiscourseAPIError.invalidURL
        }
        return try await fetch(TopicListResponse.self, from: url)
    }

    func fetchTopic(baseURL: String, topicId: Int) async throws -> TopicDetailResponse {
        let url = try buildURL(base: baseURL, path: "/t/\(topicId).json")
        return try await fetch(TopicDetailResponse.self, from: url)
    }

    func fetchTopicPosts(baseURL: String, topicId: Int, postIds: [Int]) async throws -> TopicPostsResponse {
        guard !postIds.isEmpty else {
            return TopicPostsResponse(postStream: TopicPostsResponse.PostStreamSlice(posts: []))
        }
        let idsParam = postIds.map { "post_ids[]=\($0)" }.joined(separator: "&")
        let url = try buildURL(base: baseURL, path: "/t/\(topicId)/posts.json?\(idsParam)")
        return try await fetch(TopicPostsResponse.self, from: url)
    }

    func fetchTopicRaw(baseURL: String, topicId: Int, page: Int = 1) async throws -> String {
        let path = page > 1 ? "/raw/\(topicId)?page=\(page)" : "/raw/\(topicId)"
        let url = try buildURL(base: baseURL, path: path)
        return try await fetchText(from: url)
    }

    // MARK: - Private

    private func fetchText(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DiscourseAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscourseAPIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw DiscourseAPIError.decodingError(URLError(.cannotDecodeContentData))
        }

        return text
    }
}
