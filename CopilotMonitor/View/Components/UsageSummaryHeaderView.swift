import SwiftUI

struct UsageSummaryHeaderView: View {
    let title: String
    let percentageText: String
    let requestUsageText: String?
    let progressValue: Double
    let progressTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(percentageText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()

                if let requestUsageText {
                    Text(requestUsageText)
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: progressValue, total: 1)
                .tint(progressTint)
        }
    }
}
