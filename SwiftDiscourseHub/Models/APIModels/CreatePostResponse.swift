import Foundation

struct CreatePostRequest: Encodable {
    let topicId: Int
    let raw: String

    enum CodingKeys: String, CodingKey {
        case topicId = "topic_id"
        case raw
    }
}

struct CreatePostResponse: Codable {
    let id: Int
    let topicId: Int?
    let postNumber: Int?
    let raw: String?
    let cooked: String?
    let createdAt: String?
    let username: String?
}
