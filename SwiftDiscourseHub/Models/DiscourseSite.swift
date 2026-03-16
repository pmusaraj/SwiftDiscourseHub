import Foundation
import SwiftData

@Model
final class DiscourseSite {
    @Attribute(.unique) var baseURL: String
    var title: String
    var iconURL: String?
    var logoURL: String?
    var siteDescription: String?
    var sortOrder: Int
    var addedAt: Date

    init(baseURL: String, title: String, iconURL: String? = nil, logoURL: String? = nil, siteDescription: String? = nil, sortOrder: Int = 0) {
        // Normalize URL: ensure https, strip trailing slash
        var normalized = baseURL.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        self.baseURL = normalized
        self.title = title
        self.iconURL = iconURL
        self.logoURL = logoURL
        self.siteDescription = siteDescription
        self.sortOrder = sortOrder
        self.addedAt = Date()
    }
}
