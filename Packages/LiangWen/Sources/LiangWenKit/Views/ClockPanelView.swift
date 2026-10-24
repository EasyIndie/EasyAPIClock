import SwiftUI
import LiangWenCore

public struct ClockPanelView: View {
    private let model: ClockModel
    private let onQuit: (() -> Void)?
    @State private var showingSettings = false

    public init(model: ClockModel, onQuit: (() -> Void)? = nil) {
        self.model = model
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            if showingSettings {
                SettingsPanelContent(model: model, onQuit: onQuit)
            } else {
                MainPanelContent(model: model)
                Divider()
                footer
            }
        }
        .frame(width: 304)
    }

    private var header: some View {
        HStack {
            Text(showingSettings ? "设置" : "梁文钟")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button(showingSettings ? "完成" : "设置") {
                showingSettings.toggle()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .accessibilityLabel(showingSettings ? "完成设置" : "打开设置")
            .accessibilityHint(showingSettings ? "返回主面板" : "调整提醒与规则")
        }
        .padding(.horizontal, 19)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(ClockText.daySummary(for: model.snapshot))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(model.reminderStatusText)
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 19)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}
