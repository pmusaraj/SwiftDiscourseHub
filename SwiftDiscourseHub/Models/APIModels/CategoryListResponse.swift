import Foundation

struct CategoryListResponse: Codable {
    let categoryList: CategoryListWrapper?
}

struct CategoryListWrapper: Codable {
    let canCreateCategory: Bool?
    let canCreateTopic: Bool?
    let categories: [DiscourseCategory]?
}

struct DiscourseCategory: Codable, Identifiable {
    let id: Int
    let name: String?
    let slug: String?
    let color: String?
    let textColor: String?
    let topicCount: Int?
    let postCount: Int?
    let description: String?
    let descriptionText: String?
    let topicUrl: String?
    let subcategoryIds: [Int]?
    let uploadedLogo: CategoryLogo?
    let parentCategoryId: Int?
    let position: Int?
}

struct CategoryLogo: Codable {
    let url: String?
    let width: Int?
    let height: Int?
}
