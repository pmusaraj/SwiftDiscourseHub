import Foundation

struct TopicListResponse: Codable {
    let users: [DiscourseUser]?
    let topicList: TopicList?
}

struct TopicList: Codable {
    let canCreateTopic: Bool?
    let moreTopicsUrl: String?
    let perPage: Int?
    let topics: [Topic]?
}

struct Topic: Codable, Identifiable {
    let id: Int
    let title: String?
    let fancyTitle: String?
    let slug: String?
    let postsCount: Int?
    let replyCount: Int?
    let highestPostNumber: Int?
    let createdAt: String?
    let lastPostedAt: String?
    let bumped: Bool?
    let bumpedAt: String?
    let archetype: String?
    let unseen: Bool?
    let pinned: Bool?
    let excerpt: String?
    let visible: Bool?
    let closed: Bool?
    let archived: Bool?
    let views: Int?
    let likeCount: Int?
    let categoryId: Int?
    let posters: [Poster]?
    let imageUrl: String?
}

struct Poster: Codable {
    let extras: String?
    let description: String?
    let userId: Int?
}

struct DiscourseUser: Codable, Identifiable {
    let id: Int
    let username: String?
    let name: String?
    let avatarTemplate: String?
}

struct UserSearchResponse: Codable {
    let users: [DiscourseUser]
}
