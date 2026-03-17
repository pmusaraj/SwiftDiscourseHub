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
                RoundedRectangle(cornerRadius: 12)
                    .fill(.secondary.opacity(0.2))
                Text(fallbackLetter)
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
        .help(site.title)
    }
}
