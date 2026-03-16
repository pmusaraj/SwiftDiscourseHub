import Foundation

@Observable
final class CategoryListViewModel {
    var categories: [DiscourseCategory] = []
    var isLoading = false
    var error: DiscourseAPIError?

    private let apiClient = DiscourseAPIClient()

    @MainActor
    func loadCategories(for site: DiscourseSite) async {
        isLoading = true
        error = nil
        do {
            let response = try await apiClient.fetchCategories(baseURL: site.baseURL)
            categories = response.categoryList?.categories ?? []
        } catch let apiError as DiscourseAPIError {
            error = apiError
        } catch {
            self.error = .networkError(error)
        }
        isLoading = false
    }
}
