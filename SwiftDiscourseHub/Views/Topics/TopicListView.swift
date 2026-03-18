import SwiftUI

struct TopicListView: View {
    let site: DiscourseSite
    @Binding var selectedTopicId: Int?
    @Binding var selectedTopic: Topic?
    @Binding var topicCategories: [DiscourseCategory]
    @Environment(\.apiClient) private var apiClient
    @State private var topicVM = TopicListViewModel()
    @State private var categoryVM = CategoryListViewModel()
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            TopicFilterBar(viewModel: topicVM, isAuthenticated: site.isAuthenticated)
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

            Group {
                if topicVM.isLoading && topicVM.topics.isEmpty {
                    ProgressView("Loading topics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = topicVM.error, topicVM.topics.isEmpty {
                    ErrorStateView(title: "Failed to Load", message: error.localizedDescription) {
                        Task { await topicVM.loadTopics(for: site) }
                    }
                } else if topicVM.topics.isEmpty {
                    ContentUnavailableView("No Topics", systemImage: "text.bubble", description: Text("No topics found"))
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
            topicVM.apiClient = apiClient
            categoryVM.apiClient = apiClient
            await topicVM.loadTopics(for: site)
            await categoryVM.loadCategories(for: site)
            topicCategories = categoryVM.categories
        }
        .onChange(of: topicVM.filter) {
            topicVM.clearCategory()
            Task { await topicVM.loadTopics(for: site) }
        }
        .onChange(of: selectedTopicId) {
            selectedTopic = topicVM.topics.first { $0.id == selectedTopicId }
        }
    }
}
