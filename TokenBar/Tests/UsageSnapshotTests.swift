import XCTest
@testable import TokenBar

final class UsageSnapshotTests: XCTestCase {
    func testRemainingPercentageIsClamped() {
        XCTAssertEqual(UsageWindow(usedPercentage: 27, resetsAt: nil, durationMinutes: nil).remainingPercentage, 73)
        XCTAssertEqual(UsageWindow(usedPercentage: 120, resetsAt: nil, durationMinutes: nil).remainingPercentage, 0)
        XCTAssertEqual(UsageWindow(usedPercentage: -4, resetsAt: nil, durationMinutes: nil).remainingPercentage, 100)
    }

    func testMostConstrainedWindow() {
        let snapshot = UsageSnapshot(
            provider: .codex,
            shortWindow: UsageWindow(usedPercentage: 30, resetsAt: nil, durationMinutes: 300),
            weeklyWindow: UsageWindow(usedPercentage: 65, resetsAt: nil, durationMinutes: 10_080),
            updatedAt: .now,
            sourceDescription: "Test"
        )

        XCTAssertEqual(snapshot.mostConstrainedRemainingPercentage, 35)
    }

    func testStaleSnapshot() {
        let snapshot = UsageSnapshot(
            provider: .claude,
            updatedAt: Date(timeIntervalSince1970: 0),
            sourceDescription: "Test"
        )

        XCTAssertTrue(snapshot.isStale(at: Date(timeIntervalSince1970: 601)))
    }
}

