@testable import GudengRuntime
import Foundation
import Testing
@testable import GudengCore
@testable import GudengKit

@Suite("强提醒重复的保留规则")
struct StrongRepeatRetentionTests {
    private let policy = ReminderPolicy(
        schemaVersion: 1,
        version: "test",
        defaultIntensity: .strong,
        advanceOptionsSeconds: [300],
        strongRepeatIntervalSeconds: 30,
        strongMaxRepeats: 10,
        soundEnabled: true,
        notes: nil
    )
    private let transition = KitFixture.date("2026-10-21T09:00:00+08:00")

    private func identifier(_ suffix: String) -> String {
        "lw.t:\(Int(transition.timeIntervalSince1970)).\(suffix)"
    }

    @Test("切换后一分钟内保留强提醒重复")
    func keepsLiveRepeats() {
        let kept = StrongRepeatRetention.shouldKeep(
            identifier: identifier("r3"),
            categoryIdentifier: NotificationCategory.strong,
            eventID: "t:\(Int(transition.timeIntervalSince1970))",
            now: transition.addingTimeInterval(60),
            policy: policy
        )
        #expect(kept)
    }

    @Test("超过有界窗口后不再保留")
    func dropsExpiredRepeats() {
        let kept = StrongRepeatRetention.shouldKeep(
            identifier: identifier("r9"),
            categoryIdentifier: NotificationCategory.strong,
            eventID: "t:\(Int(transition.timeIntervalSince1970))",
            now: transition.addingTimeInterval(6 * 60),
            policy: policy
        )
        #expect(!kept)
    }

    @Test("基础通知、非强分类或未知事件不保留")
    func rejectsOtherRequests() {
        let eventID = "t:\(Int(transition.timeIntervalSince1970))"
        #expect(
            !StrongRepeatRetention.shouldKeep(
                identifier: "lw.\(eventID)",
                categoryIdentifier: NotificationCategory.strong,
                eventID: eventID,
                now: transition.addingTimeInterval(30),
                policy: policy
            )
        )
        #expect(
            !StrongRepeatRetention.shouldKeep(
                identifier: identifier("r1"),
                categoryIdentifier: "",
                eventID: eventID,
                now: transition.addingTimeInterval(30),
                policy: policy
            )
        )
        #expect(
            !StrongRepeatRetention.shouldKeep(
                identifier: identifier("r1"),
                categoryIdentifier: NotificationCategory.strong,
                eventID: nil,
                now: transition.addingTimeInterval(30),
                policy: policy
            )
        )
    }
}
