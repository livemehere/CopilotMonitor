import SwiftUI

struct PopoverView : View {
    var usageData: UsageViewModel
    
    var body: some View {
        VStack {
            Text("Used: \(usageData.ratio)")
        }
        .padding()
    }
}


#Preview {
    PopoverView(usageData: UsageViewModel())
}
