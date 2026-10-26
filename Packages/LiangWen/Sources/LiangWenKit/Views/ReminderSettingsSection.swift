import SwiftUI
import LiangWenCore

struct ReminderSettingsSection: View {
    let model: ClockModel

    var body: some View {
        SettingsSection(ClockText.remindersTitle) {
            SettingsRow(ClockText.reminderIntensityTitle) {
                Picker(ClockText.reminderIntensityTitle, selection: intensityBinding) {
                    ForEach(ReminderIntensity.allCases, id: \.self) { intensity in
                        Text(ClockText.intensityName(intensity)).tag(intensity)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 174)
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
                .buttonStyle(.plain)
                .disabled(model.preferences.intensity == .off)
                .help(ClockText.previewExplanation)
            }
            Text(model.isPreviewing ? ClockText.previewExplanation : ClockText.previewSummary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private var intensityBinding: Binding<ReminderIntensity> {
        Binding(
            get: { model.preferences.intensity },
            set: { value in
                Task { await model.setIntensity(value) }
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
