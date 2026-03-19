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
    @State private var selectedDiscoverSite: DiscoverSite?
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AuthCoordinator.self) private var authCoordinator
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.apiClient) private var apiClient

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
        .onChange(of: showingDiscover) {
            if !showingDiscover {
                selectedDiscoverSite = nil
            }
            columnVisibility = showingDiscover ? .detailOnly : .doubleColumn
        }
        .onChange(of: authCoordinator.isAuthenticating) {
            // When auth finishes successfully, update the site's hasApiKey flag
            if !authCoordinator.isAuthenticating,
               authCoordinator.authError == nil,
               let baseURL = authCoordinator.pendingBaseURL,
               let site = sites.first(where: { $0.baseURL == baseURL }) {
                Task {
                    if await authCoordinator.apiKey(for: baseURL) != nil {
                        site.hasApiKey = true
                        toastManager.show("Logged in to \(site.title)", style: .success)
                        if let username = try? await apiClient.fetchCurrentUsername(baseURL: baseURL) {
                            site.username = username
                        }
                    }
                }
            }
        }
        .onChange(of: authCoordinator.authError) {
            if let error = authCoordinator.authError {
                toastManager.show(error, style: .error, duration: 6.0)
            }
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

    // MARK: - Regular (Mac / iPad) — 3-column split view

    private var regularLayout: some View {
        #if os(macOS)
        macOSLayout
        #else
        iPadLayout
        #endif
    }

    #if os(macOS)
    private var macOSLayout: some View {
        Group {
            if showingDiscover {
                NavigationSplitView {
                    SiteSidebarView(selectedSite: $selectedSite, selectedTopicId: $selectedTopicId, showingDiscover: $showingDiscover)
                } detail: {
                    NavigationStack {
                        DiscoverSitesView(onSiteAdded: { site in
                            selectedSite = site
                            showingDiscover = false
                        }, selectedDiscoverSite: $selectedDiscoverSite)
                    }
                }
            } else {
                NavigationSplitView {
                    SiteSidebarView(selectedSite: $selectedSite, selectedTopicId: $selectedTopicId, showingDiscover: $showingDiscover)
                } content: {
                    if let site = selectedSite {
                        if site.loginRequired && !site.isAuthenticated {
                            LoginRequiredView(site: site)
                        } else {
                            TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
                                .id(site.baseURL)
                        }
                    } else {
                        ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                    }
                } detail: {
                    NavigationStack {
                        if let topicId = selectedTopicId, let site = selectedSite {
                            TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories)
                        } else {
                            Color.clear
                        }
                    }
                    .id(selectedTopicId)
                }
            }
        }
    }
    #endif

    #if os(iOS)
    private var iPadLayout: some View {
        Group {
            if showingDiscover {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SiteSidebarView(selectedSite: $selectedSite, selectedTopicId: $selectedTopicId, showingDiscover: $showingDiscover)
                } detail: {
                    NavigationStack {
                        DiscoverSitesView(onSiteAdded: { site in
                            selectedSite = site
                            showingDiscover = false
                        }, selectedDiscoverSite: $selectedDiscoverSite)
                    }
                }
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SiteSidebarView(selectedSite: $selectedSite, selectedTopicId: $selectedTopicId, showingDiscover: $showingDiscover)
                } content: {
                    if let site = selectedSite {
                        if site.loginRequired && !site.isAuthenticated {
                            LoginRequiredView(site: site)
                        } else {
                            TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
                        }
                    } else {
                        ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                    }
                } detail: {
                    NavigationStack {
                        if let topicId = selectedTopicId, let site = selectedSite {
                            TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories)
                        } else {
                            Color.clear
                        }
                    }
                    .id(selectedTopicId)
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
                    }, selectedDiscoverSite: $selectedDiscoverSite)
                }
        }
    }
}
