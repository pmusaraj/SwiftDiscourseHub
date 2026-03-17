import SwiftUI

struct CategoryBadgeView: View {
    let name: String
    let color: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.categoryBadgeHorizontal) {
            Circle()
                .fill(Color(hex: color ?? Theme.CategoryBadge.defaultColor))
                .frame(width: Theme.CategoryBadge.dotSize, height: Theme.CategoryBadge.dotSize)
            Text(name)
                .font(Theme.Fonts.metadata)
                .lineLimit(Theme.LineLimit.categoryName)
        }
        .padding(.horizontal, Theme.Padding.categoryBadgeHorizontal)
        .padding(.vertical, Theme.Padding.categoryBadgeVertical)
        .background(Color(hex: color ?? Theme.CategoryBadge.defaultColor).opacity(Theme.CategoryBadge.backgroundOpacity))
        .clipShape(Capsule())
    }
}
