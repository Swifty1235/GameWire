import SwiftUI
import WebKit

/// Shows an article's HTML with WebKit. Tapped links are handed back via `onOpenLink`
/// (so they open in the in-app browser), while embedded videos play inline.
/// `previews` fill in link cards (`data-preview-url`) with an image and title once they've loaded.
struct ArticleWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    var previews: [LinkPreview] = []
    let onOpenLink: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenLink: onOpenLink)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // baseURL lets relative links and "//site.com" embeds resolve, and gives YouTube a referrer.
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpenLink = onOpenLink
        context.coordinator.previews = previews
        context.coordinator.applyPreviews(to: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var onOpenLink: (URL) -> Void
        var previews: [LinkPreview] = []
        private var isLoaded = false
        private var applied = Set<URL>()

        init(onOpenLink: @escaping (URL) -> Void) {
            self.onOpenLink = onOpenLink
        }

        /// Puts each preview's image and title into its card. Waits for the page if it's still loading.
        func applyPreviews(to webView: WKWebView) {
            guard isLoaded else { return }
            for preview in previews where !applied.contains(preview.url) {
                applied.insert(preview.url)
                let script = """
                document.querySelectorAll('[data-preview-url="' + \(jsString(preview.url.absoluteString)) + '"]').forEach(card => {
                  const image = \(jsString(preview.imageURL?.absoluteString));
                  const title = \(jsString(preview.title));
                  if (image) card.querySelector('.preview-image')?.setAttribute('src', image);
                  if (title) { const t = card.querySelector('.preview-title'); if (t) t.textContent = title; }
                });
                """
                webView.evaluateJavaScript(script)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            applyPreviews(to: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            // A tapped link in the article itself (not inside a video player) → in-app browser.
            if navigationAction.navigationType == .linkActivated,
               navigationAction.targetFrame?.isMainFrame != false,
               let url = navigationAction.request.url {
                // "#section" links jump within the article.
                if url.fragment != nil, url.absoluteString.hasPrefix((webView.url?.absoluteString ?? "") + "#") {
                    return .allow
                }
                open(url)
                return .cancel
            }
            return .allow
        }

        /// Web links go to the in-app browser; anything else (steam://, mailto:) goes to the system,
        /// since Safari's in-app browser can only show http(s) pages.
        private func open(_ url: URL) {
            if ["http", "https"].contains(url.scheme?.lowercased()) {
                onOpenLink(url)
            } else {
                UIApplication.shared.open(url)
            }
        }

        /// Embedded posts (X, Instagram…) open links in a new window; send those to the in-app browser too.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                open(url)
            }
            return nil
        }

        /// A Swift string as a safe JavaScript literal (or `null`).
        private func jsString(_ value: String?) -> String {
            guard let value,
                  let data = try? JSONEncoder().encode(value),
                  let literal = String(data: data, encoding: .utf8)
            else { return "null" }
            return literal
        }
    }
}
