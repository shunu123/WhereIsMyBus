import SwiftUI
import WebKit

struct LottieView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script src="https://unpkg.com/@dotlottie/player-component@latest/dist/dotlottie-player.mjs" type="module"></script>
            <style>
                body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: transparent; }
                dotlottie-player { width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <dotlottie-player src="\(url.absoluteString)" background="transparent" speed="1" loop autoplay></dotlottie-player>
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
