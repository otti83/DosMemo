import SwiftUI
import WebKit

/// Read-only rendering of Markdown HTML in a WKWebView, styled with
/// github-markdown-css (Resources/markdown).
struct MarkdownPreviewView: NSViewRepresentable {
    let html: String
    /// Directory of the document, so relative links and images resolve.
    let baseURL: URL?
    let zoom: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Markdown may contain raw HTML; never run scripts from it. The app
        // itself can still call evaluateJavaScript to swap the content.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.loadHTMLString(Self.page, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.pageZoom != zoom { webView.pageZoom = zoom }
        context.coordinator.show(html)
    }

    private static let page: String = {
        let css = Bundle.main.url(forResource: "github-markdown", withExtension: "css", subdirectory: "markdown")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>\(css)
        body { margin: 0; background: Canvas; }
        .markdown-body li:has(> input[type=checkbox]) { list-style: none; }
        .markdown-body li > input[type=checkbox] { margin: 0 0.2em 0.25em -1.4em; vertical-align: middle; }
        .markdown-body { box-sizing: border-box; max-width: 980px; margin: 0 auto; padding: 24px 32px; background: transparent; }
        </style></head>
        <body><article id="content" class="markdown-body"></article></body></html>
        """
    }()

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var isLoaded = false
        private var shownHTML: String?
        private var pendingHTML: String?

        /// Replaces the article body in place so the scroll position
        /// survives edits in split view.
        func show(_ html: String) {
            guard html != shownHTML else { return }
            guard isLoaded, let webView else {
                pendingHTML = html
                return
            }
            guard let literal = Self.javaScriptStringLiteral(html) else { return }
            shownHTML = html
            webView.evaluateJavaScript("document.getElementById('content').innerHTML = \(literal);")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if let pendingHTML {
                self.pendingHTML = nil
                show(pendingHTML)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
                // The initial page load; anything else stays inside the preview.
                decisionHandler(isLoaded ? .cancel : .allow)
                return
            }
            if url.fragment != nil, url.scheme == webView.url?.scheme,
               url.path == webView.url?.path, url.host == webView.url?.host {
                decisionHandler(.allow)   // In-page anchor such as a footnote.
                return
            }
            decisionHandler(.cancel)
            // Clicked links open in the default app; other schemes could
            // launch arbitrary URL handlers, so they are ignored.
            if let scheme = url.scheme?.lowercased(), Self.openableSchemes.contains(scheme) {
                NSWorkspace.shared.open(url)
            }
        }

        private static let openableSchemes: Set<String> = ["http", "https", "mailto", "file"]

        private static func javaScriptStringLiteral(_ string: String) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: [string]),
                  let array = String(data: data, encoding: .utf8) else { return nil }
            return String(array.dropFirst().dropLast())   // Strip the enclosing [ ].
        }
    }
}
