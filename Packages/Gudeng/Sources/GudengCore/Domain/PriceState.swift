import Foundation

/// The two price states published by DeepSeek.
public enum PriceState: String, Sendable, Codable, CaseIterable {
    case peak
    case valley
}

/// The reason a date resolves to a price schedule.
public enum DayKind: Sendable, Equatable {
    case weekday
    case weekend
    case holiday(name: String)
}

/// Coarse period of a weekday, used only for display summaries.
public enum WeekdayPeriod: Sendable, Equatable {
    case early
    case morningPeak
    case midday
    case afternoonPeak
    case evening
}

/// Why the engine could not confirm a price state or its next transition.
public enum RuleIssue: Sendable, Equatable {
    /// The date calendar does not cover the requested date.
    case calendarExpired(through: LocalDate)
    /// The requested weekday is outside the verified date coverage.
    case dateUnverified(LocalDate)
    /// No transition could be confirmed inside the search horizon.
    case nextChangeUnconfirmed
}
