import SwiftUI

@main
struct CopilotMonitorApp: App {
    @State private var usageData = UsageViewModel()
    var body: some Scene {
        MenuBarExtra("\(usageData.percentage)%") {
            PopoverView(usageData: usageData)
        }
        .menuBarExtraStyle(.window)
    }
}
