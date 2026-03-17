import SwiftUI
import SwiftData

struct DiscoverSiteDetailView: View {
    let site: DiscoverSite
    var onSiteAdded: ((DiscourseSite) -> Void)?

    @Query(sort: \DiscourseSite.sortOrder) private var savedSites: [DiscourseSite]
    @Environment(\.modelContext) private var modelContext
    @State private var siteInfo: SiteBasicInfoResponse?
    @State private var recentTopics: [Topic] = []
    @State private var recentUsers: [DiscourseUser] = []
    @State private var recentCategories: [DiscourseCategory] = []
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var contentWidth: CGFloat = 0

    @Environment(\.apiClient) private var apiClient

    private var isSiteAdded: Bool {
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

    private var siteURL: URL? {
        URL(string: site.featuredLink)
    }

    private var description: String {
        if let desc = siteInfo?.description, !desc.isEmpty {
            return desc
        }
        if let excerpt = site.excerpt {
            return excerpt.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private var horizontalPadding: CGFloat {
        Theme.Padding.postHorizontal(for: contentWidth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()

                if !description.isEmpty {
                    Text(description)
                        .font(Theme.Fonts.postBody)
                        .foregroundStyle(.secondary)
                }

                if !site.tags.isEmpty {
                    tagsSection
                }

                statsSection

                actionButtons

                if !recentTopics.isEmpty {
                    Divider()
                    recentTopicsSection
                } else if isLoading {
                    Divider()
                    ProgressView("Loading community info...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.vertical, Theme.Padding.postVertical)
            .padding(.horizontal, horizontalPadding)
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
        .task(id: site.id) {
            await loadSiteData()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            if let logoUrl = site.logoUrl,
               let url = URL(string: logoUrl.hasPrefix("//") ? "https:\(logoUrl)" : logoUrl),
               !logoUrl.hasSuffix(".svg") && !logoUrl.hasSuffix(".webp") {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    siteLetterIcon
                }
                .frame(width: Theme.Discover.detailIconSize, height: Theme.Discover.detailIconSize)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Discover.detailIconCornerRadius))
            } else {
                siteLetterIcon
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(site.title)
                    .font(Theme.Fonts.topicHeaderTitle)

                Text(site.featuredLink)
                    .font(Theme.Fonts.metadata)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var siteLetterIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Discover.detailIconCornerRadius)
                .fill(.secondary.opacity(Theme.Sidebar.iconFallbackOpacity))
            Text(String(site.title.prefix(1)).uppercased())
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(width: Theme.Discover.detailIconSize, height: Theme.Discover.detailIconSize)
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(Theme.Fonts.postAuthorName)

            FlowLayout(spacing: 8) {
                ForEach(site.tags, id: \.self) { tag in
                    Text(tag.capitalized)
                        .font(Theme.Fonts.metadata)
                        .padding(.horizontal, Theme.Discover.tagPaddingH)
                        .padding(.vertical, Theme.Discover.tagPaddingV)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 24) {
            if let users = site.activeUsers30Days, users > 0 {
                Label("\(users) active users", systemImage: "person.2")
            }
            if !recentTopics.isEmpty {
                Label("\(recentTopics.count) recent topics", systemImage: "text.bubble")
            }
        }
        .font(Theme.Fonts.discoverSiteStats)
        .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if isSiteAdded {
                Label("Added to Sidebar", systemImage: "checkmark.circle.fill")
                    .font(.body.bold())
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await addSite() }
                } label: {
                    Label(isAdding ? "Adding..." : "Add to Sidebar", systemImage: "plus.circle.fill")
                        .font(.body.bold())
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAdding)
            }

            if let url = siteURL {
                Button {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                } label: {
                    Label("Open in Safari", systemImage: "safari")
                        .font(.body)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Recent Topics

    private var recentTopicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Topics")
                .font(Theme.Fonts.postAuthorName)

            ForEach(recentTopics.prefix(8)) { topic in
                TopicRowView(
                    topic: topic,
                    users: recentUsers,
                    categories: recentCategories,
                    baseURL: site.featuredLink
                )
            }
        }
    }

    // MARK: - Data Loading

    private func loadSiteData() async {
        isLoading = true
        async let infoTask: Void = loadBasicInfo()
        async let topicsTask: Void = loadRecentTopics()
        _ = await (infoTask, topicsTask)
        isLoading = false
    }

    private func loadBasicInfo() async {
        do {
            siteInfo = try await apiClient.fetchBasicInfo(baseURL: site.featuredLink)
        } catch {
            // Non-fatal — we still have discover data
        }
    }

    private func loadRecentTopics() async {
        do {
            let response = try await apiClient.fetchLatestTopics(baseURL: site.featuredLink)
            recentTopics = response.topicList?.topics ?? []
            recentUsers = response.users ?? []

            let catResponse = try await apiClient.fetchCategories(baseURL: site.featuredLink)
            recentCategories = catResponse.categoryList?.categories ?? []
        } catch {
            // Non-fatal
        }
    }

    private func addSite() async {
        isAdding = true
        let url = site.featuredLink
        let newSite: DiscourseSite
        if let info = siteInfo {
            newSite = DiscourseSite(
                baseURL: url,
                title: info.title ?? site.title,
                iconURL: info.appleTouchIconUrl ?? info.faviconUrl,
                logoURL: info.logoUrl,
                siteDescription: info.description
            )
        } else {
            newSite = DiscourseSite(
                baseURL: url,
                title: site.title,
                iconURL: site.logoUrl,
                siteDescription: description.isEmpty ? nil : description
            )
        }
        await MainActor.run {
            modelContext.insert(newSite)
            try? modelContext.save()
            onSiteAdded?(newSite)
        }
        isAdding = false
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
