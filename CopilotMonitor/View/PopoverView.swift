import SwiftUI

struct PopoverView: View {
    let copilot: GitHubCopilotModel
    @Environment(\.openWindow) private var openWindow

    private var viewModel: PopoverViewModel {
        PopoverViewModel(copilot: copilot)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                UsageSummaryHeaderView(
                    title: viewModel.title,
                    percentageText: viewModel.percentageText,
                    requestUsageText: viewModel.requestUsageText,
                    progressValue: viewModel.progressValue,
                    progressTint: viewModel.progressTint
                )

                InfoCardView {
                    ForEach(viewModel.detailItems) { item in
                        DetailRowView(label: item.label, value: item.value)
                    }
                }

                if let banner = viewModel.banner {
                    StatusBannerView(
                        systemImage: banner.systemImage,
                        tint: banner.tint,
                        message: banner.message
                    )
                }
            }
            .padding()
            .frame(maxWidth: 420)

            Divider()

            VStack(spacing: 4) {
                MenuLikeButton(
                    title: "Login with GitHub",
                    systemImage: "person.crop.circle.badge.checkmark"
                ) {
                    openWindow(id: "github-login")
                }
                .disabled(viewModel.isBusy)

                MenuLikeButton(
                    title: "Clear Stored Session",
                    systemImage: "trash",
                    tint: .red,
                    role: .destructive
                ) {
                    Task {
                        await copilot.clearPersistedSession()
                    }
                }
                .disabled(viewModel.isBusy)

                MenuLikeToggle(
                    title: "Auto Refresh",
                    systemImage: "arrow.clockwise",
                    badgeText: "30s",
                    isOn: Binding(
                        get: { copilot.isAutoRefreshEnabled },
                        set: { copilot.isAutoRefreshEnabled = $0 }
                    )
                )
                .disabled(viewModel.isBusy)

                MenuLikeButton(title: "Quit", systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 420)
        .onAppear {
            Task {
                await copilot.refreshEntitlementIfPossible()
            }
        }
    }
}

#Preview("Idle") {
    PopoverView(copilot: .preview())
}

#Preview("Validating") {
    PopoverView(
        copilot: .preview(
            loginState: GitHubCopilotModel.LoginState.validating,
            ratio: 0.34,
            cookies: [
                HTTPCookie.preview(name: "user_session", value: "user")
            ]
        )
    )
}

#Preview("Completed") {
    PopoverView(
        copilot: .preview(
            loginState: GitHubCopilotModel.LoginState.completed,
            ratio: 0.341,
            cookies: [
                HTTPCookie.preview(name: "user_session", value: "user")
            ],
            entitlement: GitHubCopilotEntitlementResponse.preview()
        )
    )
}

#Preview("Failed") {
    PopoverView(
        copilot: .preview(
            loginState: GitHubCopilotModel.LoginState.failed,
            cookies: [
                HTTPCookie.preview(name: "user_session", value: "expired")
            ]
        )
    )
}
