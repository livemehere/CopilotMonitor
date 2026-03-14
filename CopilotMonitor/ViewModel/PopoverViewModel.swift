import SwiftUI

struct PopoverViewModel {
    struct DetailItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    struct Banner {
        let systemImage: String
        let tint: Color
        let message: String
    }

    let title = "Copilot Usage"
    let percentageText: String
    let requestUsageText: String?
    let progressValue: Double
    let progressTint: Color
    let detailItems: [DetailItem]
    let banner: Banner?
    let isBusy: Bool

    init(copilot: GitHubCopilotModel) {
        percentageText = "\(copilot.percentage)%"
        requestUsageText = copilot.premiumUsageCompactDescription
        progressValue = Double(copilot.ratio)
        progressTint = copilot.usageColor
        detailItems = Self.makeDetailItems(from: copilot)
        banner = Self.makeBanner(from: copilot)
        isBusy = copilot.isBusy
    }

    private static func makeDetailItems(from copilot: GitHubCopilotModel) -> [DetailItem] {
        var items = [DetailItem(label: "Status", value: copilot.loginState.description)]

        if let planDescription = copilot.planDescription {
            items.append(.init(label: "Plan", value: planDescription))
        }

        if let resetDate = copilot.resetDateDescription {
            items.append(.init(label: "Reset", value: resetDate))
        }

        return items
    }

    private static func makeBanner(from copilot: GitHubCopilotModel) -> Banner? {
        if copilot.loginState == .failed {
            return Banner(
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange,
                message: "Session expired or invalid. Sign in with GitHub again to continue."
            )
        }

        if copilot.isResettingSession {
            return Banner(
                systemImage: "trash.fill",
                tint: .secondary,
                message: "Clearing the saved GitHub session."
            )
        }

        return nil
    }
}
