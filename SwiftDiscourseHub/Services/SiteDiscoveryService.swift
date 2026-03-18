import Foundation

enum DiscoverCategory: String, CaseIterable, Identifiable {
    case featured = "#locale-en"
    case technology = "#technology"
    case interests = "#interests"
    case support = "#support"
    case media = "#media"
    case gaming = "#gaming"
    case finance = "#finance"
    case openSource = "#open-source"
    case ai = "#ai"
    case international = "#locale-intl"
    case recent = "order:latest_topic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .featured: return "Featured"
        case .technology: return "Tech"
        case .interests: return "Interests"
        case .support: return "Support"
        case .media: return "Media"
        case .gaming: return "Gaming"
        case .finance: return "Finance"
        case .openSource: return "Open Source"
        case .ai: return "AI"
        case .international: return "International"
        case .recent: return "Recent"
        }
    }

    var iconName: String {
        switch self {
        case .featured: return "star.fill"
        case .technology: return "desktopcomputer"
        case .interests: return "heart.fill"
        case .support: return "questionmark.circle.fill"
        case .media: return "play.rectangle.fill"
        case .gaming: return "gamecontroller.fill"
        case .finance: return "chart.line.uptrend.xyaxis"
        case .openSource: return "chevron.left.forwardslash.chevron.right"
        case .ai: return "brain.head.profile"
        case .international: return "globe"
        case .recent: return "clock.fill"
        }
    }
}

struct DiscoverSite: Identifiable, Hashable {
    let id: Int
    let title: String
    let featuredLink: String
    let excerpt: String?
    let logoUrl: String?
    let activeUsers30Days: Int?
    let topics30Days: Int?
    let tags: [String]

    static func == (lhs: DiscoverSite, rhs: DiscoverSite) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Raw Codable types for the search API response
private struct DiscoverSearchResponse: Codable {
    let topics: [DiscoverSearchTopic]?
    let groupedSearchResult: GroupedSearchResult?

    enum CodingKeys: String, CodingKey {
        case topics
        case groupedSearchResult = "grouped_search_result"
    }
}

private struct DiscoverSearchTopic: Codable {
    let id: Int
    let title: String?
    let featuredLink: String?
    let excerpt: String?
    let discoverEntryLogoUrl: String?
    let activeUsers30Days: Int?
    let topics30Days: Int?
    let tags: [DiscoverTag]?

    enum CodingKeys: String, CodingKey {
        case id, title, excerpt, tags
        case featuredLink = "featured_link"
        case discoverEntryLogoUrl = "discover_entry_logo_url"
        case activeUsers30Days = "active_users_30_days"
        case topics30Days = "topics_30_days"
    }
}

private struct DiscoverTag: Codable {
    let name: String
}

private struct GroupedSearchResult: Codable {
    let moreFullPageResults: Bool?

    enum CodingKeys: String, CodingKey {
        case moreFullPageResults = "more_full_page_results"
    }
}

actor SiteDiscoveryService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSites(category: DiscoverCategory = .featured, page: Int = 1) async throws -> (sites: [DiscoverSite], hasMore: Bool) {
        let tag = category.rawValue
        let orderSuffix = tag.contains("order:") ? "" : " order:featured"
        let query = "#discover \(tag)\(orderSuffix)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://discover.discourse.com/search.json?q=\(encoded)&page=\(page)") else {
            throw DiscourseAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DiscourseHub", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DiscourseAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DiscourseAPIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0, nil)
        }

        let decoder = JSONDecoder()

        let searchResponse: DiscoverSearchResponse
        do {
            searchResponse = try decoder.decode(DiscoverSearchResponse.self, from: data)
        } catch {
            throw DiscourseAPIError.decodingError(error)
        }

        let sites = (searchResponse.topics ?? []).compactMap { topic -> DiscoverSite? in
            guard let link = topic.featuredLink, !link.isEmpty else { return nil }
            let discoverTags = (topic.tags ?? []).map(\.name).filter { !$0.hasPrefix("locale-") && $0 != "discover" && $0 != "featured" }
            return DiscoverSite(
                id: topic.id,
                title: topic.title ?? link,
                featuredLink: link.hasPrefix("http") ? link : "https://\(link)",
                excerpt: topic.excerpt,
                logoUrl: topic.discoverEntryLogoUrl,
                activeUsers30Days: topic.activeUsers30Days,
                topics30Days: topic.topics30Days,
                tags: discoverTags
            )
        }

        let hasMore = searchResponse.groupedSearchResult?.moreFullPageResults ?? false
        return (sites, hasMore)
    }
}
