import Foundation
import Testing
@testable import LiangWenCore

@Suite("LocalDate 与时间类型")
struct LocalDateTests {
    @Test("解析有效日期")
    func parsesValidDate() throws {
        let date = try #require(LocalDate(iso8601: "2026-10-23"))
        #expect(date.year == 2026)
        #expect(date.month == 10)
        #expect(date.day == 23)
        #expect(date.description == "2026-10-23")
    }

    @Test("拒绝不存在的日期")
    func rejectsInvalidDates() {
        #expect(LocalDate(iso8601: "2026-02-29") == nil)
        #expect(LocalDate(iso8601: "2026-13-01") == nil)
        #expect(LocalDate(iso8601: "2026-1-1") == nil)
        #expect(LocalDate(iso8601: "not-a-date") == nil)
        #expect(LocalDate(iso8601: "2024-02-29") != nil)
    }

    @Test("日期比较与范围")
    func comparisonAndRange() throws {
        let first = try #require(LocalDate(iso8601: "2026-01-01"))
        let last = try #require(LocalDate(iso8601: "2026-12-31"))
        let middle = try #require(LocalDate(iso8601: "2026-06-01"))
        #expect(first < middle)
        #expect(middle < last)
        let range = LocalDateRange(from: first, through: last)
        #expect(range.contains(middle))
        #expect(!range.contains(try #require(LocalDate(iso8601: "2027-01-01"))))
    }

    @Test("分钟解析与左闭右开比较")
    func minuteOfDay() throws {
        let start = try #require(MinuteOfDay(iso8601: "09:00"))
        let end = try #require(MinuteOfDay(iso8601: "12:00"))
        #expect(start.minutes == 540)
        #expect(start.description == "09:00")
        #expect(MinuteOfDay(iso8601: "24:00")?.minutes == 1440)
        #expect(MinuteOfDay(iso8601: "09:60") == nil)
        #expect(start < end)
    }

    @Test("金额从字符串精确解码")
    func decimalAmountDecoding() throws {
        let data = Data("\"0.02\"".utf8)
        let amount = try JSONDecoder().decode(DecimalAmount.self, from: data)
        #expect(amount.description == "0.02")
        let numeric = try JSONDecoder().decode(DecimalAmount.self, from: Data("4.5".utf8))
        #expect(numeric.description == "4.5")
    }
}
