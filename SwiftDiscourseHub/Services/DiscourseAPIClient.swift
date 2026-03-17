import Foundation
import SwiftUI
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "API")

// MARK: - Environment Key

private struct DiscourseAPIClientKey: EnvironmentKey {
    static let defaultValue: DiscourseAPIClient = DiscourseAPIClient()
}

extension EnvironmentValues {
    var apiClient: DiscourseAPIClient {
        get { self[DiscourseAPIClientKey.self] }
        set { self[DiscourseAPIClientKey.self] = newValue }
    }
}

enum DiscourseAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case loginRequired
    case httpError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
        case .loginRequired: return "This site requires login"
        case .httpError(let code, let message):
            if let message { return "HTTP error \(code): \(message)" }
            return "HTTP error \(code)"
        }
    }
}

actor DiscourseAPIClient {
    private let session: URLSession
    private let credentialProvider: AuthCredentialProvider?

    init(session: URLSession = .shared, credentialProvider: AuthCredentialProvider? = nil) {
        self.session = session
        self.credentialProvider = credentialProvider
    }

    private func extractErrors(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errors = json["errors"] as? [String] else { return nil }
        return errors.joined(separator: "; ")
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func addAuthHeaders(to request: inout URLRequest, baseURL: String?) async {
        guard let baseURL, let provider = credentialProvider else {
            log.debug("No auth: baseURL=\(baseURL ?? "nil"), provider=\(self.credentialProvider == nil ? "nil" : "set")")
            return
        }
        if let apiKey = await provider.apiKey(for: baseURL) {
            request.setValue(apiKey, forHTTPHeaderField: "User-Api-Key")
            log.debug("Set User-Api-Key header (\(apiKey.count) chars)")
        } else {
            log.warning("No API key found for \(baseURL)")
        }
        if let clientId = await provider.clientId(for: baseURL) {
            request.setValue(clientId, forHTTPHeaderField: "User-Api-Client-Id")
            log.debug("Set User-Api-Client-Id header: \(clientId.prefix(8))...")
        } else {
            log.warning("No client ID found for \(baseURL)")
        }
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL, baseURL: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

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
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
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
        return try await fetch(SiteBasicInfoResponse.self, from: url, baseURL: baseURL)
    }

    func fetchLatestTopics(baseURL: String, page: Int = 0) async throws -> TopicListResponse {
        let path = page > 0 ? "/latest.json?page=\(page)" : "/latest.json"
        let url = try buildURL(base: baseURL, path: path)
        return try await fetch(TopicListResponse.self, from: url, baseURL: baseURL)
    }

    func fetchHotTopics(baseURL: String) async throws -> TopicListResponse {
        let url = try buildURL(base: baseURL, path: "/hot.json")
        return try await fetch(TopicListResponse.self, from: url, baseURL: baseURL)
    }

    func fetchCategories(baseURL: String) async throws -> CategoryListResponse {
        let url = try buildURL(base: baseURL, path: "/categories.json")
        return try await fetch(CategoryListResponse.self, from: url, baseURL: baseURL)
    }

    func fetchCategoryTopics(baseURL: String, categorySlug: String, categoryId: Int, page: Int = 0) async throws -> TopicListResponse {
        let path = page > 0
            ? "/c/\(categorySlug)/\(categoryId)/l/latest.json?page=\(page)"
            : "/c/\(categorySlug)/\(categoryId)/l/latest.json"
        let url = try buildURL(base: baseURL, path: path)
        return try await fetch(TopicListResponse.self, from: url, baseURL: baseURL)
    }

    func fetchMoreTopics(baseURL: String, moreTopicsUrl: String) async throws -> TopicListResponse {
        guard let url = URL(string: moreTopicsUrl.hasPrefix("http") ? moreTopicsUrl : (baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL) + (moreTopicsUrl.hasPrefix("/") ? moreTopicsUrl : "/" + moreTopicsUrl)) else {
            throw DiscourseAPIError.invalidURL
        }
        return try await fetch(TopicListResponse.self, from: url, baseURL: baseURL)
    }

    func fetchTopic(baseURL: String, topicId: Int) async throws -> TopicDetailResponse {
        let url = try buildURL(base: baseURL, path: "/t/\(topicId).json")
        return try await fetch(TopicDetailResponse.self, from: url, baseURL: baseURL)
    }

    func fetchTopicPosts(baseURL: String, topicId: Int, postIds: [Int]) async throws -> TopicPostsResponse {
        guard !postIds.isEmpty else {
            return TopicPostsResponse(postStream: TopicPostsResponse.PostStreamSlice(posts: []))
        }
        let idsParam = postIds.map { "post_ids[]=\($0)" }.joined(separator: "&")
        let url = try buildURL(base: baseURL, path: "/t/\(topicId)/posts.json?\(idsParam)")
        return try await fetch(TopicPostsResponse.self, from: url, baseURL: baseURL)
    }

    func fetchTopicRaw(baseURL: String, topicId: Int, page: Int = 1) async throws -> String {
        let path = page > 1 ? "/raw/\(topicId)?page=\(page)" : "/raw/\(topicId)"
        let url = try buildURL(base: baseURL, path: path)
        return try await fetchText(from: url, baseURL: baseURL)
    }

    func fetchTopicRaw(baseURL: String, topicId: Int, postNumber: Int) async throws -> String {
        let url = try buildURL(base: baseURL, path: "/raw/\(topicId)/\(postNumber)")
        return try await fetchText(from: url, baseURL: baseURL)
    }

    func createPost(baseURL: String, topicId: Int, raw: String) async throws -> CreatePostResponse {
        let url = try buildURL(base: baseURL, path: "/posts.json")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        let body = CreatePostRequest(topicId: topicId, raw: raw)
        request.httpBody = try JSONEncoder().encode(body)

        log.info("POST \(url) for topic \(topicId)")
        log.debug("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let httpBody = request.httpBody, let bodyStr = String(data: httpBody, encoding: .utf8) {
            log.debug("Request body: \(bodyStr)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log.error("Network error: \(error)")
            throw DiscourseAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscourseAPIError.networkError(URLError(.badServerResponse))
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "<binary>"
        log.info("Response status: \(httpResponse.statusCode)")
        log.debug("Response headers: \(httpResponse.allHeaderFields)")
        log.debug("Response body: \(responseBody)")

        guard httpResponse.statusCode == 200 else {
            log.error("createPost failed: HTTP \(httpResponse.statusCode) — \(responseBody)")
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }

        do {
            return try makeDecoder().decode(CreatePostResponse.self, from: data)
        } catch {
            throw DiscourseAPIError.decodingError(error)
        }
    }

    func revokeApiKey(baseURL: String) async throws {
        let url = try buildURL(base: baseURL, path: "/user-api-key/revoke.json")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)
        _ = try await session.data(for: request)
    }

    func likePost(baseURL: String, postId: Int) async throws {
        let url = try buildURL(base: baseURL, path: "/post_actions.json")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        let body: [String: Any] = ["id": postId, "post_action_type_id": 2]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw DiscourseAPIError.httpError(code, extractErrors(from: data))
        }
    }

    func unlikePost(baseURL: String, postId: Int) async throws {
        let url = try buildURL(base: baseURL, path: "/post_actions/\(postId).json")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)
        request.httpBody = "post_action_type_id=2".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw DiscourseAPIError.httpError(code, extractErrors(from: data))
        }
    }

    // MARK: - Private

    private func fetchText(from url: URL, baseURL: String? = nil) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

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
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw DiscourseAPIError.decodingError(URLError(.cannotDecodeContentData))
        }

        return text
    }
}
