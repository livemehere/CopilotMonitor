import SwiftUI
import WebKit

struct GitHubLoginView: View {
    let copilot: GitHubCopilotModel
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        GitHubLoginWebView(copilot: copilot) {
            dismissWindow(id: "github-login")
        }
        .onDisappear {
            copilot.handleLoginWindowClosed()
        }
    }
}

private struct GitHubLoginWebView: NSViewRepresentable {
    var copilot: GitHubCopilotModel
    let onLoginCompleted: @MainActor () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://github.com/login") {
            copilot.startLogin()
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObservingCookies(in: nsView.configuration.websiteDataStore.httpCookieStore)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: copilot, onLoginCompleted: onLoginCompleted)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        private let model: GitHubCopilotModel
        private let service = GitHubCopilotEntitlementService()
        private let onLoginCompleted: @MainActor () -> Void
        private var lastValidatedFingerprint = ""
        private var hasCompletedLogin = false
        private var validationTask: Task<Void, Never>?

        init(
            model: GitHubCopilotModel,
            onLoginCompleted: @escaping @MainActor () -> Void
        ) {
            self.model = model
            self.onLoginCompleted = onLoginCompleted
        }

        deinit {
            validationTask?.cancel()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.configuration.websiteDataStore.httpCookieStore.add(self)
            scheduleCookieValidation(using: webView.configuration.websiteDataStore.httpCookieStore)
        }

        func stopObservingCookies(in cookieStore: WKHTTPCookieStore) {
            validationTask?.cancel()
            cookieStore.remove(self)
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            scheduleCookieValidation(using: cookieStore)
        }

        private func scheduleCookieValidation(using cookieStore: WKHTTPCookieStore) {
            guard !hasCompletedLogin else {
                return
            }

            validationTask?.cancel()
            validationTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else {
                    return
                }

                await self?.validateCookies(in: cookieStore)
            }
        }

        @MainActor
        private func validateCookies(in cookieStore: WKHTTPCookieStore) async {
            let cookies = await cookieStore.allCookies()
            let relevantCookies = service.extractRelevantCookies(from: cookies)

            model.updateObservedCookies(relevantCookies)

            guard service.hasRequiredCookies(relevantCookies) else {
                lastValidatedFingerprint = ""
                return
            }

            let fingerprint = service.fingerprint(for: relevantCookies)
            guard fingerprint != lastValidatedFingerprint else {
                return
            }

            let didValidate = await model.validateObservedCookies(relevantCookies)

            if didValidate {
                lastValidatedFingerprint = fingerprint
                hasCompletedLogin = true
                onLoginCompleted()
                return
            }

            validationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }

                await self?.validateCookies(in: cookieStore)
            }
        }
    }
}
