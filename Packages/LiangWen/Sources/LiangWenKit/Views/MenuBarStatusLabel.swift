import SwiftUI
import LiangWenCore

public struct MenuBarStatusLabel: View {
    private let model: ClockModel

    public init(model: ClockModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbolName)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(ClockText.menuBarTitle(for: model.snapshot, now: model.now))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var symbolName: String {
        switch model.snapshot.state {
        case .peak: "chevron.up"
        case .valley: "chevron.down"
        case nil: "questionmark"
        }
    }

    private var accessibilityText: String {
        guard let state = model.snapshot.state, let next = model.snapshot.nextChangeAt else {
            return "梁文钟，规则待更新"
        }
        let name = state == .peak ? "高峰" : "低价"
        return "梁文钟，当前\(name)时段，\(ClockText.compactRemaining(until: next, now: model.now))后切换"
    }
}
