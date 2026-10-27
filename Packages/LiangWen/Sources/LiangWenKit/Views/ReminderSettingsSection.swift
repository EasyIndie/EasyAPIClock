import SwiftUI
import LiangWenCore

struct ReminderSettingsSection: View {
    @ObservedObject var model: ClockModel
    @AppStorage("gudeng.animations") private var animations = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsRow(ClockText.reminderIntensityTitle) {
                SettingsSegments(
                    title: ClockText.reminderIntensityTitle,
                    titles: ReminderIntensity.allCases.map(ClockText.intensityName),
                    selection: intensityBinding
                )
                .help(ClockText.reminderExplanation)
            }
            SettingsRow(model.advanceLeadText) {
                Toggle(model.advanceLeadText, isOn: earlyBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            SettingsRow(model.isPreviewing ? ClockText.previewStop : ClockText.previewTitle) {
                Button(action: togglePreview) {
                    Label(
                        model.isPreviewing ? ClockText.previewStop : ClockText.previewTitle,
                        systemImage: model.isPreviewing ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PanelIconButtonStyle())
                .scaleEffect(model.isPreviewing && animations && !reduceMotion ? 1.06 : 1)
                .animation(
                    model.isPreviewing && animations && !reduceMotion
                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : nil,
                    value: model.isPreviewing && animations && !reduceMotion
                )
                .disabled(model.preferences.intensity == .off)
                .help(ClockText.previewExplanation(for: model.preferences.intensity))
            }
            if model.isPreviewing {
                Text(ClockText.previewExplanation(for: model.preferences.intensity))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !model.previewMessage.isEmpty {
                Text(model.previewMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.authorization.isDenied, model.preferences.intensity != .off {
                SettingsRow(ClockText.notificationDisabledTitle) {
                    Button(ClockText.notificationSettingsTitle, action: model.openNotificationSettings)
                        .controlSize(.small)
                }
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            }
        }
    }

    private func togglePreview() {
        if model.isPreviewing { model.stopPreview() } else { model.startPreview() }
    }

    private var intensityBinding: Binding<Int> {
        Binding(
            get: { ReminderIntensity.allCases.firstIndex(of: model.preferences.intensity) ?? 0 },
            set: { index in
                guard ReminderIntensity.allCases.indices.contains(index) else { return }
                Task { await model.setIntensity(ReminderIntensity.allCases[index]) }
            })
    }

    private var earlyBinding: Binding<Bool> {
        Binding(
            get: { model.preferences.earlyReminderEnabled },
            set: { value in
                Task { await model.setEarlyReminderEnabled(value) }
            })
    }
}
