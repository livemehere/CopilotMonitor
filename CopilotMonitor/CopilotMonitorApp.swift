import SwiftUI

@main
struct CopilotMonitorApp: App {
    @State private var usageData = UsageViewModel();
    var body: some Scene {
        MenuBarExtra("\(usageData.ratio)%", systemImage: "chevron.left.forwardslash.chevron.right") {
            // TODO
            PopoverView(usageData: usageData)
        }
        .menuBarExtraStyle(.window)
    }
}
