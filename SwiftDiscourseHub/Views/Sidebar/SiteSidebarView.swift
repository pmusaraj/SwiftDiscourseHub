import SwiftUI
import SwiftData

struct SiteSidebarView: View {
    @Query(sort: \DiscourseSite.sortOrder) private var sites: [DiscourseSite]
    @Binding var selectedSite: DiscourseSite?
    @Binding var selectedTopicId: Int?
    @Binding var showingDiscover: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthCoordinator.self) private var authCoordinator

    var body: some View {
        VStack(spacing: Theme.Sidebar.iconSpacing) {
            ForEach(sites) { site in
                Button {
                    if selectedSite?.baseURL == site.baseURL {
                        selectedTopicId = nil
                    } else {
                        selectedSite = site
                    }
                    showingDiscover = false
                } label: {
                    SiteIconView(site: site, isSelected: selectedSite?.baseURL == site.baseURL && !showingDiscover)
                }
                .buttonStyle(.plain)
                .contextMenu {
                        if site.isAuthenticated {
                            Button("Log Out") {
                                Task {
                                    await authCoordinator.logout(for: site.baseURL)
                                    site.hasApiKey = false
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

            Button("Discover Communities", systemImage: "globe") {
                selectedSite = nil
                showingDiscover = true
            }
            .labelStyle(.iconOnly)
            .font(Theme.Fonts.sidebarIcon)
            .foregroundStyle(showingDiscover && selectedSite == nil ? Color.accentColor : Color.secondary)
            .frame(width: Theme.Sidebar.discoverButtonSize, height: Theme.Sidebar.discoverButtonSize)
            .buttonStyle(.plain)
            .help("Discover Communities")
        }
        .padding(.vertical, Theme.Sidebar.paddingVertical)
        .padding(.horizontal, Theme.Sidebar.paddingHorizontal)
        .frame(width: Theme.Sidebar.width)
        .frame(maxHeight: .infinity)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            if selectedSite == nil, let first = sites.first {
                selectedSite = first
            }
        }
    }
}
