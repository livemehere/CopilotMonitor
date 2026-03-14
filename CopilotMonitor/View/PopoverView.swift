import SwiftUI

struct PopoverView: View {
    var usageData: UsageViewModel

    var body: some View {
        VStack {
            ProgressView(value: usageData.ratio, total: 1) {
                Text("Usage: \(usageData.percentage)%")
            }
            .tint(usageData.usageColor)
        }
        .padding()
        .frame(maxWidth: 400)
    }

}

#Preview {
    PopoverView(usageData: UsageViewModel())
}
