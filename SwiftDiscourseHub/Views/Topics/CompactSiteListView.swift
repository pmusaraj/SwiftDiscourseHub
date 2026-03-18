import SwiftUI
import SwiftData

struct CompactSiteListView: View {
    @Query(sort: \DiscourseSite.sortOrder) private var sites: [DiscourseSite]
    @Binding var selectedSite: DiscourseSite?
    @Binding var showingAddSite: Bool
    @Binding var showingDiscover: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthCoordinator.self) private var authCoordinator

    var body: some View {
        List {
            ForEach(sites) { site in
                NavigationLink(value: site) {
                    HStack(spacing: 12) {
                        SiteIconView(site: site, isSelected: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.title)
                                .font(.headline)
                            Text(site.baseURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                let sitesToDelete = indexSet.map { sites[$0] }
                for site in sitesToDelete {
                    let baseURL = site.baseURL
                    modelContext.delete(site)
                    Task { await authCoordinator.removeSite(baseURL: baseURL) }
                }
                try? modelContext.save()
            }
        }
        .navigationDestination(for: DiscourseSite.self) { site in
            CompactTopicListView(site: site)
        }
        .navigationTitle("Sites")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Add Site", systemImage: "plus") {
                    Button {
                        showingAddSite = true
                    } label: {
                        Label("Add Site by URL", systemImage: "link")
                    }
                    Button {
                        showingDiscover = true
                    } label: {
                        Label("Discover Communities", systemImage: "globe")
                    }
                }
            }
        }
        .overlay {
            if sites.isEmpty {
                ContentUnavailableView {
                    Label("No Sites", systemImage: "globe")
                } description: {
                    Text("Add a Discourse community to get started")
                } actions: {
                    Button("Discover Communities") { showingDiscover = true }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
