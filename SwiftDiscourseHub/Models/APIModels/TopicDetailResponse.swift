import Foundation

struct TopicDetailResponse: Codable {
    let postStream: PostStream?
    let id: Int
    let title: String?
    let fancyTitle: String?
    let postsCount: Int?
    let createdAt: String?
    let views: Int?
    let likeCount: Int?
    let categoryId: Int?
    let slug: String?
}

struct PostStream: Codable {
    let posts: [Post]?
    let stream: [Int]?
}

struct Post: Codable, Identifiable {
    let id: Int
    let username: String?
    let name: String?
    let avatarTemplate: String?
    let createdAt: String?
    let cooked: String?
    let postNumber: Int?
    let postType: Int?
    let replyCount: Int?
    let readsCount: Int?
    let score: Double?
    let yours: Bool?
    let topicId: Int?
    let admin: Bool?
    let moderator: Bool?
    let staff: Bool?
    let actionsSummary: [ActionSummary]?
    let replyToPostNumber: Int?

    var likeCount: Int {
        actionsSummary?.first(where: { $0.id == 2 })?.count ?? 0
    }
}

struct ActionSummary: Codable {
    let id: Int
    let count: Int?
}

struct TopicPostsResponse: Codable {
    let postStream: PostStreamSlice

    struct PostStreamSlice: Codable {
        let posts: [Post]
    }
}
