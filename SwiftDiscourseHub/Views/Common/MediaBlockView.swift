import SwiftUI
import WebKit

#if os(macOS)
struct MediaBlockView: NSViewRepresentable {
    let html: String
    let baseURL: String
    @Binding var height: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        loadContent(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    private func loadContent(in webView: WKWebView) {
        let wrapped = wrapHTML(html, baseURL: baseURL)
        webView.loadHTMLString(wrapped, baseURL: URL(string: baseURL))
    }
}
#else
struct MediaBlockView: UIViewRepresentable {
    let html: String
    let baseURL: String
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        loadContent(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    private func loadContent(in webView: WKWebView) {
        let wrapped = wrapHTML(html, baseURL: baseURL)
        webView.loadHTMLString(wrapped, baseURL: URL(string: baseURL))
    }
}
#endif

extension MediaBlockView {
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var height: CGFloat

        init(height: Binding<CGFloat>) {
            _height = height
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                if let h = result as? CGFloat, h > 0 {
                    DispatchQueue.main.async {
                        self?.height = h
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                UIApplication.shared.open(url)
                #endif
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

private func wrapHTML(_ html: String, baseURL: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
    body {
        margin: 0; padding: 0;
        font-family: -apple-system, system-ui;
        font-size: 16px;
        color-scheme: light dark;
    }
    @media (prefers-color-scheme: dark) {
        body { color: #e0e0e0; }
    }
    iframe { max-width: 100%; border: none; border-radius: 8px; }
    video { max-width: 100%; border-radius: 8px; }
    img { max-width: 100%; height: auto; }
    </style>
    </head>
    <body>\(html)</body>
    </html>
    """
}
