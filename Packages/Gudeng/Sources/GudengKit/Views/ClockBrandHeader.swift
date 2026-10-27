import SwiftUI

struct ClockBrandHeader: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 3) {
            Text(ClockText.brandTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ClockTheme.brand(scheme))
            Text(ClockText.brandCaption)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
