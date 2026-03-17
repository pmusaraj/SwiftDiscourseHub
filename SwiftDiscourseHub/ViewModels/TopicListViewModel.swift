import Foundation

enum TopicFilter: String, CaseIterable {
    case latest = "Latest"
    case new = "New"
    case hot = "Hot"
}

@Observable
final class TopicListViewModel {
    var topics: [Topic] = []
    var users: [DiscourseUser] = []
    var isLoading = false
    var error: DiscourseAPIError?
    var filter: TopicFilter = .latest
    var currentPage = 0
    var hasMore = true
    var selectedCategoryId: Int?
    var selectedCategorySlug: String?

    var apiClient = DiscourseAPIClient()

    @MainActor
    func loadTopics(for site: DiscourseSite) async {
        isLoading = true
        error = nil
        currentPage = 0
        hasMore = true

        do {
            let response: TopicListResponse
            if let slug = selectedCategorySlug, let catId = selectedCategoryId {
                response = try await apiClient.fetchCategoryTopics(
                    baseURL: site.baseURL, categorySlug: slug, categoryId: catId
                )
            } else {
                switch filter {
                case .latest:
                    response = try await apiClient.fetchLatestTopics(baseURL: site.baseURL)
                case .new:
                    response = try await apiClient.fetchNewTopics(baseURL: site.baseURL)
                case .hot:
                    response = try await apiClient.fetchHotTopics(baseURL: site.baseURL)
                }
            }
            topics = (response.topicList?.topics ?? []).filter { $0.pinned != true }
            users = response.users ?? []
            hasMore = response.topicList?.moreTopicsUrl != nil
        } catch let apiError as DiscourseAPIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }
        isLoading = false
    }

    @MainActor
    func loadMore(for site: DiscourseSite) async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        currentPage += 1

        do {
            let response: TopicListResponse
            if let slug = selectedCategorySlug, let catId = selectedCategoryId {
                response = try await apiClient.fetchCategoryTopics(
                    baseURL: site.baseURL, categorySlug: slug, categoryId: catId, page: currentPage
                )
            } else {
                switch filter {
                case .latest:
                    response = try await apiClient.fetchLatestTopics(baseURL: site.baseURL, page: currentPage)
                case .new:
                    response = try await apiClient.fetchNewTopics(baseURL: site.baseURL, page: currentPage)
                case .hot:
                    response = try await apiClient.fetchLatestTopics(baseURL: site.baseURL, page: currentPage)
                }
            }
            let newTopics = (response.topicList?.topics ?? []).filter { $0.pinned != true }
            topics.append(contentsOf: newTopics)
            if let newUsers = response.users {
                users.append(contentsOf: newUsers)
            }
            hasMore = response.topicList?.moreTopicsUrl != nil
        } catch {
            currentPage -= 1
        }
        isLoading = false
    }

    func user(for poster: Poster) -> DiscourseUser? {
        guard let userId = poster.userId else { return nil }
        return users.first { $0.id == userId }
    }

    func selectCategory(slug: String, id: Int) {
        selectedCategorySlug = slug
        selectedCategoryId = id
    }

    func clearCategory() {
        selectedCategorySlug = nil
        selectedCategoryId = nil
    }
}
