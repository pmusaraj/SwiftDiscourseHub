import SwiftUI

struct DiscoverSiteRow: View {
    let site: DiscoverSite
    let isAdded: Bool
    let isSelected: Bool
    let strippedExcerpt: String
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Logo
            if let logoUrl = site.logoUrl, let url = URL(string: logoUrl.hasPrefix("//") ? "https:\(logoUrl)" : logoUrl),
               !logoUrl.hasSuffix(".svg") && !logoUrl.hasSuffix(".webp") {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    siteLetterIcon
                }
                .frame(width: Theme.Discover.siteIconSize, height: Theme.Discover.siteIconSize)
                .clipShape(.rect(cornerRadius: Theme.Discover.siteIconCornerRadius))
            } else {
                siteLetterIcon
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(site.title)
                    .font(Theme.Fonts.discoverSiteTitle)
                    .lineLimit(1)

                if !strippedExcerpt.isEmpty {
                    Text(strippedExcerpt)
                        .font(Theme.Fonts.discoverSiteDescription)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let users = site.activeUsers30Days, users > 0 {
                    Label("\(users) active users", systemImage: "person.2")
                        .font(Theme.Fonts.discoverSiteStats)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(Theme.Discover.actionIconFont)
            } else {
                Button("Add Site", systemImage: "plus.circle", action: onAdd)
                    .labelStyle(.iconOnly)
                    .font(Theme.Discover.actionIconFont)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.Padding.topicRowVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var siteLetterIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Discover.siteIconCornerRadius)
                .fill(.secondary.opacity(Theme.Sidebar.iconFallbackOpacity))
            Text(String(site.title.prefix(1)).uppercased())
                .font(Theme.Fonts.siteIconFallback)
                .foregroundStyle(.secondary)
        }
        .frame(width: Theme.Discover.siteIconSize, height: Theme.Discover.siteIconSize)
    }
}
