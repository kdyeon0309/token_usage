import XCTest
@testable import TokenBar

final class BillingScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testKeepsConfiguredUpcomingDate() {
        let configured = date(2026, 10, 15)
        let next = BillingSchedule.nextBillingDate(
            from: configured,
            after: date(2026, 9, 29),
            calendar: calendar
        )

        XCTAssertEqual(next, configured)
        XCTAssertEqual(
            BillingSchedule.daysRemaining(
                until: next,
                from: date(2026, 9, 29),
                calendar: calendar
            ),
            16
        )
    }

    func testAdvancesPastDateToCurrentBillingMonth() {
        let next = BillingSchedule.nextBillingDate(
            from: date(2025, 1, 31),
            after: date(2025, 2, 1),
            calendar: calendar
        )

        XCTAssertEqual(next, date(2025, 2, 28))
    }

    func testBillingDateTodayHasNoRemainingDays() {
        let today = date(2026, 9, 29)
        XCTAssertEqual(
            BillingSchedule.daysRemaining(until: today, from: today, calendar: calendar),
            0
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
