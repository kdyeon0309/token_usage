import XCTest
@testable import TokenBar

final class UsageNotificationPolicyTests: XCTestCase {
    func testChoosesReachedThreshold() {
        XCTAssertEqual(
            UsageNotificationPolicy.nextThreshold(remainingPercentage: 19, previousThreshold: nil),
            20
        )
        XCTAssertEqual(
            UsageNotificationPolicy.nextThreshold(remainingPercentage: 9, previousThreshold: 20),
            10
        )
        XCTAssertEqual(
            UsageNotificationPolicy.nextThreshold(remainingPercentage: 4, previousThreshold: 10),
            5
        )
    }

    func testDoesNotRepeatSameThreshold() {
        XCTAssertNil(
            UsageNotificationPolicy.nextThreshold(remainingPercentage: 18, previousThreshold: 20)
        )
        XCTAssertNil(
            UsageNotificationPolicy.nextThreshold(remainingPercentage: 45, previousThreshold: nil)
        )
    }
}
