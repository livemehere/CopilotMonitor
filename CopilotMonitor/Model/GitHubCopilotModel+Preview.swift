#if DEBUG
import Foundation

@MainActor
extension GitHubCopilotModel {
    static func preview(
        loginState: LoginState = .idle,
        ratio: Float = 0,
        cookies: [HTTPCookie] = [],
        entitlement: GitHubCopilotEntitlementResponse? = nil,
        isResettingSession: Bool = false
    ) -> GitHubCopilotModel {
        let model = GitHubCopilotModel(restoresPersistedSession: false)
        model.loginState = loginState
        model.ratio = ratio
        model.cookies = cookies
        model.entitlement = entitlement
        model.isResettingSession = isResettingSession
        return model
    }
}

extension GitHubCopilotEntitlementResponse {
    static func preview(
        licenseType: String = "licensed_full",
        premiumLimit: Int = 300,
        premiumRemaining: Int = 197,
        premiumRemainingPercentage: Double = 65.9,
        resetDate: String = "2026-04-01",
        plan: String = "pro",
        eligible: Bool = false,
        overagesEnabled: Bool = false
    ) -> GitHubCopilotEntitlementResponse {
        GitHubCopilotEntitlementResponse(
            licenseType: licenseType,
            quotas: .init(
                limits: .init(premiumInteractions: premiumLimit),
                remaining: .init(
                    premiumInteractions: premiumRemaining,
                    chatPercentage: 100,
                    premiumInteractionsPercentage: premiumRemainingPercentage
                ),
                resetDate: resetDate,
                overagesEnabled: overagesEnabled
            ),
            plan: plan,
            trial: .init(eligible: eligible)
        )
    }
}

extension HTTPCookie {
    static func preview(
        name: String,
        value: String,
        domain: String = ".github.com"
    ) -> HTTPCookie {
        HTTPCookie(properties: [
            .domain: domain,
            .path: "/",
            .name: name,
            .value: value,
            .secure: true,
            .expires: Date().addingTimeInterval(3600)
        ])!
    }
}
#endif
