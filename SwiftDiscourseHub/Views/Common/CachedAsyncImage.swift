import SwiftUI
import os

private let imageLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SwiftDiscourseHub", category: "ImageLoading")

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: PlatformImage?
    @State private var hasFailed = false

    init(url: URL?,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let loadedImage {
                #if os(macOS)
                content(Image(nsImage: loadedImage))
                #else
                content(Image(uiImage: loadedImage))
                #endif
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url, loadedImage == nil else { return }
            await loadImage(from: url)
        }
    }

    private func loadImage(from url: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                imageLogger.warning("Image HTTP \(httpResponse.statusCode, privacy: .public) for \(url.absoluteString, privacy: .public)")
                hasFailed = true
                return
            }

            guard let image = PlatformImage(data: data) else {
                imageLogger.warning("Image decode failed for \(url.absoluteString, privacy: .public) (\(data.count) bytes)")
                hasFailed = true
                return
            }

            self.loadedImage = image
        } catch {
            imageLogger.warning("Image load error for \(url.absoluteString, privacy: .public) — \(error.localizedDescription, privacy: .public)")
            hasFailed = true
        }
    }
}

#if os(macOS)
private typealias PlatformImage = NSImage
#else
private typealias PlatformImage = UIImage
#endif
