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
    @State private var topicVM = TopicListViewModel()
    @State private var showKeyboardHelp = false
    #if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var keyMonitor: Any?
    @State private var pendingGPrefix = false
    @State private var gPrefixTask: Task<Void, Never>?
    #else
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var preComposerVisibility: NavigationSplitViewVisibility?
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AuthCoordinator.self) private var authCoordinator
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.apiClient) private var apiClient

    private var hasSites: Bool { !sites.isEmpty }

    // TODO: Re-enable jump to last read post
    // private var nextUnreadPostNumber: Int? {
    //     guard let site = selectedSite, site.isAuthenticated,
    //           let lastRead = selectedTopic?.lastReadPostNumber, lastRead > 0 else { return nil }
    //     return lastRead + 1
    // }
    private var nextUnreadPostNumber: Int? { nil }

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
        .sheet(isPresented: $showKeyboardHelp) {
            KeyboardShortcutHelpView()
        }
        #if os(macOS)
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
        #endif
        .onChange(of: selectedSite?.baseURL) {
            selectedTopicId = nil
            selectedTopic = nil
        }
        .onChange(of: showingDiscover) {
            if !showingDiscover {
                selectedDiscoverSite = nil
            }
            #if os(macOS)
            columnVisibility = showingDiscover ? .doubleColumn : .all
            #else
            columnVisibility = showingDiscover ? .detailOnly : .doubleColumn
            #endif
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
                        if let user = try? await apiClient.fetchCurrentUser(baseURL: baseURL) {
                            site.username = user.username
                            site.avatarTemplate = user.avatarTemplate
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
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: .composerDidShow)) { _ in
            preComposerVisibility = columnVisibility
            withAnimation { columnVisibility = .detailOnly }
        }
        .onReceive(NotificationCenter.default.publisher(for: .composerDidHide)) { _ in
            if let saved = preComposerVisibility {
                withAnimation { columnVisibility = saved }
                preComposerVisibility = nil
            }
        }
        #endif
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
                            TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories, topicVM: topicVM)
                                .id(site.baseURL)
                        }
                    } else {
                        ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                    }
                } detail: {
                    NavigationStack {
                        if let topicId = selectedTopicId, let site = selectedSite {
                            TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories, startPostNumber: nextUnreadPostNumber)
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
                            TopicListView(site: site, selectedTopicId: $selectedTopicId, selectedTopic: $selectedTopic, topicCategories: $topicCategories, topicVM: topicVM)
                        }
                    } else {
                        ContentUnavailableView("Select a Site", systemImage: "globe", description: Text("Choose a community from the sidebar"))
                    }
                } detail: {
                    NavigationStack {
                        if let topicId = selectedTopicId, let site = selectedSite {
                            TopicDetailView(topicId: topicId, site: site, topic: selectedTopic, categories: topicCategories, startPostNumber: nextUnreadPostNumber)
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

    // MARK: - Topic Navigation

    private func selectNextTopic() {
        guard !topicVM.topics.isEmpty else { return }
        if let current = selectedTopicId,
           let idx = topicVM.topics.firstIndex(where: { $0.id == current }),
           idx + 1 < topicVM.topics.count {
            selectedTopicId = topicVM.topics[idx + 1].id
        } else {
            selectedTopicId = topicVM.topics.first?.id
        }
    }

    private func selectPreviousTopic() {
        guard !topicVM.topics.isEmpty else { return }
        if let current = selectedTopicId,
           let idx = topicVM.topics.firstIndex(where: { $0.id == current }),
           idx > 0 {
            selectedTopicId = topicVM.topics[idx - 1].id
        }
    }

    private func selectNextSite() {
        guard !sites.isEmpty else { return }
        if let current = selectedSite,
           let idx = sites.firstIndex(where: { $0.id == current.id }),
           idx + 1 < sites.count {
            selectedSite = sites[idx + 1]
        } else {
            selectedSite = sites.first
        }
    }

    private func selectPreviousSite() {
        guard !sites.isEmpty else { return }
        if let current = selectedSite,
           let idx = sites.firstIndex(where: { $0.id == current.id }),
           idx > 0 {
            selectedSite = sites[idx - 1]
        }
    }

    // MARK: - Key Monitor (macOS)

    #if os(macOS)
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func isFirstResponderTextInput() -> Bool {
        KeyboardHelper.isTextInput(NSApp.keyWindow?.firstResponder)
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard !isFirstResponderTextInput() else {
            resetGPrefix()
            return event
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""

        // Arrow keys also set .numericPad and .function flags, so check .contains
        // Command + Arrow Down/Up: navigate topics
        if flags.contains(.command), !flags.contains(.shift), !flags.contains(.option), !flags.contains(.control) {
            if event.keyCode == 125 { // arrow down
                selectNextTopic()
                return nil
            } else if event.keyCode == 126 { // arrow up
                selectPreviousTopic()
                return nil
            }
        }

        // Option + Arrow Down/Up: navigate sites
        if flags.contains(.option), !flags.contains(.shift), !flags.contains(.command), !flags.contains(.control) {
            if event.keyCode == 125 { // arrow down
                selectNextSite()
                return nil
            } else if event.keyCode == 126 { // arrow up
                selectPreviousSite()
                return nil
            }
        }

        // Space / Shift+Space: scroll detail view
        if chars == " " && (flags == [] || flags == .shift) {
            if let scrollView = findDetailScrollView() {
                if flags.contains(.shift) {
                    scrollView.pageUp(nil)
                } else {
                    scrollView.pageDown(nil)
                }
            }
            return nil
        }

        // All remaining shortcuts require no modifiers (except shift for ?)
        guard flags == [] || (flags == .shift && chars == "?") else {
            resetGPrefix()
            return event
        }

        // Handle g-prefix second key
        if pendingGPrefix {
            resetGPrefix()
            switch chars {
            case "h":
                topicVM.clearCategory()
                topicVM.filter = .hot
                return nil
            case "n" where selectedSite?.isAuthenticated == true:
                topicVM.clearCategory()
                topicVM.filter = .new
                return nil
            case "l":
                topicVM.clearCategory()
                topicVM.filter = .latest
                return nil
            default:
                return event
            }
        }

        switch chars {
        case "g":
            pendingGPrefix = true
            gPrefixTask?.cancel()
            gPrefixTask = Task {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { pendingGPrefix = false }
            }
            return nil
        case "r":
            guard selectedSite?.hasApiKey == true, selectedTopicId != nil else { return event }
            NotificationCenter.default.post(name: .showReplyComposer, object: nil)
            return nil
        case "?":
            showKeyboardHelp.toggle()
            return nil
        default:
            return event
        }
    }

    private func findDetailScrollView() -> NSScrollView? {
        guard let contentView = NSApp.keyWindow?.contentView else { return nil }
        var scrollViews: [NSScrollView] = []
        collectScrollViews(in: contentView, into: &scrollViews)
        // The detail column's scroll view is the rightmost large one,
        // excluding per-post NSScrollViews wrapping NSTextView (from MarkdownNSTextView)
        return scrollViews
            .filter { sv in
                sv.frame.width > 200 && sv.frame.height > 200
                && !(sv.documentView is NSTextView)
            }
            .max(by: { $0.convert($0.bounds.origin, to: nil).x < $1.convert($1.bounds.origin, to: nil).x })
    }

    private func collectScrollViews(in view: NSView, into result: inout [NSScrollView]) {
        if let sv = view as? NSScrollView {
            result.append(sv)
        }
        for subview in view.subviews {
            collectScrollViews(in: subview, into: &result)
        }
    }

    private func resetGPrefix() {
        pendingGPrefix = false
        gPrefixTask?.cancel()
        gPrefixTask = nil
    }
    #endif
}
