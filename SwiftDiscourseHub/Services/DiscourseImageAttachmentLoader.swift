import SwiftUI
import Textual

struct PreSizedImageAttachment: Attachment, Hashable, Sendable {
    let url: URL
    let knownWidth: CGFloat
    let knownHeight: CGFloat

    var description: String { url.absoluteString }

    @MainActor var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            default:
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, in _: TextEnvironmentValues) -> CGSize {
        guard let proposedWidth = proposal.width else {
            return CGSize(width: knownWidth, height: knownHeight)
        }
        let aspect = knownWidth / knownHeight
        let width = min(proposedWidth, knownWidth)
        let height = width / aspect
        return CGSize(width: width, height: height)
    }
}

struct DiscourseImageAttachmentLoader: AttachmentLoader {
    let baseURL: URL?

    func attachment(
        for url: URL,
        text: String,
        environment: ColorEnvironmentValues
    ) async throws -> some Attachment {
        let resolvedURL = URL(string: url.absoluteString, relativeTo: baseURL) ?? url

        if let fragment = resolvedURL.fragment,
           let dims = Self.parseDimensions(from: fragment) {
            var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: true)!
            components.fragment = nil
            let cleanURL = components.url ?? resolvedURL
            return PreSizedImageAttachment(url: cleanURL, knownWidth: dims.width, knownHeight: dims.height)
        }

        // No dimension hints — load image to determine size
        let (data, _) = try await URLSession.shared.data(from: resolvedURL)
        #if os(macOS)
        guard let platformImage = NSImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        let size = platformImage.size
        #else
        guard let platformImage = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        let size = platformImage.size
        #endif
        return PreSizedImageAttachment(url: resolvedURL, knownWidth: size.width, knownHeight: size.height)
    }

    private static func parseDimensions(from fragment: String) -> CGSize? {
        guard fragment.hasPrefix("dim=") else { return nil }
        let value = fragment.dropFirst(4)
        let parts = value.split(separator: "x")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }
}
