import SwiftUI
import WebKit

struct MarkdownWebView: UIViewRepresentable {
    let markdownContent: String
    let themeColor: Color
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $contentHeight) }
    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "contentHeight")
        controller.addUserScript(WKUserScript(source: """
        const content = document.getElementById('content');
        const report = () => window.webkit.messageHandlers.contentHeight.postMessage(content.getBoundingClientRect().height + 24);
        window.aeropassResizeObserver = new ResizeObserver(report);
        window.aeropassResizeObserver.observe(content);
        report();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.panGestureRecognizer.isEnabled = false
        web.scrollView.bounces = false
        web.navigationDelegate = context.coordinator
        context.coordinator.web = web
        web.loadHTMLString(html, baseURL: nil)
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.height = $contentHeight
        let html = MarkdownToHTMLConverter.convert(markdownContent)
        guard context.coordinator.pendingHTML != html else { return }
        context.coordinator.pendingHTML = html
        context.coordinator.scheduleRender()
    }
    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        coordinator.work?.cancel()
        web.configuration.userContentController.removeScriptMessageHandler(forName: "contentHeight")
    }
    private var html: String {
        let color = UIColor(themeColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        return """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; --accent: \(hex); }
        * { box-sizing: border-box; }
        html, body { margin: 0; background: transparent; }
        body { font: 16px/1.65 -apple-system, BlinkMacSystemFont, 'PingFang SC', sans-serif; color: #1c1c1e; overflow-wrap: anywhere; padding: 12px 14px; }
        #content { min-height: 16px; display: flow-root; }
        p { margin: 0 0 10px; } h1,h2,h3 { line-height: 1.4; margin: 16px 0 8px; } h1 { font-size: 1.4em; } h2 { font-size: 1.25em; } h3 { font-size: 1.1em; }
        strong { color: var(--accent); } ul,ol { padding-left: 24px; } li { margin: 5px 0; }
        code,pre { font-family: ui-monospace, monospace; background: #eaeaef; border-radius: 6px; } code { padding: 2px 4px; } pre { padding: 12px; overflow: auto; } pre code { padding: 0; }
        blockquote { margin: 12px 0; padding-left: 12px; border-left: 3px solid var(--accent); color: #636366; }
        table { display: block; overflow-x: auto; border-collapse: collapse; margin: 10px 0; } th,td { border: 1px solid #c7c7cc; padding: 8px; } th { font-weight: 600; }
        .math-block { overflow-x: auto; text-align: center; margin: 12px 0; } .math-inline,.math-block { font-family: 'Times New Roman',serif; }
        @media (prefers-color-scheme: dark) { body { color: #f2f2f7; } code,pre { background: #38383a; } blockquote { color: #aeaeb2; } th,td { border-color: #545458; } }
        </style></head><body><div id="content">\(MarkdownToHTMLConverter.convert(markdownContent))</div></body></html>
        """
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var height: Binding<CGFloat>
        weak var web: WKWebView?
        var ready = false
        var pendingHTML: String?
        var work: DispatchWorkItem?
        init(height: Binding<CGFloat>) { self.height = height }
        func scheduleRender() {
            guard ready, work == nil else { return }
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }; self.work = nil
                guard let html = self.pendingHTML,
                      let data = try? JSONSerialization.data(withJSONObject: html, options: [.fragmentsAllowed]),
                      let literal = String(data: data, encoding: .utf8) else { return }
                self.web?.evaluateJavaScript("document.getElementById('content').innerHTML = \(literal); document.getElementById('content').getBoundingClientRect().height + 24;") { [weak self] result, _ in
                    if let value = result as? Double { self?.setHeight(value) }
                }
            }
            work = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: item)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            webView.evaluateJavaScript("document.getElementById('content').getBoundingClientRect().height + 24") { [weak self] result, _ in
                if let value = result as? Double { self?.setHeight(value) }
            }
            scheduleRender()
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let value = message.body as? Double else { return }
            setHeight(value)
        }
        private func setHeight(_ value: Double) {
            guard value.isFinite, value > 0 else { return }
            let newHeight = max(40, ceil(value))
            if abs(height.wrappedValue - newHeight) > 1 { height.wrappedValue = newHeight }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                if ["https", "http"].contains(url.scheme?.lowercased() ?? "") { UIApplication.shared.open(url) }
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
}
