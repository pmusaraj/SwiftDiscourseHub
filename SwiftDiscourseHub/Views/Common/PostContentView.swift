import SwiftUI
import Textual

struct PostContentView: View {
    let markdown: String
    let baseURL: String

    private var siteBaseURL: URL? { URL(string: baseURL) }

    var body: some View {
        StructuredText(markdown: markdown, baseURL: siteBaseURL)
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
