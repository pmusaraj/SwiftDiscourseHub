import SwiftUI
import SwiftData

struct SiteSidebarView: View {
    @Query(sort: \DiscourseSite.sortOrder) private var sites: [DiscourseSite]
    @Binding var selectedSite: DiscourseSite?
    @Binding var selectedTopicId: Int?
    @Binding var showingDiscover: Bool
    var dismissSidebar: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthCoordinator.self) private var authCoordinator
    @Environment(\.apiClient) private var apiClient

    var body: some View {
        VStack(spacing: Theme.Sidebar.iconSpacing) {
            ForEach(sites) { site in
                let isSelected = selectedSite?.baseURL == site.baseURL && !showingDiscover
                Button {
                    if selectedSite?.baseURL == site.baseURL {
                        selectedTopicId = nil
                    } else {
                        selectedSite = site
                    }
                    showingDiscover = false
                    dismissSidebar?()
                } label: {
                    HStack(spacing: 8) {
                        SiteIconView(site: site, isSelected: isSelected)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(site.title)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .lineLimit(1)

                            if site.isAuthenticated, let username = site.username {
                                Text("@\(username)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(isSelected ? Color.accentColor.opacity(0.12) : .clear)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if site.isAuthenticated {
                        Button("Log Out") {
                            Task {
                                await authCoordinator.logout(for: site.baseURL)
                                site.hasApiKey = false
                                site.username = nil
                                try? modelContext.save()
                            }
                        }
                    }
                    Button("Remove Site", role: .destructive) {
                        let baseURL = site.baseURL
                        if selectedSite?.baseURL == baseURL {
                            selectedSite = nil
                        }
                        modelContext.delete(site)
                        try? modelContext.save()
                        Task { await authCoordinator.removeSite(baseURL: baseURL) }
                    }
                }
            }

            Spacer()

            Button {
                selectedSite = nil
                showingDiscover = true
                dismissSidebar?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .frame(width: Theme.Sidebar.discoverButtonSize, height: Theme.Sidebar.discoverButtonSize)

                    Text("Discover")
                        .font(.subheadline)

                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(showingDiscover ? Color.accentColor.opacity(0.12) : .clear)
                .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showingDiscover ? Color.accentColor : .secondary)
            .help("Discover Communities")
        }
        .padding(.vertical, Theme.Sidebar.paddingVertical)
        .padding(.horizontal, Theme.Sidebar.paddingHorizontal)
        .frame(width: Theme.Sidebar.width)
        .frame(maxHeight: .infinity)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -30 {
                        dismissSidebar?()
                    }
                }
        )
        #endif
        .onAppear {
            if selectedSite == nil, let first = sites.first {
                selectedSite = first
            }
        }
        .task {
            for site in sites where site.isAuthenticated && site.username == nil {
                if let username = try? await apiClient.fetchCurrentUsername(baseURL: site.baseURL) {
                    site.username = username
                }
            }
        }
    }
}
