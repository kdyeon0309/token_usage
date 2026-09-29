import Foundation

enum BillingSchedule {
    static func nextBillingDate(
        from configuredDate: Date,
        after now: Date,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        let configured = calendar.startOfDay(for: configuredDate)
        if configured >= today { return configured }

        let billingDay = calendar.component(.day, from: configured)
        var month = calendar.dateComponents([.year, .month], from: today)

        for _ in 0..<24 {
            guard let monthStart = calendar.date(from: month),
                  let days = calendar.range(of: .day, in: .month, for: monthStart) else {
                break
            }
            var candidateComponents = month
            candidateComponents.day = min(billingDay, days.count)
            if let candidate = calendar.date(from: candidateComponents), candidate >= today {
                return candidate
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                break
            }
            month = calendar.dateComponents([.year, .month], from: nextMonth)
        }

        return configured
    }

    static func daysRemaining(
        until billingDate: Date,
        from now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: billingDate)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}
