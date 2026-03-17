import SwiftUI

struct TopicListView: View {
    let site: DiscourseSite
    @Binding var selectedTopicId: Int?
    @Binding var selectedTopic: Topic?
    @Binding var topicCategories: [DiscourseCategory]
    @State private var topicVM = TopicListViewModel()
    @State private var categoryVM = CategoryListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TopicFilterBar(viewModel: topicVM)
                .padding(.vertical, Theme.Padding.topicFilterVertical)

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
                .padding(.horizontal)
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
                    List(selection: $selectedTopicId) {
                        ForEach(topicVM.topics) { topic in
                            TopicRowView(
                                topic: topic,
                                users: topicVM.users,
                                categories: categoryVM.categories,
                                baseURL: site.baseURL
                            )
                            .tag(topic.id)
                            .listRowSeparator(.hidden)
                            .onAppear {
                                if topic.id == topicVM.topics.last?.id {
                                    Task { await topicVM.loadMore(for: site) }
                                }
                            }
                        }
                        if topicVM.isLoading && !topicVM.topics.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await topicVM.loadTopics(for: site)
                    }
                }
            }
        }
        .navigationTitle(site.title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .task(id: site.baseURL) {
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
