import SwiftUI

#if os(macOS)
import Markdown
#endif

struct PostView: View {
    let post: Post
    let baseURL: String
    let markdown: String?
    var contentWidth: CGFloat = 0
    var isLiked: Bool = false
    var isWhisper: Bool = false
    var currentTopicId: Int = 0
    var avatarLookup: [String: String] = [:]
    var onLike: (() async -> Void)?
    var onQuote: ((String) -> Void)?
    var onScrollToPost: ((Int) -> Void)?

    @State private var isLiking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + username + date
            HStack(spacing: Theme.Spacing.postHeaderHorizontal) {
                CachedAsyncImage(
                    url: URLHelpers.avatarURL(template: post.avatarTemplate, size: Theme.Avatar.postFetch, baseURL: baseURL)
                ) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: Theme.Avatar.postDisplay, height: Theme.Avatar.postDisplay)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.postAuthorVertical) {
                    HStack(spacing: Theme.Spacing.postNameItems) {
                        Text(post.name ?? post.username ?? "Unknown")
                            .font(Theme.Fonts.postAuthorName)
                        if post.staff == true {
                            Image(systemName: "shield.fill")
                                .font(Theme.Fonts.metadataSmall)
                                .foregroundStyle(.blue)
                        }
                    }
                    if let username = post.username {
                        Text("@\(username)")
                            .font(Theme.Fonts.metadata)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if isWhisper {
                    Image(systemName: Theme.Whisper.iconName)
                        .font(Theme.Whisper.iconFont)
                        .foregroundStyle(Theme.Whisper.iconColor)
                }

                HStack(spacing: 4) {
                    RelativeTimeText(dateString: post.createdAt)
                    if let pn = post.postNumber {
                        Text("·")
                        Text("#\(pn)")
                    }
                }
                .font(Theme.Fonts.metadata)
                .foregroundStyle(.secondary)
            }

            Spacer().frame(height: Theme.Spacing.postHeaderToBody)

            // Content
            if let md = markdown {
                #if os(macOS)
                MarkdownNSTextView(
                    markdown: md,
                    contentWidth: contentWidth > 0 ? contentWidth : nil
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    if let onQuote {
                        Button {
                            let plainText = md
                                .replacing(/!\[.*?\]\(.*?\)/, with: "[image]")
                            onQuote(plainText)
                        } label: {
                            Label("Quote in Reply", systemImage: "text.quote")
                        }
                    }
                }
                #else
                Text(md)
                    .font(Theme.Fonts.postBody)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contextMenu {
                        if let onQuote {
                            Button {
                                let plainText = md
                                    .replacing(/!\[.*?\]\(.*?\)/, with: "[image]")
                                onQuote(plainText)
                            } label: {
                                Label("Quote in Reply", systemImage: "text.quote")
                            }
                        }
                    }
                #endif
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            Spacer().frame(height: Theme.Spacing.postBodyToFooter)

            // Footer: likes + replies
            HStack(spacing: Theme.Spacing.postFooterHorizontal) {
                if let onLike {
                    Button {
                        guard !isLiking else { return }
                        isLiking = true
                        Task {
                            await onLike()
                            isLiking = false
                        }
                    } label: {
                        Label(
                            "\(likeCountDisplay)",
                            systemImage: isLiked ? "heart.fill" : "heart"
                        )
                        .foregroundStyle(isLiked ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLiking)
                    #if os(macOS)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    #endif
                } else if post.likeCount > 0 {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .foregroundStyle(.secondary)
                }

                if let replies = post.replyCount, replies > 0 {
                    Label("\(replies)", systemImage: "arrowshape.turn.up.left")
                        .foregroundStyle(.secondary)
                }
            }
            .font(Theme.Fonts.statCount)
            .imageScale(.large)
        }
        .padding(.vertical, Theme.Padding.postVertical)
        .padding(.horizontal, Theme.Padding.postHorizontal(for: contentWidth))
        .opacity(isWhisper ? Theme.Whisper.postOpacity : 1.0)
    }

    private var likeCountDisplay: String {
        var count = post.likeCount
        if isLiked && !post.hasLiked { count += 1 }
        if !isLiked && post.hasLiked { count -= 1 }
        return count > 0 ? "\(count)" : ""
    }
}

// MARK: - macOS Rich Markdown View

#if os(macOS)
import Nuke

private struct MarkdownNSTextView: NSViewRepresentable {
    let markdown: String
    let contentWidth: CGFloat?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage()
        let layoutManager = QuoteBarLayoutManager()
        let textContainer = NSTextContainer()
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = true

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.textContainerInset = .zero
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        applyMarkdown(to: textView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Only re-render if markdown changed
        if context.coordinator.lastMarkdown != markdown {
            applyMarkdown(to: textView, coordinator: context.coordinator)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let textView = nsView.documentView as? NSTextView else { return nil }
        let width = effectiveWidth(from: proposal)
        textView.textContainer?.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        return CGSize(width: width, height: ceil(usedRect.height))
    }

    private func effectiveWidth(from proposal: ProposedViewSize? = nil) -> CGFloat {
        if let w = contentWidth, w > 0 {
            // Subtract horizontal padding so text doesn't overflow
            let padding = Theme.Padding.postHorizontal(for: w) * 2
            return w - padding
        }
        return proposal?.width ?? 400
    }

    private func applyMarkdown(to textView: NSTextView, coordinator: Coordinator) {
        coordinator.cancelImageLoads()
        coordinator.lastMarkdown = markdown

        let document = Document(parsing: markdown)
        let width = effectiveWidth()
        var renderer = Markdownosaur(maxImageWidth: width)
        let attributed = renderer.attributedString(from: document)
        textView.textStorage?.setAttributedString(attributed)
        textView.textContainer?.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)

        loadInlineImages(in: textView, coordinator: coordinator)
    }

    private func loadInlineImages(in textView: NSTextView, coordinator: Coordinator) {
        guard let attrText = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: attrText.length)

        attrText.enumerateAttribute(.attachment, in: fullRange, options: []) { value, _, _ in
            guard let attachment = value as? ScalableImageAttachment,
                  let urlString = attachment.imageURL,
                  let url = URL(string: urlString) else { return }

            let task = ImagePipeline.shared.loadImage(with: url) { result in
                if case .success(let response) = result {
                    DispatchQueue.main.async {
                        attachment.image = response.image
                        // Force redraw
                        let current = NSAttributedString(attributedString: attrText)
                        textView.textStorage?.setAttributedString(current)
                    }
                }
            }
            coordinator.imageTasks.append(task)
        }
    }

    final class Coordinator {
        var lastMarkdown: String?
        var imageTasks: [ImageTask] = []

        func cancelImageLoads() {
            imageTasks.forEach { $0.cancel() }
            imageTasks.removeAll()
        }
    }
}
#endif
