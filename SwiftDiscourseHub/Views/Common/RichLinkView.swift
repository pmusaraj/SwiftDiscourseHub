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
