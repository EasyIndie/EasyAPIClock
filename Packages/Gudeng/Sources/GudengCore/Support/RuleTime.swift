import Foundation

/// All price decisions are made in Beijing time, independent of the device time zone.
///
/// The official DeepSeek rule is defined in Asia/Shanghai. China has no daylight
/// saving time, so a fixed Gregorian calendar is sufficient and deterministic.
public enum RuleTime {
    public static let beijingTimeZoneIdentifier = "Asia/Shanghai"
    public static let beijing: TimeZone = TimeZone(identifier: beijingTimeZoneIdentifier)!

    public static func makeCalendar(timeZone: TimeZone = beijing) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}
