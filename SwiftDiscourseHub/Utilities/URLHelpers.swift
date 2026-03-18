import Foundation

enum URLHelpers {
    /// Resolves a potentially relative URL against a base site URL
    static func resolveURL(_ urlString: String?, baseURL: String) -> URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return URL(string: base + (urlString.hasPrefix("/") ? urlString : "/" + urlString))
    }

    /// Builds a full avatar URL from a Discourse avatar template
    /// Avatar templates look like: "/user_avatar/meta.discourse.org/username/{size}/12345_2.png"
    static func avatarURL(template: String?, size: Int, baseURL: String) -> URL? {
        guard let template else { return nil }
        let resolved = template.replacing("{size}", with: "\(size)")
        return resolveURL(resolved, baseURL: baseURL)
    }
}
