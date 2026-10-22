import SwiftUI
import LiangWenCore

struct SettingsPanelContent: View {
    let model: ClockModel
    let onQuit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("提醒强度")
                Spacer(minLength: 8)
                Picker("提醒强度", selection: intensityBinding) {
                    ForEach(ReminderIntensity.allCases, id: \.self) { intensity in
                        Text(ClockText.intensityName(intensity)).tag(intensity)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 88)
            }

            Toggle(model.advanceLeadText, isOn: earlyBinding)
                .toggleStyle(.switch)
                .controlSize(.small)

            Text("中等：通知与短音一次\n强：持续提示，手动关闭")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.top, 2)

            ruleInfo

            if let pending = model.ruleStatus.pendingVersion {
                Text("已下载规则包 \(pending)，将在生效时间自动启用。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if model.ruleStatus.installedError != nil {
                Text("已下载规则无效，继续使用内置规则。")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
            if model.authorization.isDenied, model.preferences.intensity != .off {
                HStack(spacing: 8) {
                    Text("系统通知未开启")
                        .foregroundStyle(.orange)
                    Spacer(minLength: 8)
                    Button("打开系统设置") {
                        model.openNotificationSettings()
                    }
                    .font(.system(size: 11))
                }
                .font(.system(size: 11))
            }

            Button {
                Task { await model.checkForUpdates() }
            } label: {
                Text(model.isCheckingForUpdates ? "正在检查…" : "检查规则更新")
                    .frame(maxWidth: .infinity)
            }
            .disabled(model.isCheckingForUpdates)

            if !model.updateMessage.isEmpty {
                Text(model.updateMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onQuit {
                Button("退出梁文钟") {
                    onQuit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .accessibilityHint("退出应用后不再重新排定提醒")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 19)
        .padding(.top, 10)
        .padding(.bottom, 19)
    }

    private var ruleInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("DeepSeek 官方价格 · 北京时间")
            Text("价格规则 \(model.ruleStatus.pricingVersion) · 日期数据 \(model.ruleStatus.calendarVersion)")
            Text("覆盖 \(ClockText.coverageText(model.ruleStatus.coverage))")
            Text("\(model.ruleStatus.originText) · 价格核对于 \(ClockText.checkedAtText(model.ruleStatus.checkedAt))")
            Text("日期核对于 \(ClockText.checkedAtText(model.ruleStatus.calendarCheckedAt))")
            if let issue = model.snapshot.issue {
                Text(ClockText.issueText(issue))
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 10) {
                Link("价格来源", destination: model.ruleStatus.sourceURL)
                Link("日期来源", destination: model.ruleStatus.calendarSourceURL)
            }
            .padding(.top, 2)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var intensityBinding: Binding<ReminderIntensity> {
        Binding(
            get: { model.preferences.intensity },
            set: { value in
                Task { await model.setIntensity(value) }
            }
        )
    }

    private var earlyBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.earlyReminderEnabled },
            set: { value in
                Task { await model.setEarlyReminderEnabled(value) }
            }
        )
    }
}
