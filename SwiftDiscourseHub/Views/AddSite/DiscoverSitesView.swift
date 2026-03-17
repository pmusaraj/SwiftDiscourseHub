import SwiftUI
import SwiftData

struct DiscoverSitesView: View {
    var onSiteAdded: ((DiscourseSite) -> Void)?
    @Binding var selectedDiscoverSite: DiscoverSite?

    @Query(sort: \DiscourseSite.sortOrder) private var savedSites: [DiscourseSite]
    @Environment(\.modelContext) private var modelContext
    @State private var sites: [DiscoverSite] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedCategory: DiscoverCategory = .featured
    @State private var currentPage = 1
    @State private var hasMore = false
    @State private var contentWidth: CGFloat = 0

    // Add by URL
    @State private var urlText = ""
    @State private var isValidating = false
    @State private var validationError: String?

    private let discoveryService = SiteDiscoveryService()
    @Environment(\.apiClient) private var apiClient

    private var horizontalPadding: CGFloat {
        Theme.Padding.postHorizontal(for: contentWidth)
    }

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
            // Add by URL
            addByURLBar

            Divider()

            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscoverCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.displayName, systemImage: category.iconName)
                                .font(Theme.Fonts.discoverCategory)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sites) { site in
                            DiscoverSiteRow(
                                site: site,
                                isAdded: isSiteAdded(site),
                                isSelected: selectedDiscoverSite?.id == site.id,
                                strippedExcerpt: stripHTML(site.excerpt),
                                onAdd: { Task { await addSite(site) } }
                            )
                            .padding(.horizontal, horizontalPadding)
                            .contentShape(Rectangle())
                            .background(selectedDiscoverSite?.id == site.id ? Color.accentColor.opacity(Theme.Selection.highlightOpacity) : .clear)
                            .onTapGesture {
                                selectedDiscoverSite = site
                            }
                        }
                        if hasMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .onAppear {
                                    Task { await loadMore() }
                                }
                        }
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            contentWidth = newWidth
        }
        .navigationTitle("Discover")
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .task(id: selectedCategory) {
            await loadSites(reset: true)
        }
    }

    // MARK: - Add by URL

    private var addByURLBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)

            TextField("Add site by URL...", text: $urlText)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .onSubmit { Task { await validateAndAdd() } }

            if isValidating {
                ProgressView()
                    .controlSize(.small)
            } else if !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    Task { await validateAndAdd() }
                } label: {
                    Text("Add")
                        .font(.body.bold())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if let validationError {
                Text(validationError)
                    .font(Theme.Fonts.metadataSmall)
                    .foregroundStyle(.red)
                    .padding(.horizontal, horizontalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: 16)
            }
        }
    }

    // MARK: - Data Loading

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

    private func validateAndAdd() async {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        var normalized = raw.lowercased()
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        isValidating = true
        validationError = nil

        do {
            let info = try await apiClient.fetchBasicInfo(baseURL: normalized)
            if info.loginRequired == true {
                validationError = "This site requires login"
                isValidating = false
                return
            }
            let site = DiscourseSite(
                baseURL: normalized,
                title: info.title ?? normalized,
                iconURL: info.appleTouchIconUrl ?? info.faviconUrl,
                logoURL: info.logoUrl,
                siteDescription: info.description
            )
            await MainActor.run {
                modelContext.insert(site)
                try? modelContext.save()
                onSiteAdded?(site)
            }
            urlText = ""
        } catch {
            validationError = "Could not connect to site"
        }
        isValidating = false
    }
}

struct DiscoverSiteRow: View {
    let site: DiscoverSite
    let isAdded: Bool
    let isSelected: Bool
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
                .frame(width: Theme.Discover.siteIconSize, height: Theme.Discover.siteIconSize)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Discover.siteIconCornerRadius))
            } else {
                siteLetterIcon
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(site.title)
                    .font(Theme.Fonts.discoverSiteTitle)
                    .lineLimit(1)

                if !strippedExcerpt.isEmpty {
                    Text(strippedExcerpt)
                        .font(Theme.Fonts.discoverSiteDescription)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let users = site.activeUsers30Days, users > 0 {
                    Label("\(users) active users", systemImage: "person.2")
                        .font(Theme.Fonts.discoverSiteStats)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(Theme.Discover.actionIconFont)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(Theme.Discover.actionIconFont)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Padding.topicRowVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var siteLetterIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Discover.siteIconCornerRadius)
                .fill(.secondary.opacity(Theme.Sidebar.iconFallbackOpacity))
            Text(String(site.title.prefix(1)).uppercased())
                .font(Theme.Fonts.siteIconFallback)
                .foregroundStyle(.secondary)
        }
        .frame(width: Theme.Discover.siteIconSize, height: Theme.Discover.siteIconSize)
    }
}
