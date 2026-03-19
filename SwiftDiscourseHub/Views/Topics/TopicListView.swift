import SwiftUI

struct TopicListView: View {
    let site: DiscourseSite
    @Binding var selectedTopicId: Int?
    @Binding var selectedTopic: Topic?
    @Binding var topicCategories: [DiscourseCategory]
    @Bindable var topicVM: TopicListViewModel
    @Environment(\.apiClient) private var apiClient
    @State private var categoryVM = CategoryListViewModel()
    @State private var contentWidth: CGFloat = 0
    @State private var initialLoadComplete = false

    private var topCategories: [DiscourseCategory] {
        categoryVM.categories
            .filter { $0.parentCategoryId == nil }
            .sorted { ($0.topicCount ?? 0) > ($1.topicCount ?? 0) }
            .prefix(10)
            .map { $0 }
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            TopicFilterBar(
                viewModel: topicVM,
                isAuthenticated: site.isAuthenticated,
                onBuiltInSelected: {
                    Task { await topicVM.loadTopics(for: site) }
                },
                onCategorySelected: { cat in
                    selectCategory(cat)
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            #if os(macOS)
            siteMenu
            #endif
        }
        .padding(.vertical, Theme.Padding.topicFilterVertical)
        .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
        .background(.ultraThinMaterial)
    }

    var body: some View {
        Group {
            if !initialLoadComplete {
                VStack {
                    Spacer()
                    ProgressView("Loading topics...")
                    Spacer()
                }
            } else if let error = topicVM.error, topicVM.topics.isEmpty {
                VStack {
                    Spacer()
                    ErrorStateView(title: "Failed to Load", message: error.localizedDescription) {
                        Task { await topicVM.loadTopics(for: site) }
                    }
                    Spacer()
                }
            } else if topicVM.topics.isEmpty {
                ScrollView {
                    Spacer().frame(height: 100)
                    ContentUnavailableView("No Topics", systemImage: "text.bubble", description: Text("No topics found"))
                }
                .safeAreaInset(edge: .top) {
                    filterBar
                }
            } else {
                List {
                    ForEach(topicVM.topics) { topic in
                        Button {
                            selectedTopicId = topic.id
                        } label: {
                            TopicRowView(
                                topic: topic,
                                users: topicVM.users,
                                categories: categoryVM.categories,
                                baseURL: site.baseURL,
                                contentWidth: contentWidth
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(
                            top: 0, leading: Theme.Padding.postHorizontal(for: contentWidth),
                            bottom: 0, trailing: Theme.Padding.postHorizontal(for: contentWidth)
                        ))
                        .listRowBackground(
                            selectedTopicId == topic.id
                                ? Color.accentColor.opacity(Theme.Selection.highlightOpacity)
                                : Color.clear
                        )
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            if topicVM.filter == .new && site.isAuthenticated {
                                Button {
                                    Task { await topicVM.dismissNewTopic(topic.id, site: site) }
                                } label: {
                                    Label("Mark as Read", systemImage: "envelope.open")
                                }
                                .tint(.blue)
                            }
                        }
                        .contextMenu {
                            if topicVM.filter == .new && site.isAuthenticated {
                                Button {
                                    Task { await topicVM.dismissNewTopic(topic.id, site: site) }
                                } label: {
                                    Label("Mark as Read", systemImage: "envelope.open")
                                }
                            }
                        }
                        .onAppear {
                            if topic.id == topicVM.topics.last?.id {
                                Task { await topicVM.loadMore(for: site) }
                            }
                        }
                    }
                    if topicVM.isLoading && !topicVM.topics.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.never)
                .refreshable {
                    await topicVM.loadTopics(for: site)
                }
                .safeAreaInset(edge: .top) {
                    filterBar
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            contentWidth = newWidth
        }
        .navigationTitle("")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                siteMenu
            }
        }
        #endif
        #if os(macOS)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar(removing: .title)
        .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 600)
        #endif
        .task(id: site.baseURL) {
            initialLoadComplete = false
            topicVM.apiClient = apiClient
            topicVM.switchSite(to: site.baseURL)
            categoryVM.apiClient = apiClient
            await categoryVM.loadCategories(for: site)
            topicCategories = categoryVM.categories
            await topicVM.loadTopics(for: site)
            initialLoadComplete = true
            if selectedTopicId == nil, let first = topicVM.topics.first {
                selectedTopicId = first.id
            }
        }
        .onChange(of: topicVM.filter) {
            if !topicVM.isShowingCategory {
                Task { await topicVM.loadTopics(for: site) }
            }
        }
        .onChange(of: selectedTopicId) {
            selectedTopic = topicVM.topics.first { $0.id == selectedTopicId }
        }
        .onReceive(NotificationCenter.default.publisher(for: .topicWasRead)) { notification in
            if let topicId = notification.userInfo?["topicId"] as? Int {
                topicVM.removeReadTopic(topicId)
            }
        }
    }

    // MARK: - Site Menu

    private var siteMenu: some View {
        Menu {
            Section("Filters") {
                ForEach(TopicFilter.allCases, id: \.self) { filter in
                    if filter == .new && !site.isAuthenticated { } else {
                        let isEnabled = !topicVM.hiddenBuiltInFilters.contains(filter)
                        Button {
                            if isEnabled {
                                topicVM.hiddenBuiltInFilters.insert(filter)
                            } else {
                                topicVM.hiddenBuiltInFilters.remove(filter)
                            }
                        } label: {
                            Label(filter.rawValue, systemImage: isEnabled ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            }

            Section("Categories") {
                ForEach(topCategories) { cat in
                    let isPinned = topicVM.pinnedCategories.contains { $0.id == cat.id }
                    Button {
                        if isPinned {
                            topicVM.removePinnedCategory(cat.id)
                        } else {
                            topicVM.addPinnedCategory(cat)
                            selectCategory(cat)
                        }
                    } label: {
                        Label(cat.name ?? "Unknown", systemImage: isPinned ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
        } label: {
            #if os(macOS)
            Image(systemName: "line.3.horizontal.decrease.circle")
            #else
            SiteIconView(site: site, isSelected: true)
                .frame(width: 24, height: 24)
            #endif
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .fixedSize()
        #endif
    }

    // MARK: - Helpers

    private func selectCategory(_ cat: DiscourseCategory) {
        topicVM.selectCategory(slug: cat.slug ?? "", id: cat.id)
        Task { await topicVM.loadTopics(for: site) }
    }
}
