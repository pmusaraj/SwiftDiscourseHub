import SwiftUI

struct TopicFilterBar: View {
    @Bindable var viewModel: TopicListViewModel
    var isAuthenticated: Bool = false
    var onBuiltInSelected: (() -> Void)? = nil
    var onCategorySelected: ((DiscourseCategory) -> Void)? = nil

    private var builtInFilters: [TopicFilter] {
        TopicFilter.allCases.filter { filter in
            if filter == .new && !isAuthenticated { return false }
            return !viewModel.hiddenBuiltInFilters.contains(filter)
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(builtInFilters, id: \.self) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        isSelected: !viewModel.isShowingCategory && viewModel.filter == filter
                    ) {
                        let wasShowingCategory = viewModel.isShowingCategory
                        viewModel.clearCategory()
                        if viewModel.filter == filter && wasShowingCategory {
                            onBuiltInSelected?()
                        } else {
                            viewModel.filter = filter
                        }
                    }
                }

                if !viewModel.pinnedCategories.isEmpty {
                    dividerDot
                }

                ForEach(viewModel.pinnedCategories) { cat in
                    FilterChip(
                        label: cat.name ?? "Unknown",
                        color: cat.color,
                        isSelected: viewModel.selectedCategoryId == cat.id
                    ) {
                        onCategorySelected?(cat)
                    } onRemove: {
                        viewModel.removePinnedCategory(cat.id)
                    }
                }
            }
        }
        .scrollIndicators(.never)
    }

    private var dividerDot: some View {
        Circle()
            .fill(.quaternary)
            .frame(width: 4, height: 4)
    }
}

private struct FilterChip: View {
    let label: String
    var color: String? = nil
    let isSelected: Bool
    let action: () -> Void
    var onRemove: (() -> Void)? = nil

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 8, height: 8)
                }
                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove Filter", systemImage: "minus.circle")
                }
            }
        }
    }
}
