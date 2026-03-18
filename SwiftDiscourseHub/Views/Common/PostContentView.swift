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

            PostContentView(markdown: quote.content, baseURL: baseURL)
        }
        .padding(12)
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
