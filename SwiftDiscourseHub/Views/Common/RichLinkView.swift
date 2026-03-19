import SwiftUI

private enum WellKnownSite {
    case gitHub, wikipedia, amazon, reddit, hackerNews, google

    init?(domain: String) {
        if domain.hasSuffix("github.com") { self = .gitHub }
        else if domain.hasSuffix("wikipedia.org") { self = .wikipedia }
        else if domain.hasSuffix("amazon.com") || domain.hasSuffix("amazon.co.uk") { self = .amazon }
        else if domain.hasSuffix("reddit.com") { self = .reddit }
        else if domain == "news.ycombinator.com" { self = .hackerNews }
        else if domain.hasSuffix("google.com") || domain.hasSuffix("docs.google.com") { self = .google }
        else { return nil }
    }
}

struct RichLinkView: View {
    let info: OneboxInfo

    private var wellKnownSite: WellKnownSite? {
        WellKnownSite(domain: info.domain)
    }

    var body: some View {
        Button {
            if let url = URL(string: info.url) {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL = info.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.08)
                            .frame(height: 160)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        siteIcon

                        Text(info.siteName ?? info.domain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let title = info.title {
                        Text(title)
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    if let description = info.description {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(.gray.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        #endif
    }

    @ViewBuilder
    private var siteIcon: some View {
        switch wellKnownSite {
        case .gitHub:
            Image("GitHubMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
        case .wikipedia:
            Image(systemName: "book.closed.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .amazon:
            Image(systemName: "cart.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .reddit:
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .hackerNews:
            Image(systemName: "y.square.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .google:
            Image(systemName: "doc.text.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case nil:
            if let faviconURL = info.faviconURL, let url = URL(string: faviconURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "globe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 16, height: 16)
            } else {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
