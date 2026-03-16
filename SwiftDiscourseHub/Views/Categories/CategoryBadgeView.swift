import SwiftUI

struct CategoryBadgeView: View {
    let name: String
    let color: String?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: color ?? "808080"))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(hex: color ?? "808080").opacity(0.1))
        .clipShape(Capsule())
    }
}
