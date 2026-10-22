import Foundation
@testable import LiangWenCore

enum KitTestPaths {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // LiangWenKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // LiangWen
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repository root
    }

    static var rulesDirectory: URL {
        repositoryRoot.appendingPathComponent("Rules")
    }
}

enum KitFixture {
    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else {
            fatalError("Invalid test date: \(iso)")
        }
        return date
    }

    static let rules: RuleSet = {
        do {
            return try RuleBundleLoader.load(from: KitTestPaths.rulesDirectory).ruleSet
        } catch {
            fatalError("Unable to load test rules: \(error)")
        }
    }()

    static let engine = ClockEngine(rules: rules)

    static func snapshot(at iso: String) -> PriceSnapshot {
        engine.snapshot(at: date(iso))
    }

    static func reminder(
        at iso: String,
        intensity: ReminderIntensity = .medium,
        early: Bool = false
    ) -> PlannedReminder? {
        let now = date(iso)
        return ReminderPlanner(
            now: now,
            preferences: UserPreferences(intensity: intensity, earlyReminderEnabled: early),
            policy: rules.reminderPolicy
        )
        .plan(for: engine.snapshot(at: now))
        .first
    }
}
