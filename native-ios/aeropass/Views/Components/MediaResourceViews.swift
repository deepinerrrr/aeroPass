import SwiftUI
import WebKit

struct SVGIconView: UIViewRepresentable {
    let resourceName: String
    let resourceDirectory: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        load(resourceInto: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        load(resourceInto: webView)
    }

    private func load(resourceInto webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "svg", subdirectory: resourceDirectory) else {
            webView.loadHTMLString("<body style='margin:0;background:transparent'></body>", baseURL: nil)
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

struct WalkingDogLottieView: UIViewRepresentable {
    let resourceName: String
    let resourceDirectory: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        loadAnimation(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            loadAnimation(into: webView)
        }
    }

    private func loadAnimation(into webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: resourceDirectory),
              let data = try? Data(contentsOf: url),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        let escapedJSON = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "</", with: "<\\/")

        let html = """
        <!doctype html>
        <html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>
        <body style='margin:0;background:transparent;overflow:hidden'>
        <div id='animation' style='width:100vw;height:100vh'></div>
        <script src='https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js'></script>
        <script>
        (function() {
          const data = JSON.parse(`\(escapedJSON)`);
          if (window.lottie) {
            lottie.loadAnimation({container: document.getElementById('animation'), renderer:'svg', loop:true, autoplay:true, animationData:data});
          } else {
            document.getElementById('animation').innerHTML = '<div style="font-size:24px;text-align:center;line-height:1">•</div>';
          }
        })();
        </script></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

struct QuestionProgressBar: View {
    @Binding var value: Double
    let maximum: Double
    let tint: Color

    private var normalizedProgress: CGFloat {
        guard maximum > 0 else { return 0 }
        return CGFloat(min(max(value / maximum, 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 18
            let usableWidth = max(0, proxy.size.width - horizontalInset * 2)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.14))
                    .frame(height: 5)
                Capsule()
                    .fill(tint.opacity(0.28))
                    .frame(width: usableWidth * normalizedProgress, height: 5)
                WalkingDogLottieView(resourceName: "walking_dog-3", resourceDirectory: "Animations")
                    .frame(width: 36, height: 36)
                    .offset(x: horizontalInset + usableWidth * normalizedProgress - 18, y: -13)
                    .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.78), value: normalizedProgress)
            }
            .padding(.horizontal, horizontalInset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard maximum > 0 else { return }
                        let position = min(max(gesture.location.x - horizontalInset, 0), usableWidth)
                        value = Double(position / max(usableWidth, 1)) * maximum
                    }
            )
        }
        .frame(height: 34)
        .accessibilityLabel("题目进度")
        .accessibilityValue("第 \(Int(value.rounded()) + 1) 题，共 \(Int(maximum.rounded()) + 1) 题")
    }
}

struct AIProviderLogoView: View {
    let provider: AIProvider

    var body: some View {
        SVGIconView(
            resourceName: provider == .deepseek ? "deepseek" : "qwen",
            resourceDirectory: "Icons"
        )
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct AIProviderLogoPair: View {
    var body: some View {
        HStack(spacing: 5) {
            AIProviderLogoView(provider: .deepseek)
            AIProviderLogoView(provider: .qwen)
        }
    }
}
