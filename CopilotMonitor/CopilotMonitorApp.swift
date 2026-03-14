import SwiftUI

@main
struct CopilotMonitorApp: App {
    @State private var copilot = GitHubCopilotModel()

    var body: some Scene {
        MenuBarExtra(copilot.menuBarTitle) {
            PopoverView(copilot: copilot)
        }
        .menuBarExtraStyle(.window)

        Window("GitHub Login", id: "github-login") {
            GitHubLoginView(copilot: copilot)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 800, height: 600)
    }
}
