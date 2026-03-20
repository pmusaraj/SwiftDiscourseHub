import Foundation

struct CurrentUserResponse: Decodable {
    let currentUser: CurrentUser

    struct CurrentUser: Decodable {
        let username: String
        let avatarTemplate: String?
    }
}
