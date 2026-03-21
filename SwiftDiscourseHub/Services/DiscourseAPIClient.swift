import Foundation
import SwiftUI
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "API")

/// Toggle network request logging to the console. Set to `false` to silence all request/response logs.
nonisolated(unsafe) var enableNetworkLogging = true

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

    // MARK: - Logging

    private func timestamp() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }

    private func logRequest(_ method: String, _ url: URL) {
        guard enableNetworkLogging else { return }
        log.info("[request] [\(self.timestamp())] \(method) \(url.absoluteString)")
    }

    private func logResponse(_ statusCode: Int, _ url: URL, duration: TimeInterval) {
        guard enableNetworkLogging else { return }
        let ms = Int(duration * 1000)
        log.info("[response] [\(self.timestamp())] \(statusCode) \(url.absoluteString) (\(ms)ms)")
    }

    private func logError(_ method: String, _ url: URL, error: String) {
        guard enableNetworkLogging else { return }
        log.error("[error] [\(self.timestamp())] \(method) \(url.absoluteString) — \(error)")
    }

    // MARK: - Core Request Methods

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
        guard let baseURL, let provider = credentialProvider else { return }
        if let apiKey = await provider.apiKey(for: baseURL) {
            request.setValue(apiKey, forHTTPHeaderField: "User-Api-Key")
        }
    }

    private func fetch<T: Decodable>(_ type: T.Type, from url: URL, baseURL: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        logRequest("GET", url)
        let start = CFAbsoluteTimeGetCurrent()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logError("GET", url, error: error.localizedDescription)
            throw DiscourseAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscourseAPIError.networkError(URLError(.badServerResponse))
        }

        logResponse(httpResponse.statusCode, url, duration: CFAbsoluteTimeGetCurrent() - start)

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

    private func fetchText(from url: URL, baseURL: String? = nil) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        logRequest("GET", url)
        let start = CFAbsoluteTimeGetCurrent()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logError("GET", url, error: error.localizedDescription)
            throw DiscourseAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscourseAPIError.networkError(URLError(.badServerResponse))
        }

        logResponse(httpResponse.statusCode, url, duration: CFAbsoluteTimeGetCurrent() - start)

        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw DiscourseAPIError.decodingError(URLError(.cannotDecodeContentData))
        }

        return text
    }

    /// Performs a non-GET request (POST/PUT/DELETE) with logging.
    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url!

        logRequest(method, url)
        let start = CFAbsoluteTimeGetCurrent()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logError(method, url, error: error.localizedDescription)
            throw DiscourseAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiscourseAPIError.networkError(URLError(.badServerResponse))
        }

        logResponse(httpResponse.statusCode, url, duration: CFAbsoluteTimeGetCurrent() - start)

        return (data, httpResponse)
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

    func fetchNewTopics(baseURL: String, page: Int = 0) async throws -> TopicListResponse {
        let path = page > 0 ? "/new.json?page=\(page)" : "/new.json"
        let url = try buildURL(base: baseURL, path: path)
        return try await fetch(TopicListResponse.self, from: url, baseURL: baseURL)
    }

    func fetchCategories(baseURL: String) async throws -> CategoryListResponse {
        let url = try buildURL(base: baseURL, path: "/categories.json?include_subcategories=true")
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

    func fetchCurrentUser(baseURL: String) async throws -> CurrentUserResponse.CurrentUser {
        let url = try buildURL(base: baseURL, path: "/session/current.json")
        let response = try await fetch(CurrentUserResponse.self, from: url, baseURL: baseURL)
        return response.currentUser
    }

    func fetchTopic(baseURL: String, topicId: Int) async throws -> TopicDetailResponse {
        let url = try buildURL(base: baseURL, path: "/t/\(topicId).json")
        return try await fetch(TopicDetailResponse.self, from: url, baseURL: baseURL)
    }

    func fetchTopic(baseURL: String, topicId: Int, nearPost postNumber: Int) async throws -> TopicDetailResponse {
        let url = try buildURL(base: baseURL, path: "/t/\(topicId).json?post_number=\(postNumber)")
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

        let (data, httpResponse) = try await performRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }

        do {
            return try makeDecoder().decode(CreatePostResponse.self, from: data)
        } catch {
            throw DiscourseAPIError.decodingError(error)
        }
    }

    func uploadFile(baseURL: String, data fileData: Data, fileName: String, mimeType: String) async throws -> UploadResponse {
        let url = try buildURL(base: baseURL, path: "/uploads.json")
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"type\"\r\n\r\ncomposer\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"synchronous\"\r\n\r\ntrue\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\nContent-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, httpResponse) = try await performRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }

        do {
            return try makeDecoder().decode(UploadResponse.self, from: data)
        } catch {
            throw DiscourseAPIError.decodingError(error)
        }
    }

    func searchUsers(baseURL: String, term: String, topicId: Int? = nil) async throws -> [DiscourseUser] {
        var path = "/u/search/users.json?term=\(term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term)"
        if let topicId { path += "&topic_id=\(topicId)" }
        let url = try buildURL(base: baseURL, path: path)
        let response = try await fetch(UserSearchResponse.self, from: url, baseURL: baseURL)
        return response.users
    }

    func postTimings(baseURL: String, topicId: Int, topicTime: Int, timings: [Int: Int]) async throws {
        let url = try buildURL(base: baseURL, path: "/topics/timings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        request.setValue("true", forHTTPHeaderField: "X-SILENCE-LOGGER")
        request.setValue("true", forHTTPHeaderField: "Discourse-Background")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        let body: [String: Any] = [
            "topic_id": topicId,
            "topic_time": topicTime,
            "timings": Dictionary(uniqueKeysWithValues: timings.map { ("\($0.key)", $0.value) })
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performRequest(request)
        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }
    }

    func dismissNewTopics(baseURL: String, topicIds: [Int]) async throws {
        let url = try buildURL(base: baseURL, path: "/topics/reset-new")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        let body: [String: Any] = [
            "dismiss_topics": true,
            "dismiss_posts": true,
            "topic_ids": topicIds
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performRequest(request)
        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }
    }

    func revokeApiKey(baseURL: String) async throws {
        let url = try buildURL(base: baseURL, path: "/user-api-key/revoke.json")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")
        await addAuthHeaders(to: &request, baseURL: baseURL)

        _ = try await performRequest(request)
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

        let (data, httpResponse) = try await performRequest(request)
        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
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

        let (data, httpResponse) = try await performRequest(request)
        guard httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError(httpResponse.statusCode, extractErrors(from: data))
        }
    }
}
