import Foundation

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
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"

    let requiredCookieNames = [
        "_gh_sess",
        "user_session",
        "__Host-user_session_same_site",
        "logged_in",
        "dotcom_user"
    ]

    private let supplementalCookieNames = [
        "_octo",
        "_device_id"
    ]

    private var allowedCookieNames: Set<String> {
        Set(requiredCookieNames + supplementalCookieNames)
    }

    func extractRelevantCookies(from cookies: [HTTPCookie]) -> [HTTPCookie] {
        let pairs: [(String, HTTPCookie)] = cookies.compactMap { cookie in
                guard
                    cookie.domain.contains("github"),
                    allowedCookieNames.contains(cookie.name),
                    !cookie.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return nil
                }

                return (cookie.name, cookie)
            }

        let cookiesByName = Dictionary(uniqueKeysWithValues: pairs)

        return (requiredCookieNames + supplementalCookieNames).compactMap { cookiesByName[$0] }
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

    func validate(cookies: [HTTPCookie]) async throws -> GitHubCopilotEntitlementResponse {
        let relevantCookies = extractRelevantCookies(from: cookies)
        let rawCookie = cookieHeader(from: relevantCookies)

        guard !rawCookie.isEmpty, hasRequiredCookies(relevantCookies) else {
            throw ValidationError.missingRequiredCookies
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(userAgent, forHTTPHeaderField: "user-agent")
        request.setValue(rawCookie, forHTTPHeaderField: "cookie")
        request.setValue("true", forHTTPHeaderField: "github-verified-fetch")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "x-requested-with")
        request.setValue("https://github.com/settings/copilot/features", forHTTPHeaderField: "referer")

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
                return "Copilot entitlement 호출에 필요한 GitHub 세션 쿠키가 아직 부족합니다."
            case .invalidResponse:
                return "GitHub 응답을 확인하지 못했습니다."
            case .emptyResponse:
                return "GitHub 응답이 비어 있습니다."
            case let .httpFailure(statusCode, body):
                if let body, !body.isEmpty {
                    return "GitHub 검증 실패 (HTTP \(statusCode)): \(body)"
                }

                return "GitHub 검증 실패 (HTTP \(statusCode))"
            case let .decodingFailure(body):
                if let body, !body.isEmpty {
                    return "GitHub entitlement 응답 파싱 실패: \(body)"
                }

                return "GitHub entitlement 응답 파싱 실패"
            }
        }
    }
}
