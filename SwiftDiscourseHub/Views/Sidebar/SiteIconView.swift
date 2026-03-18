import SwiftUI

struct SiteIconView: View {
    let site: DiscourseSite
    let isSelected: Bool

    private var iconURL: URL? {
        URLHelpers.resolveURL(site.iconURL, baseURL: site.baseURL)
    }

    private var fallbackLetter: String {
        String(site.title.prefix(1)).uppercased()
    }

    var body: some View {
        CachedAsyncImage(url: iconURL) { image in
            image.resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Sidebar.iconCornerRadius)
                    .fill(.secondary.opacity(Theme.Sidebar.iconFallbackOpacity))
                Text(fallbackLetter)
                    .font(Theme.Fonts.siteIconFallback)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Theme.Sidebar.iconSize, height: Theme.Sidebar.iconSize)
        .clipShape(.rect(cornerRadius: Theme.Sidebar.iconCornerRadius))
    }
}
