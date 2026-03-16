import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \DiscourseSite.sortOrder) private var sites: [DiscourseSite]
    @State private var selectedSite: DiscourseSite?
    @State private var selectedTopicId: Int?
    @State private var showingAddSite = false
    @State private var showingDiscover = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var hasSites: Bool { !sites.isEmpty }

    var body: some View {
        Group {
            if !hasSites && !showingDiscover {
                welcomeView
            } else {
                #if os(macOS)
                regularLayout
                #else
                if horizontalSizeClass == .compact {
                    compactLayout
                } else {
                    regularLayout
                }
                #endif
            }
        }
        .sheet(isPresented: $showingAddSite) {
            AddSiteSheet()
        }
        .onChange(of: selectedSite?.baseURL) {
            selectedTopicId = nil
        }
    }

    // MARK: - Welcome (no sites)

    private var welcomeView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("Welcome to SwiftDiscourseHub")
                    .font(.title2.bold())

                Text("Add a Discourse community to get started")
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button {
                        showingAddSite = true
                    } label: {
                        Label("Add a Site by URL", systemImage: "link")
                            .frame(maxWidth: 260)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        showingDiscover = true
                    } label: {
                        Label("Discover Communities", systemImage: "globe")
                            .frame(maxWidth: 260)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()
            }
        }
    }

    // MARK: - Regular (Mac / iPad) — 2-column, expanding to 3 when topic selected

    private var regularLayout: some View {
        Group {
            if selectedTopicId != nil, let site = selectedSite {
                // 3-column: sidebar | topics | detail
                NavigationSplitView {
                    SiteSidebarView(selectedSite: $selectedSite, showingDiscover: $showingDiscover)
                } content: {
                    TopicListView(site: site, selectedTopicId: $selectedTopicId)
                } detail: {
                    TopicDetailView(topicId: selectedTopicId!, baseURL: site.baseURL)
                }
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 48, ideal: 48, max: 48)
                #endif
            } else {
                // 2-column: sidebar | content
                NavigationSplitView {
                    SiteSidebarView(selectedSite: $selectedSite, showingDiscover: $showingDiscover)
                } detail: {
                    if showingDiscover {
                        DiscoverSitesView(onSiteAdded: { site in
                            selectedSite = site
                            showingDiscover = false
                        })
                        .navigationTitle("Discover")
                    } else if let site = selectedSite {
                        TopicListView(site: site, selectedTopicId: $selectedTopicId)
                    } else {
                        ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                    }
                }
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 48, ideal: 48, max: 48)
                #endif
            }
        }
    }

    // MARK: - Compact (iPhone)

    private var compactLayout: some View {
        NavigationStack {
            CompactSiteListView(selectedSite: $selectedSite, showingAddSite: $showingAddSite, showingDiscover: $showingDiscover)
                .navigationDestination(isPresented: $showingDiscover) {
                    DiscoverSitesView(onSiteAdded: { site in
                        selectedSite = site
                        showingDiscover = false
                    })
                }
        }
    }
}

// MARK: - Compact site list for iPhone

struct CompactSiteListView: View {
    @Query(sort: \DiscourseSite.sortOrder) private var sites: [DiscourseSite]
    @Binding var selectedSite: DiscourseSite?
    @Binding var showingAddSite: Bool
    @Binding var showingDiscover: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(sites) { site in
                NavigationLink {
                    CompactTopicListView(site: site)
                } label: {
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
                for index in indexSet {
                    modelContext.delete(sites[index])
                }
                try? modelContext.save()
            }
        }
        .navigationTitle("Sites")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
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
                } label: {
                    Image(systemName: "plus")
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

// MARK: - Compact topic list with NavigationLink to detail

struct CompactTopicListView: View {
    let site: DiscourseSite
    @State private var selectedTopicId: Int?

    var body: some View {
        TopicListView(site: site, selectedTopicId: $selectedTopicId)
            .navigationDestination(item: $selectedTopicId) { topicId in
                TopicDetailView(topicId: topicId, baseURL: site.baseURL)
            }
    }
}
