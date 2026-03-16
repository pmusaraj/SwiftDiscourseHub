import Testing
import Foundation

@testable import SwiftDiscourseHub

@Suite(.serialized) struct DiscoverTests {

    @Test func discoverFeaturedLoads20Sites() async throws {
        let service = SiteDiscoveryService()
        let result = try await service.fetchSites(category: .featured, page: 1)

        #expect(result.sites.count >= 20, "Expected at least 20 sites, got \(result.sites.count)")

        // Verify first site has required fields
        let first = result.sites[0]
        #expect(!first.title.isEmpty, "Title should not be empty")
        #expect(!first.featuredLink.isEmpty, "Featured link should not be empty")
        #expect(first.featuredLink.hasPrefix("http"), "Link should be a URL: \(first.featuredLink)")

        // Verify logo URLs are present for most sites
        let sitesWithLogos = result.sites.prefix(20).filter { $0.logoUrl != nil }
        #expect(sitesWithLogos.count >= 10, "Expected at least 10 of top 20 to have logos, got \(sitesWithLogos.count)")

        // Verify active user counts are present
        let sitesWithUsers = result.sites.prefix(20).filter { ($0.activeUsers30Days ?? 0) > 0 }
        #expect(sitesWithUsers.count >= 10, "Expected at least 10 of top 20 to have active users, got \(sitesWithUsers.count)")

        // Verify pagination flag
        #expect(result.hasMore, "Featured should have more than one page")
    }

    @Test func discoverSiteFieldsAreValid() async throws {
        let service = SiteDiscoveryService()
        let result = try await service.fetchSites(category: .featured, page: 1)

        for site in result.sites.prefix(5) {
            // Every site must have a title and a valid URL
            #expect(!site.title.isEmpty)
            #expect(site.featuredLink.hasPrefix("https://") || site.featuredLink.hasPrefix("http://"),
                    "Invalid URL for \(site.title): \(site.featuredLink)")
            // Excerpt should have HTML stripped or be raw HTML from API
            // Logo URL if present should be a valid URL
            if let logo = site.logoUrl {
                #expect(logo.contains("://") || logo.hasPrefix("//"),
                        "Logo should be a URL: \(logo)")
            }
        }
    }

    @Test func discoverCategoryFilterWorks() async throws {
        let service = SiteDiscoveryService()

        // Test a specific category
        let techResult = try await service.fetchSites(category: .technology, page: 1)
        #expect(!techResult.sites.isEmpty, "Tech category should return sites")

        try await Task.sleep(for: .seconds(2))

        let aiResult = try await service.fetchSites(category: .ai, page: 1)
        #expect(!aiResult.sites.isEmpty, "AI category should return sites")

        // Results should differ between categories
        let techIds = Set(techResult.sites.prefix(10).map(\.id))
        let aiIds = Set(aiResult.sites.prefix(10).map(\.id))
        #expect(techIds != aiIds, "Different categories should return different results")
    }
}
