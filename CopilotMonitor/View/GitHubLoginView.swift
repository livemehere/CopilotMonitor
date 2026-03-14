import SwiftUI
import WebKit

struct GitHubLoginView: NSViewRepresentable {
    var model: GitHubCopilotModel

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // WebView가 생성되면 바로 GitHub 로그인 페이지 로드
        if let url = URL(string: "https://github.com/login") {
            model.startLogin()
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 업데이트는 필요 없음
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var model: GitHubCopilotModel

        init(model: GitHubCopilotModel) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.hasLoaded = true

            // 쿠키 가져오기
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let githubCookies = cookies.filter { $0.domain.contains("github") }

                print("=== GitHub Cookies ===")
                for cookie in githubCookies {
                    print("\(cookie.name): \(cookie.value)")
                }
                print("=====================")

                DispatchQueue.main.async {
                    self.model.cookies = githubCookies
                    self.model.isLoading = false
                }
            }
        }
    }
}
