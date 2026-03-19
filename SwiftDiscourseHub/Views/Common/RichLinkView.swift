import FontAwesomeSwiftUI
import SwiftUI

private enum WellKnownSite {
    case gitHub, wikipedia, amazon, reddit, hackerNews, google
    case youtube, twitter, facebook, apple, stackOverflow, discord, slack, linkedin

    init?(domain: String) {
        if domain.hasSuffix("github.com") { self = .gitHub }
        else if domain.hasSuffix("wikipedia.org") { self = .wikipedia }
        else if domain.hasSuffix("amazon.com") || domain.hasSuffix("amazon.co.uk") { self = .amazon }
        else if domain.hasSuffix("reddit.com") { self = .reddit }
        else if domain == "news.ycombinator.com" { self = .hackerNews }
        else if domain.hasSuffix("google.com") { self = .google }
        else if domain.hasSuffix("youtube.com") { self = .youtube }
        else if domain.hasSuffix("twitter.com") || domain.hasSuffix("x.com") { self = .twitter }
        else if domain.hasSuffix("facebook.com") { self = .facebook }
        else if domain.hasSuffix("apple.com") { self = .apple }
        else if domain.hasSuffix("stackoverflow.com") || domain.hasSuffix("stackexchange.com") { self = .stackOverflow }
        else if domain.hasSuffix("discord.com") || domain.hasSuffix("discord.gg") { self = .discord }
        else if domain.hasSuffix("slack.com") { self = .slack }
        else if domain.hasSuffix("linkedin.com") { self = .linkedin }
        else { return nil }
    }

    var icon: AwesomeIcon {
        switch self {
        case .gitHub: .github
        case .wikipedia: .wikipediaW
        case .amazon: .amazon
        case .reddit: .reddit
        case .hackerNews: .hackerNews
        case .google: .google
        case .youtube: .youtube
        case .twitter: .twitter
        case .facebook: .facebookF
        case .apple: .apple
        case .stackOverflow: .stackOverflow
        case .discord: .discord
        case .slack: .slack
        case .linkedin: .linkedinIn
        }
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
        if let site = wellKnownSite {
            Text(site.icon.rawValue)
                .font(.awesome(style: .brand, size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
        } else if let faviconURL = info.faviconURL, let url = URL(string: faviconURL) {
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
