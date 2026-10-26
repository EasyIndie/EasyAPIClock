import Foundation
import LiangWenCore

/// Notification copy derived from rule facts, never from hard-coded prices.
public enum ReminderCopy {
    public static func title(for reminder: PlannedReminder) -> String {
        switch reminder.kind {
        case .transition:
            return reminder.targetState == .peak ? "高峰时段开始" : "低价时段开始"
        case .advance(let lead):
            let target = reminder.targetState == .peak ? "高峰" : "低价时段"
            return "还有 \(ClockText.leadPhrase(lead))进入\(target)"
        }
    }

    public static func body(for reminder: PlannedReminder) -> String {
        let duration = reminder.facts.upcomingWindowDuration
        switch reminder.kind {
        case .advance:
            let window = reminder.targetState == .peak ? "高峰" : "低价"
            var text = "模型单价即将\(reminder.targetState == .peak ? "上升" : "下降")。"
            if let duration {
                text += "本次\(window)持续 \(ClockText.durationPhrase(duration))。"
            }
            return text
        case .transition:
            var text = comparisonSentence(reminder.facts) + "。"
            if let duration {
                if reminder.targetState == .peak {
                    text += "距离下次低价还有 \(ClockText.durationPhrase(duration))。"
                } else {
                    text += "本次低价持续 \(ClockText.durationPhrase(duration))。"
                }
            }
            return text
        }
    }

    public static func subtitle(for reminder: PlannedReminder) -> String? {
        switch reminder.intensity {
        case .off:
            return nil
        case .medium:
            return "谷蹬 · 中等提醒 · 短音一次"
        case .strong:
            return "谷蹬 · 强提醒 · 持续至关闭"
        }
    }

    private static func comparisonSentence(_ facts: ReminderFacts) -> String {
        switch facts.targetState {
        case .peak:
            if let multiple = facts.comparison.multiple {
                return "模型单价为谷期的 \(NSDecimalNumber(decimal: multiple).stringValue) 倍"
            }
            return "模型单价进入高峰价格时段"
        case .valley:
            if let percent = facts.comparison.valleyPercentLower {
                return "模型单价较峰期低 \(NSDecimalNumber(decimal: percent).stringValue)%"
            }
            return "模型单价进入空闲价格时段"
        }
    }
}
