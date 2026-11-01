import SwiftUI
import WebKit

/// WKWebView a pantalla completa. Usa el data store por defecto (persistente), así la sesión
/// de Supabase (localStorage/cookies) se mantiene entre aperturas de la app.
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var reloadTick: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .automatic
        web.isOpaque = false
        web.backgroundColor = .clear

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        web.scrollView.refreshControl = refresh

        context.coordinator.webView = web
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.lastReloadTick != reloadTick {
            context.coordinator.lastReloadTick = reloadTick
            web.reload()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        var lastReloadTick = 0

        init(_ parent: WebView) { self.parent = parent }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finishWithError(webView, error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finishWithError(webView, error)
        }

        private func finishWithError(_ webView: WKWebView, _ error: Error) {
            parent.isLoading = false
            webView.scrollView.refreshControl?.endRefreshing()
            let code = (error as NSError).code
            if code == NSURLErrorCancelled { return }
            let html = """
            <html><head><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>body{font-family:-apple-system;display:flex;flex-direction:column;align-items:center;
            justify-content:center;height:100vh;margin:0;background:#4f46e5;color:#fff;text-align:center}
            p{opacity:.85;padding:0 32px}</style></head>
            <body><h2>Sin conexión</h2><p>No pude cargar Sturea. Desliza hacia abajo para reintentar.</p></body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }

        // Enlaces externos (otros dominios) se abren en Safari; sturea.com y Supabase auth quedan dentro.
        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = action.request.url, let host = target.host?.lowercased() else {
                decisionHandler(.allow); return
            }
            let scheme = target.scheme?.lowercased() ?? ""
            if scheme == "mailto" || scheme == "tel" {
                UIApplication.shared.open(target)
                decisionHandler(.cancel); return
            }
            let internalHosts = ["sturea.com", "supabase.co"]
            let isInternal = internalHosts.contains { host == $0 || host.hasSuffix("." + $0) }
            if action.navigationType == .linkActivated && !isInternal {
                UIApplication.shared.open(target)
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }

        // target="_blank": cargar en la misma vista.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
