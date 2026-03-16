import SwiftUI

struct TopicListView: View {
    let site: DiscourseSite
    @Binding var selectedTopicId: Int?
    @State private var topicVM = TopicListViewModel()
    @State private var categoryVM = CategoryListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TopicFilterBar(viewModel: topicVM)
                .padding(.vertical, 8)

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
                .padding(.bottom, 4)
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
        .task(id: site.baseURL) {
            await topicVM.loadTopics(for: site)
            await categoryVM.loadCategories(for: site)
        }
        .onChange(of: topicVM.filter) {
            topicVM.clearCategory()
            Task { await topicVM.loadTopics(for: site) }
        }
    }

    func selectedTopic() -> Topic? {
        guard let id = selectedTopicId else { return nil }
        return topicVM.topics.first { $0.id == id }
    }
}
