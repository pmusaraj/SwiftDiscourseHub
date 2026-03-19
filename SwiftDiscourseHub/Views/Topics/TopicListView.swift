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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                TopicFilterBar(viewModel: topicVM, isAuthenticated: site.isAuthenticated)

                Spacer()

                SiteIconView(site: site, isSelected: true)
                    .frame(width: 28, height: 28)
            }
            .padding(.vertical, Theme.Padding.topicFilterVertical)
            .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))

            if let selectedSlug = topicVM.selectedCategorySlug,
               let cat = categoryVM.categories.first(where: { $0.slug == selectedSlug }) {
                HStack {
                    CategoryBadgeView(name: cat.name ?? selectedSlug, color: cat.color)
                    Button {
                        topicVM.clearCategory()
                        Task { await topicVM.loadTopics(for: site) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
                .padding(.bottom, Theme.Padding.categoryFilterBottom)
            }

            if !initialLoadComplete {
                Spacer()
                ProgressView("Loading topics...")
                Spacer()
            } else if let error = topicVM.error, topicVM.topics.isEmpty {
                Spacer()
                ErrorStateView(title: "Failed to Load", message: error.localizedDescription) {
                    Task { await topicVM.loadTopics(for: site) }
                }
                Spacer()
            } else if topicVM.topics.isEmpty {
                Spacer()
                ContentUnavailableView("No Topics", systemImage: "text.bubble", description: Text("No topics found"))
                Spacer()
            } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(topicVM.topics) { topic in
                                Button {
                                    selectedTopicId = topic.id
                                } label: {
                                    TopicRowView(
                                        topic: topic,
                                        users: topicVM.users,
                                        categories: categoryVM.categories,
                                        baseURL: site.baseURL
                                    )
                                    .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
                                    .contentShape(Rectangle())
                                    .background(selectedTopicId == topic.id ? Color.accentColor.opacity(Theme.Selection.highlightOpacity) : .clear)
                                }
                                .buttonStyle(.plain)
                                #if os(iOS)
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
                                #endif
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
                                    .padding()
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    .refreshable {
                        await topicVM.loadTopics(for: site)
                    }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            contentWidth = newWidth
        }
        .navigationTitle("")
        #if os(macOS)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 600)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .task(id: site.baseURL) {
            initialLoadComplete = false
            topicVM.apiClient = apiClient
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
            topicVM.clearCategory()
            Task { await topicVM.loadTopics(for: site) }
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
}
