import SwiftUI

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
                        FaviconView(domain: info.domain)
                            .frame(width: 16, height: 16)

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
}

private struct FaviconView: View {
    let domain: String
    @State private var imageData: Data?
    @State private var loaded = false

    var body: some View {
        Group {
            if let imageData, let image = platformImage(from: imageData) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: domain) {
            guard !loaded else { return }
            imageData = await FaviconCache.shared.favicon(for: domain)
            loaded = true
        }
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #endif
    }
}
