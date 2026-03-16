import Foundation

struct SiteBasicInfoResponse: Codable {
    let title: String?
    let description: String?
    let logoUrl: String?
    let appleTouchIconUrl: String?
    let mobileLogoUrl: String?
    let loginRequired: Bool?
    // Discourse uses "favicon_url" at top level
    let faviconUrl: String?
}
