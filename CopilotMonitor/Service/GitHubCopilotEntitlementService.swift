import Foundation
import WebKit

struct GitHubCopilotEntitlementResponse: Codable {
    let licenseType: String
    let quotas: Quotas
    let plan: String
    let trial: Trial

    struct Quotas: Codable {
        let limits: Limits
        let remaining: Remaining
        let resetDate: String
        let overagesEnabled: Bool
    }

    struct Limits: Codable {
        let premiumInteractions: Int?
    }

    struct Remaining: Codable {
        let premiumInteractions: Int?
        let chatPercentage: Double?
        let premiumInteractionsPercentage: Double?
    }

    struct Trial: Codable {
        let eligible: Bool
    }
}

struct GitHubCopilotEntitlementService {
    private let endpoint = URL(string: "https://github.com/github-copilot/chat/entitlement")!
    private let bootstrapURL = URL(string: "https://github.com/login")!

    let requiredCookieNames = [
        "user_session",
    ]

    func extractRelevantCookies(from cookies: [HTTPCookie]) -> [HTTPCookie] {
        let pairs: [(String, HTTPCookie)] = cookies.compactMap { cookie in
                guard
                    cookie.domain.contains("github"),
                    requiredCookieNames.contains(cookie.name),
                    !cookie.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return nil
                }

                return (cookie.name, cookie)
            }

        let cookiesByName = Dictionary(uniqueKeysWithValues: pairs)

        return (requiredCookieNames).compactMap { cookiesByName[$0] }
    }

    func hasRequiredCookies(_ cookies: [HTTPCookie]) -> Bool {
        let cookieNames = Set(cookies.map(\.name))
        return Set(requiredCookieNames).isSubset(of: cookieNames)
    }

    func cookieHeader(from cookies: [HTTPCookie]) -> String {
        extractRelevantCookies(from: cookies)
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    func fingerprint(for cookies: [HTTPCookie]) -> String {
        cookieHeader(from: cookies)
    }

    func loadPersistedCookies() async -> [HTTPCookie] {
        await warmUpDefaultCookieStoreIfNeeded()
        return await WKWebsiteDataStore.default().httpCookieStore.allCookies()
    }

    func clearPersistedSession() async {
        let store = WKWebsiteDataStore.default()
        let cookieStore = store.httpCookieStore
        let cookies = await cookieStore.allCookies()

        for cookie in cookies where cookie.domain.contains("github") {
            await cookieStore.deleteCookie(cookie)
        }

        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await store.dataRecords(ofTypes: dataTypes)
        let githubRecords = records.filter {
            $0.displayName.localizedCaseInsensitiveContains("github")
        }

        guard !githubRecords.isEmpty else {
            return
        }

        await store.removeData(ofTypes: dataTypes, for: githubRecords)
    }

    func validate(cookies: [HTTPCookie]) async throws -> GitHubCopilotEntitlementResponse {
        let relevantCookies = extractRelevantCookies(from: cookies)
        let rawCookie = cookieHeader(from: relevantCookies)

        guard !rawCookie.isEmpty, hasRequiredCookies(relevantCookies) else {
            throw ValidationError.missingRequiredCookies
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(rawCookie, forHTTPHeaderField: "cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ValidationError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw ValidationError.httpFailure(statusCode: httpResponse.statusCode, body: body)
        }

        guard !data.isEmpty else {
            throw ValidationError.emptyResponse
        }

        do {
            return try JSONDecoder().decode(GitHubCopilotEntitlementResponse.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8)
            throw ValidationError.decodingFailure(body: body)
        }
    }
}

@MainActor
private extension GitHubCopilotEntitlementService {
    func warmUpDefaultCookieStoreIfNeeded() async {
        let loader = CookieStoreWarmupLoader(url: bootstrapURL)
        await loader.load()
    }
}

@MainActor
private final class CookieStoreWarmupLoader: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let url: URL
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasResumed = false

    init(url: URL) {
        self.url = url

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()
        webView.navigationDelegate = self
    }

    func load() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            webView.load(request)

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(4))
                self?.resumeIfNeeded()
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        resumeIfNeeded()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        resumeIfNeeded()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        resumeIfNeeded()
    }

    private func resumeIfNeeded() {
        guard !hasResumed else {
            return
        }

        hasResumed = true
        continuation?.resume()
        continuation = nil
    }
}

private extension WKHTTPCookieStore {
    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    func deleteCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            delete(cookie) {
                continuation.resume()
            }
        }
    }
}

private extension WKWebsiteDataStore {
    func dataRecords(ofTypes dataTypes: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { continuation in
            fetchDataRecords(ofTypes: dataTypes) { records in
                continuation.resume(returning: records)
            }
        }
    }

    func removeData(ofTypes dataTypes: Set<String>, for records: [WKWebsiteDataRecord]) async {
        await withCheckedContinuation { continuation in
            removeData(ofTypes: dataTypes, for: records) {
                continuation.resume()
            }
        }
    }
}

extension GitHubCopilotEntitlementService {
    enum ValidationError: LocalizedError {
        case missingRequiredCookies
        case invalidResponse
        case emptyResponse
        case httpFailure(statusCode: Int, body: String?)
        case decodingFailure(body: String?)

        var errorDescription: String? {
            switch self {
            case .missingRequiredCookies:
                return "The required GitHub session cookies for the Copilot entitlement request are still missing."
            case .invalidResponse:
                return "Unable to validate the GitHub response."
            case .emptyResponse:
                return "The GitHub response is empty."
            case let .httpFailure(statusCode, body):
                if let body, !body.isEmpty {
                    return "GitHub validation failed (HTTP \(statusCode)): \(body)"
                }

                return "GitHub validation failed (HTTP \(statusCode))"
            case let .decodingFailure(body):
                if let body, !body.isEmpty {
                    return "Failed to decode the GitHub entitlement response: \(body)"
                }

                return "Failed to decode the GitHub entitlement response"
            }
        }
    }
}
