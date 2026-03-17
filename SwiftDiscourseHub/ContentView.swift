import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \DiscourseSite.sortOrder) private var sites: [DiscourseSite]
    @State private var selectedSite: DiscourseSite?
    @State private var selectedTopicId: Int?
    @State private var selectedTopic: Topic?
    @State private var topicCategories: [DiscourseCategory] = []
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
            selectedTopic = nil
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
        #if os(macOS)
        macOSLayout
        #else
        iPadLayout
        #endif
    }

    #if os(macOS)
    private var hasDetail: Bool { selectedTopicId != nil && selectedSite != nil }

    private var panelShadow: some View {
        LinearGradient(
            colors: [.black.opacity(0.06), .black.opacity(0.02), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 6)
        .allowsHitTesting(false)
    }

    private var macOSLayout: some View {
        HStack(spacing: 0) {
            SiteSidebarView(selectedSite: $selectedSite, showingDiscover: $showingDiscover)
                .zIndex(2)
            panelShadow
                .zIndex(1)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    NavigationStack {
                        Group {
                            if showingDiscover {
                                DiscoverSitesView(onSiteAdded: { site in
                                    selectedSite = site
                                    showingDiscover = false
                                })
                                .navigationTitle("Discover")
                            } else if let site = selectedSite {
                                TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
                                    .id(site.baseURL)
                                    .transition(.opacity)
                            } else {
                                ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedSite?.baseURL)
                    }
                    .frame(width: hasDetail ? geo.size.width / 3 : geo.size.width)
                    .zIndex(1)

                    panelShadow

                    if hasDetail {
                        if let topicId = selectedTopicId, let site = selectedSite {
                            TopicDetailView(topicId: topicId, baseURL: site.baseURL, topic: selectedTopic, categories: topicCategories)
                                .frame(maxWidth: .infinity)
                                .id(topicId)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: hasDetail)
            }
        }
    }
    #endif

    #if os(iOS)
    private var iPadLayout: some View {
        Group {
            if selectedTopicId != nil, let site = selectedSite {
                NavigationSplitView {
                    SiteSidebarView(selectedSite: $selectedSite, showingDiscover: $showingDiscover)
                } content: {
                    TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
                } detail: {
                    TopicDetailView(topicId: selectedTopicId!, baseURL: site.baseURL, topic: selectedTopic, categories: topicCategories)
                }
            } else {
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
                        TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
                    } else {
                        ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                    }
                }
            }
        }
    }
    #endif

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
    @State private var selectedTopic: Topic?
    @State private var topicCategories: [DiscourseCategory] = []

    var body: some View {
        TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
            .navigationDestination(item: $selectedTopicId) { topicId in
                TopicDetailView(topicId: topicId, baseURL: site.baseURL, topic: selectedTopic, categories: topicCategories)
            }
    }
}
