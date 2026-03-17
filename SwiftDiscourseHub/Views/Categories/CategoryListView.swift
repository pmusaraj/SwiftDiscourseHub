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

struct CategoryCardView: View {
    let category: DiscourseCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(hex: category.color ?? "808080"))
                    .frame(width: 12, height: 12)
                Text(category.name ?? "Unnamed")
                    .font(Theme.Fonts.categoryListTitle)
                Spacer()
                if let count = category.topicCount {
                    Text("\(count) topics")
                        .font(Theme.Fonts.categoryListStats)
                        .foregroundStyle(.secondary)
                }
            }
            if let desc = category.descriptionText, !desc.isEmpty {
                Text(desc)
                    .font(Theme.Fonts.categoryListDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(hex: category.color ?? "808080").opacity(0.3), lineWidth: 2)
        )
    }
}
