import Observation
import SwiftUI

@Observable
class UsageViewModel {
    var ratio: Float = 0.97

    var percentage: Int {
        Int(ratio * 100)
    }

    var usageColor: Color {
        if ratio < 0.5 {
            return .green
        } else if ratio < 0.8 {
            return .orange
        } else {
            return .red
        }
    }
}
