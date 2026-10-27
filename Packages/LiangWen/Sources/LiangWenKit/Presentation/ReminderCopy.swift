import Foundation
import LiangWenCore

/// Notification copy derived from rule facts, never from hard-coded prices.
public enum ReminderCopy {
    public static func title(for reminder: PlannedReminder) -> String {
        switch reminder.kind {
        case .transition:
            return reminder.targetState == .peak ? "进入高峰" : "进入低价"
        case .advance(let lead):
            let target = reminder.targetState == .peak ? "高峰" : "低价"
            return "\(ClockText.leadPhrase(lead))后进入\(target)"
        }
    }

    /// One short line: price basis plus how long the new window lasts.
    /// Kept inside a single notification line so it is readable at a glance.
    public static func body(for reminder: PlannedReminder) -> String {
        var text: String
        if case .advance = reminder.kind {
            text = previewComparisonPhrase(reminder.facts)
        } else {
            text = comparisonPhrase(reminder.facts)
        }
        if let duration = reminder.facts.upcomingWindowDuration {
            text += " · 持续 \(ClockText.durationPhrase(duration))"
        }
        return text
    }

    public static func subtitle(for reminder: PlannedReminder) -> String? {
        // The app name is already shown by the system; only strong reminders
        // carry extra text because the stop action is not self-evident.
        reminder.intensity == .strong ? "持续提醒 · 可停止" : nil
    }

    private static func comparisonPhrase(_ facts: ReminderFacts) -> String {
        switch facts.targetState {
        case .peak:
            if let multiple = facts.comparison.multiple {
                return "单价为谷期 \(NSDecimalNumber(decimal: multiple).stringValue) 倍"
            }
            return "单价进入高峰价格时段"
        case .valley:
            if let percent = facts.comparison.valleyPercentLower {
                return "单价比峰期低 \(NSDecimalNumber(decimal: percent).stringValue)%"
            }
            return "单价进入低价价格时段"
        }
    }

    private static func previewComparisonPhrase(_ facts: ReminderFacts) -> String {
        switch facts.targetState {
        case .peak:
            if let multiple = facts.comparison.multiple {
                return "单价将升为谷期 \(NSDecimalNumber(decimal: multiple).stringValue) 倍"
            }
            return "单价将进入高峰价格时段"
        case .valley:
            if let percent = facts.comparison.valleyPercentLower {
                return "单价将比峰期低 \(NSDecimalNumber(decimal: percent).stringValue)%"
            }
            return "单价将进入低价价格时段"
        }
    }
}
