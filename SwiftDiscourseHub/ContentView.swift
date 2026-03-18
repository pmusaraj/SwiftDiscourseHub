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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AuthCoordinator.self) private var authCoordinator
    @Environment(ToastManager.self) private var toastManager

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
    private var hasDiscoverDetail: Bool { showingDiscover && selectedDiscoverSite != nil }
    private var hasRightPanel: Bool { hasDetail || hasDiscoverDetail }

    private var toolbarBottomShadow: some View {
        LinearGradient(
            colors: [Theme.PanelShadow.shadowColor.opacity(Theme.Toolbar.bottomShadowOpacity), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Theme.Toolbar.bottomShadowHeight)
        .allowsHitTesting(false)
    }

    private var macOSLayout: some View {
        HStack(spacing: 0) {
            SiteSidebarView(selectedSite: $selectedSite, selectedTopicId: $selectedTopicId, showingDiscover: $showingDiscover)
                .background(.background)
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [Theme.PanelShadow.shadowColor.opacity(Theme.PanelShadow.shadowOpacity), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: Theme.PanelShadow.width)
                    .offset(x: Theme.PanelShadow.width)
                    .allowsHitTesting(false)
                }
                .zIndex(2)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    NavigationStack {
                        Group {
                            if showingDiscover {
                                DiscoverSitesView(onSiteAdded: { site in
                                    selectedSite = site
                                    showingDiscover = false
                                }, selectedDiscoverSite: $selectedDiscoverSite)
                            } else if let site = selectedSite {
                                if site.loginRequired && !site.isAuthenticated {
                                    LoginRequiredView(site: site)
                                } else {
                                    TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
                                        .id(site.baseURL)
                                        .transition(.opacity)
                                }
                            } else {
                                ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedSite?.baseURL)
                    }
                    .overlay(alignment: .top) { toolbarBottomShadow }
                    .background(.background)
                    .overlay(alignment: .trailing) {
                        if hasRightPanel {
                            LinearGradient(
                                colors: [Theme.PanelShadow.shadowColor.opacity(Theme.PanelShadow.shadowOpacity), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: Theme.PanelShadow.width)
                            .offset(x: Theme.PanelShadow.width)
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(width: hasRightPanel ? geo.size.width / 3 : geo.size.width)
                    .zIndex(1)

                    if hasDetail {
                        if let topicId = selectedTopicId, let site = selectedSite {
                            NavigationStack {
                                TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories)
                            }
                            .overlay(alignment: .top) { toolbarBottomShadow }
                            .frame(maxWidth: .infinity)
                            .id(topicId)
                        }
                    } else if hasDiscoverDetail {
                        if let discoverSite = selectedDiscoverSite {
                            NavigationStack {
                                DiscoverSiteDetailView(site: discoverSite, onSiteAdded: { site in
                                    selectedSite = site
                                    showingDiscover = false
                                })
                            }
                            .overlay(alignment: .top) { toolbarBottomShadow }
                            .frame(maxWidth: .infinity)
                            .id(discoverSite.id)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: hasRightPanel)
            }
        }
    }
    #endif

    #if os(iOS)
    private var iPadLayout: some View {
        NavigationSplitView {
            SiteSidebarView(selectedSite: $selectedSite, selectedTopicId: $selectedTopicId, showingDiscover: $showingDiscover)
        } content: {
            if showingDiscover {
                DiscoverSitesView(onSiteAdded: { site in
                    selectedSite = site
                    showingDiscover = false
                }, selectedDiscoverSite: $selectedDiscoverSite)
            } else if let site = selectedSite {
                if site.loginRequired && !site.isAuthenticated {
                    LoginRequiredView(site: site)
                } else {
                    TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories)
                }
            } else {
                ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
            }
        } detail: {
            if let topicId = selectedTopicId, let site = selectedSite {
                TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories)
            } else if showingDiscover, let discoverSite = selectedDiscoverSite {
                DiscoverSiteDetailView(site: discoverSite, onSiteAdded: { site in
                    selectedSite = site
                    showingDiscover = false
                })
            } else {
                ContentUnavailableView("Select a Topic", systemImage: "text.bubble", description: Text("Choose a topic from the list"))
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
