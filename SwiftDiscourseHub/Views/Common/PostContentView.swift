import AVKit
import SwiftUI
import Textual

struct PostContentView: View {
    let markdown: String
    let baseURL: String

    private var siteBaseURL: URL? { URL(string: baseURL) }

    var body: some View {
        StructuredText(markdown: markdown, baseURL: siteBaseURL)
            .textual.structuredTextStyle(DiscourseStyle())
            .textual.imageAttachmentLoader(.image(relativeTo: siteBaseURL))
            .textual.textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
                return .handled
            })
    }
}

struct RichLinkView: View {
    let info: OneboxInfo

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
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(.gray.opacity(0.08))
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
}

struct QuoteBlockView: View {
    let quote: QuoteInfo
    let baseURL: String
    let avatarURL: URL?
    let currentTopicId: Int
    var onScrollToPost: ((Int) -> Void)?

    private var isCrossTopic: Bool {
        guard let topicId = quote.topicId else { return false }
        return topicId != currentTopicId
    }

    var body: some View {
        Group {
            if isCrossTopic, let topicId = quote.topicId {
                NavigationLink(value: LinkedTopicDestination(topicId: topicId)) {
                    quoteContent
                }
                .buttonStyle(.plain)
            } else if let postNumber = quote.postNumber, onScrollToPost != nil {
                quoteContent
                    .onTapGesture { onScrollToPost?(postNumber) }
            } else {
                quoteContent
            }
        }
    }

    private var quoteContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !quote.username.isEmpty {
                HStack(spacing: 6) {
                    CachedAsyncImage(url: avatarURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())

                    Text("\(quote.username):")
                        .font(.subheadline.bold())

                    Spacer()

                    if isCrossTopic || quote.postNumber != nil {
                        Image(systemName: isCrossTopic ? "arrow.up.right" : "arrow.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            PostContentView(markdown: quote.content, baseURL: baseURL)
        }
        .padding(12)
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PostVideoPlayerView: View {
    let urlString: String

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .task {
                guard player == nil, let url = URL(string: urlString) else { return }
                // Resolve the final URL through a HEAD request in case of redirects
                // that AVPlayer doesn't follow well (e.g. Discourse short-url 302s)
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"
                if let (_, response) = try? await URLSession.shared.data(for: request),
                   let finalURL = response.url, finalURL != url {
                    player = AVPlayer(url: finalURL)
                } else {
                    player = AVPlayer(url: url)
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
