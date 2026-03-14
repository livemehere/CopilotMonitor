import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class GitHubCopilotModel {
    private static let autoRefreshDefaultsKey = "isAutoRefreshEnabled"

    @ObservationIgnored private let entitlementService: GitHubCopilotEntitlementService = .init()
    @ObservationIgnored private var autoRefreshTask: Task<Void, Never>?

    enum LoginState {
        case idle
        case loading
        case validating
        case completed
        case failed

        var description: String {
            switch self {
            case .idle:
                return "Idle"
            case .loading:
                return "Signing in"
            case .validating:
                return "Validating session"
            case .completed:
                return "Connected"
            case .failed:
                return "Sign in required"
            }
        }
    }

    var ratio: Float = 0.0
    var entitlement: GitHubCopilotEntitlementResponse?

    var percentage: Int {
        Int(ratio * 100)
    }

    var menuBarTitle: String {
        "\(percentage)%"
    }

    var usageColor: Color {
        switch ratio {
        case ..<0.5:
            return .green
        case ..<0.8:
            return .orange
        default:
            return .red
        }
    }

    var loginState: LoginState = .idle
    var cookies: [HTTPCookie] = []
    var isResettingSession = false
    var isAutoRefreshEnabled = false {
        didSet {
            UserDefaults.standard.set(isAutoRefreshEnabled, forKey: Self.autoRefreshDefaultsKey)
            configureAutoRefreshTask()

            guard isAutoRefreshEnabled else {
                return
            }

            Task { [weak self] in
                await self?.refreshEntitlementIfPossible()
            }
        }
    }
    @ObservationIgnored private var hasAttemptedSessionRestore = false

    init(restoresPersistedSession: Bool = true) {
        isAutoRefreshEnabled = UserDefaults.standard.bool(forKey: Self.autoRefreshDefaultsKey)

        if isAutoRefreshEnabled {
            configureAutoRefreshTask()
        }

        guard restoresPersistedSession else {
            return
        }

        Task { [weak self] in
            await self?.refreshEntitlementIfPossible()
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    var isLoading: Bool {
        loginState == .loading || loginState == .validating
    }

    var isBusy: Bool {
        isLoading || isResettingSession
    }

    var hasSessionCookies: Bool {
        entitlementService.hasRequiredCookies(cookies)
    }

    var planDescription: String? {
        entitlement?.plan
    }

    var premiumInteractionsSummary: String? {
        guard
            let entitlement,
            let remaining = entitlement.quotas.remaining.premiumInteractions,
            let limit = entitlement.quotas.limits.premiumInteractions
        else {
            return nil
        }

        return "Premium remaining: \(remaining)/\(limit)"
    }

    var resetDateDescription: String? {
        entitlement?.quotas.resetDate
    }

    var premiumUsageCompactDescription: String? {
        guard
            let entitlement,
            let remaining = entitlement.quotas.remaining.premiumInteractions,
            let limit = entitlement.quotas.limits.premiumInteractions
        else {
            return nil
        }

        return "Remain \(remaining)/\(limit)"
    }

    func startLogin() {
        loginState = .loading
    }

    func restorePersistedSessionIfAvailable() async {
        guard !hasAttemptedSessionRestore else {
            return
        }

        hasAttemptedSessionRestore = true

        guard !isResettingSession else {
            return
        }

        let persistedCookies = await entitlementService.loadPersistedCookies()
        let relevantCookies = entitlementService.extractRelevantCookies(from: persistedCookies)

        guard !relevantCookies.isEmpty else {
            return
        }

        updateObservedCookies(relevantCookies)

        if entitlement == nil {
            loginState = .idle
        }
    }

    func refreshEntitlementIfPossible() async {
        guard !isBusy else {
            return
        }

        if !hasAttemptedSessionRestore {
            await restorePersistedSessionIfAvailable()
        }

        let relevantCookies = entitlementService.extractRelevantCookies(from: cookies)

        guard !relevantCookies.isEmpty else {
            return
        }

        guard entitlementService.hasRequiredCookies(relevantCookies) else {
            if entitlement != nil {
                failValidation(observedCookies: relevantCookies)
            }

            return
        }

        _ = await validateObservedCookies(relevantCookies)
    }

    func validateObservedCookies(_ cookies: [HTTPCookie]) async -> Bool {
        let relevantCookies = entitlementService.extractRelevantCookies(from: cookies)
        updateObservedCookies(relevantCookies)

        guard entitlementService.hasRequiredCookies(relevantCookies) else {
            return false
        }

        beginValidation(with: relevantCookies)

        do {
            let entitlement = try await entitlementService.validate(cookies: relevantCookies)
            completeLogin(with: relevantCookies, entitlement: entitlement)
            return true
        } catch {
            failValidation(observedCookies: relevantCookies)
            return false
        }
    }

    func updateObservedCookies(_ cookies: [HTTPCookie]) {
        self.cookies = cookies
    }

    func beginValidation(with cookies: [HTTPCookie]) {
        self.cookies = cookies
        loginState = .validating
    }

    func completeLogin(with cookies: [HTTPCookie], entitlement: GitHubCopilotEntitlementResponse) {
        self.cookies = cookies
        self.entitlement = entitlement
        loginState = .completed
        updateUsageRatio(using: entitlement)
    }

    func failValidation(observedCookies: [HTTPCookie]) {
        cookies = observedCookies
        entitlement = nil
        ratio = 0
        isAutoRefreshEnabled = false
        loginState = .failed
    }

    func handleLoginWindowClosed() {
        if entitlement != nil {
            loginState = .completed
            return
        }

        loginState = .idle
    }

    func clearPersistedSession() async {
        isResettingSession = true
        defer { isResettingSession = false }

        await entitlementService.clearPersistedSession()
        resetLogin()
    }

    func resetLogin() {
        loginState = .idle
        cookies = []
        entitlement = nil
        ratio = 0
        hasAttemptedSessionRestore = false
    }

    private func configureAutoRefreshTask() {
        autoRefreshTask?.cancel()

        guard isAutoRefreshEnabled else {
            autoRefreshTask = nil
            return
        }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))

                guard !Task.isCancelled else {
                    break
                }

                await self?.refreshEntitlementIfPossible()
            }
        }
    }

    private func updateUsageRatio(using entitlement: GitHubCopilotEntitlementResponse) {
        if let remainingPercentage = entitlement.quotas.remaining.premiumInteractionsPercentage {
            ratio = max(0, min(1, Float((100 - remainingPercentage) / 100)))
            return
        }

        guard
            let limit = entitlement.quotas.limits.premiumInteractions,
            let remaining = entitlement.quotas.remaining.premiumInteractions,
            limit > 0
        else {
            return
        }

        ratio = max(0, min(1, Float(limit - remaining) / Float(limit)))
    }
}
