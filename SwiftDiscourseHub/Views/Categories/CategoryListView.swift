import SwiftUI

struct CategoryListView: View {
    let site: DiscourseSite
    let categories: [DiscourseCategory]
    let topicVM: TopicListViewModel

    private var topLevelCategories: [DiscourseCategory] {
        categories.filter { $0.parentCategoryId == nil }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                ForEach(topLevelCategories) { category in
                    Button {
                        if let slug = category.slug {
                            topicVM.selectCategory(slug: slug, id: category.id)
                            Task { await topicVM.loadTopics(for: site) }
                        }
                    } label: {
                        CategoryCardView(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Categories")
    }
}
