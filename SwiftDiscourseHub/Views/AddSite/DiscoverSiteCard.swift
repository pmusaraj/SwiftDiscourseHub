import SwiftUI

struct DiscoverSiteCard: View {
    let site: DiscoverSite
    let isAdded: Bool
    let strippedExcerpt: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .font(Theme.Fonts.postBody)
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(strippedExcerpt.isEmpty ? 0 : 1)

            HStack(spacing: 16) {
                if let users = site.activeUsers30Days, users > 0 {
                    Label {
                        Text("\(Self.roundedStat(users)) active users")
                    } icon: {
                        Image(systemName: "person.2")
                    }
                }
                if let topics = site.topics30Days, topics > 0 {
                    Label {
                        Text("\(Self.roundedStat(topics)) recent topics")
                    } icon: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                }
            }
            .font(Theme.Fonts.discoverSiteStats)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
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

    static func roundedStat(_ value: Int) -> String {
        switch value {
        case ..<10: return "\(value)"
        case ..<100:
            let base = (value / 10) * 10
            return "\(base)+"
        case ..<1000:
            let base = (value / 100) * 100
            return "\(base)+"
        default:
            let base = (value / 1000) * 1000
            return "\(base)+"
        }
    }
}
