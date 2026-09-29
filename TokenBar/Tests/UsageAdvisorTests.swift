import XCTest
@testable import TokenBar

final class UsageAdvisorTests: XCTestCase {
    func testCalculatesSafeRateAndDepletionForecast() throws {
        let now = Date(timeIntervalSince1970: 3_600)
        let reset = Date(timeIntervalSince1970: 7_200)
        let snapshot = makeSnapshot(provider: .claude, used: 60, reset: reset)
        let history = [
            UsageSample(
                snapshot: makeSnapshot(provider: .claude, used: 20, reset: reset),
                capturedAt: now.addingTimeInterval(-30 * 60)
            ),
            UsageSample(snapshot: snapshot, capturedAt: now),
        ]

        let advice = try XCTUnwrap(
            UsageAdvisor.makeAdvice(for: snapshot, history: history, now: now)
        )

        XCTAssertEqual(try XCTUnwrap(advice.safeRatePerHour), 40, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(advice.recentRatePerHour), 80, accuracy: 0.001)
        XCTAssertEqual(advice.depletionDate, now.addingTimeInterval(30 * 60))
        XCTAssertEqual(advice.pace, .fast)
    }

    func testWaitsForEnoughHistoryBeforeForecasting() throws {
        let now = Date(timeIntervalSince1970: 3_600)
        let snapshot = makeSnapshot(
            provider: .codex,
            used: 30,
            reset: now.addingTimeInterval(3_600)
        )
        let history = [UsageSample(snapshot: snapshot, capturedAt: now)]

        let advice = try XCTUnwrap(
            UsageAdvisor.makeAdvice(for: snapshot, history: history, now: now)
        )

        XCTAssertNil(advice.recentRatePerHour)
        XCTAssertNil(advice.depletionDate)
        XCTAssertEqual(advice.pace, .learning)
    }

    func testRecommendsProviderWithMoreCapacity() throws {
        let snapshots: [UsageProviderID: UsageSnapshot] = [
            .claude: makeSnapshot(provider: .claude, used: 80, reset: nil),
            .codex: makeSnapshot(provider: .codex, used: 25, reset: nil),
        ]

        let recommendation = try XCTUnwrap(
            UsageAdvisor.recommendation(snapshots: snapshots, advice: [:])
        )

        XCTAssertEqual(recommendation.preferredProvider, .codex)
        XCTAssertTrue(recommendation.message.contains("55%p"))
    }

    func testDetectsResetThatHappensBeforeScheduledTime() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let scheduledReset = now.addingTimeInterval(2 * 60 * 60)
        let previous = UsageSample(
            snapshot: makeSnapshot(provider: .codex, used: 82, reset: scheduledReset),
            capturedAt: now.addingTimeInterval(-60)
        )
        let current = UsageSample(
            snapshot: makeSnapshot(
                provider: .codex,
                used: 3,
                reset: now.addingTimeInterval(5 * 60 * 60)
            ),
            capturedAt: now
        )

        let event = try XCTUnwrap(
            UsageAdvisor.recentUnexpectedResets(history: [previous, current], now: now).first
        )

        XCTAssertEqual(event.provider, .codex)
        XCTAssertEqual(event.window, .short)
        XCTAssertEqual(event.restoredPercentage, 79, accuracy: 0.001)
    }

    func testIgnoresResetAtScheduledTime() {
        let now = Date(timeIntervalSince1970: 10_000)
        let previous = UsageSample(
            snapshot: makeSnapshot(provider: .claude, used: 90, reset: now),
            capturedAt: now.addingTimeInterval(-60)
        )
        let current = UsageSample(
            snapshot: makeSnapshot(
                provider: .claude,
                used: 0,
                reset: now.addingTimeInterval(5 * 60 * 60)
            ),
            capturedAt: now
        )

        XCTAssertTrue(
            UsageAdvisor.recentUnexpectedResets(history: [previous, current], now: now).isEmpty
        )
    }

    private func makeSnapshot(
        provider: UsageProviderID,
        used: Double,
        reset: Date?
    ) -> UsageSnapshot {
        UsageSnapshot(
            provider: provider,
            shortWindow: UsageWindow(
                usedPercentage: used,
                resetsAt: reset,
                durationMinutes: 300
            ),
            updatedAt: .now,
            sourceDescription: "Test"
        )
    }
}
