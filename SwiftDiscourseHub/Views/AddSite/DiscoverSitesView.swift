import SwiftUI
import SwiftData

struct DiscoverSitesView: View {
    var onSiteAdded: ((DiscourseSite) -> Void)?

    @Query(sort: \DiscourseSite.sortOrder) private var savedSites: [DiscourseSite]
    @Environment(\.modelContext) private var modelContext
    @State private var sites: [DiscoverSite] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedCategory: DiscoverCategory = .featured
    @State private var currentPage = 1
    @State private var hasMore = false

    private let discoveryService = SiteDiscoveryService()
    private let apiClient = DiscourseAPIClient()

    private func isSiteAdded(_ site: DiscoverSite) -> Bool {
        let normalized = site.featuredLink.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return savedSites.contains { saved in
            let savedNorm = saved.baseURL.lowercased()
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return savedNorm == normalized
        }
    }

    private func stripHTML(_ html: String?) -> String {
        guard let html else { return "" }
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscoverCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.displayName, systemImage: category.iconName)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()

            // Content
            if isLoading && sites.isEmpty {
                Spacer()
                ProgressView("Discovering communities...")
                Spacer()
            } else if let error, sites.isEmpty {
                Spacer()
                ErrorStateView(title: "Failed to Load", message: error) {
                    Task { await loadSites(reset: true) }
                }
                Spacer()
            } else {
                List {
                    ForEach(sites) { site in
                        DiscoverSiteRow(
                            site: site,
                            isAdded: isSiteAdded(site),
                            strippedExcerpt: stripHTML(site.excerpt),
                            onAdd: { Task { await addSite(site) } }
                        )
                    }
                    if hasMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .onAppear {
                                    Task { await loadMore() }
                                }
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Discover")
        .task(id: selectedCategory) {
            await loadSites(reset: true)
        }
    }

    private func loadSites(reset: Bool) async {
        guard !isLoading else { return }
        if reset {
            currentPage = 1
        }
        isLoading = true
        error = nil
        do {
            let result = try await discoveryService.fetchSites(category: selectedCategory, page: currentPage)
            if reset {
                sites = result.sites
            } else {
                sites.append(contentsOf: result.sites)
            }
            hasMore = result.hasMore
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        currentPage += 1
        await loadSites(reset: false)
    }

    private func addSite(_ discoverSite: DiscoverSite) async {
        let url = discoverSite.featuredLink
        let site: DiscourseSite
        do {
            let info = try await apiClient.fetchBasicInfo(baseURL: url)
            site = DiscourseSite(
                baseURL: url,
                title: info.title ?? discoverSite.title,
                iconURL: info.appleTouchIconUrl ?? info.faviconUrl,
                logoURL: info.logoUrl,
                siteDescription: info.description
            )
        } catch {
            let logoUrl = discoverSite.logoUrl
            site = DiscourseSite(
                baseURL: url,
                title: discoverSite.title,
                iconURL: logoUrl,
                siteDescription: stripHTML(discoverSite.excerpt)
            )
        }
        await MainActor.run {
            modelContext.insert(site)
            try? modelContext.save()
            onSiteAdded?(site)
        }
    }
}

struct DiscoverSiteRow: View {
    let site: DiscoverSite
    let isAdded: Bool
    let strippedExcerpt: String
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Logo
            if let logoUrl = site.logoUrl, let url = URL(string: logoUrl.hasPrefix("//") ? "https:\(logoUrl)" : logoUrl),
               !logoUrl.hasSuffix(".svg") && !logoUrl.hasSuffix(".webp") {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    siteLetterIcon
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                siteLetterIcon
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(site.title)
                    .font(.headline)
                    .lineLimit(1)

                if !strippedExcerpt.isEmpty {
                    Text(strippedExcerpt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let users = site.activeUsers30Days, users > 0 {
                    Label("\(users) active users", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var siteLetterIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.secondary.opacity(0.2))
            Text(String(site.title.prefix(1)).uppercased())
                .font(.title2.bold())
                .foregroundStyle(.secondary)
        }
        .frame(width: 44, height: 44)
    }
}
