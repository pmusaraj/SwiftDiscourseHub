import Foundation

@Observable
@MainActor
final class CategoryListViewModel {
    var categories: [DiscourseCategory] = []
    var isLoading = false
    var error: DiscourseAPIError?

    var apiClient = DiscourseAPIClient()

    private static var cache: [String: (categories: [DiscourseCategory], fetchedAt: Date)] = [:]
    private static let cacheDuration: TimeInterval = 2 * 60 * 60 // 2 hours

    func loadCategories(for site: DiscourseSite) async {
        // Return cached categories if still valid
        if let cached = Self.cache[site.baseURL],
           Date().timeIntervalSince(cached.fetchedAt) < Self.cacheDuration {
            categories = cached.categories
            return
        }

        isLoading = true
        error = nil
        do {
            let response = try await apiClient.fetchCategories(baseURL: site.baseURL)
            let topLevel = response.categoryList?.categories ?? []
            let all = topLevel.flatMap { cat in
                [cat] + (cat.subcategoryList ?? [])
            }
            categories = all
            Self.cache[site.baseURL] = (categories: all, fetchedAt: Date())
        } catch let apiError as DiscourseAPIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }
        isLoading = false
    }
}
