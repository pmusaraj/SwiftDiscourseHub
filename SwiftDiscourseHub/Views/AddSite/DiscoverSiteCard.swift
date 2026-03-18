import SwiftUI

struct DiscoverSiteCard: View {
    let site: DiscoverSite
    let isAdded: Bool
    let strippedExcerpt: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let logoUrl = site.logoUrl,
                   let url = URL(string: logoUrl.hasPrefix("//") ? "https:\(logoUrl)" : logoUrl),
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

                Text(site.title)
                    .font(Theme.Fonts.discoverSiteTitle)
                    .lineLimit(1)

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

            Text(strippedExcerpt.isEmpty ? " " : strippedExcerpt)
                .font(Theme.Fonts.discoverSiteDescription)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(strippedExcerpt.isEmpty ? 0 : 1)

            Label {
                Text(site.activeUsers30Days.map { "\($0) active users" } ?? " ")
            } icon: {
                Image(systemName: "person.2")
            }
            .font(Theme.Fonts.discoverSiteStats)
            .foregroundStyle(.secondary)
            .opacity(site.activeUsers30Days != nil && site.activeUsers30Days! > 0 ? 1 : 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(color: .primary.opacity(0.08), radius: 4, y: 2)
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
