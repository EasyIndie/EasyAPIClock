import SwiftUI
import LiangWenCore
#if os(macOS)
    import AppKit
#endif

public struct MenuBarStatusLabel: View {
    @ObservedObject private var model: ClockModel

    public init(model: ClockModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 3) {
            statusImage
                .accessibilityHidden(true)
            Text(ClockText.menuBarTitle(for: model.snapshot, now: model.now))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MenuBarExtra extracts Image/Text labels; a raw SwiftUI Path may be omitted.
    private var statusImage: Image {
        guard let state = model.snapshot.state else { return Image(systemName: "questionmark") }
        #if os(macOS)
            return Image(nsImage: state == .peak ? MenuBarStatusIcon.peak : MenuBarStatusIcon.valley)
        #else
            return Image(systemName: state == .valley ? "chevron.down" : "chevron.up")
        #endif
    }

    private var accessibilityText: String {
        guard let state = model.snapshot.state, let next = model.snapshot.nextChangeAt else {
            return "谷蹬，规则待更新"
        }
        let name = state == .peak ? "高峰" : "低价"
        return "谷蹬，当前\(name)时段，\(ClockText.compactRemaining(until: next, now: model.now))后切换"
    }
}
