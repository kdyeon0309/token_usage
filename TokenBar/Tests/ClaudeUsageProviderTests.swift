import Foundation
import XCTest
@testable import TokenBar

final class ClaudeUsageProviderTests: XCTestCase {
    func testDecodesBridgeSnapshot() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        let json = """
        {
          "captured_at": 1700000000,
          "cost": {"total_cost_usd": 1.25},
          "context_window": {
            "used_percentage": 42,
            "current_usage": {
              "input_tokens": 100,
              "output_tokens": 20,
              "cache_creation_input_tokens": 30,
              "cache_read_input_tokens": 50
            }
          },
          "rate_limits": {
            "five_hour": {"used_percentage": 25, "resets_at": 1700003600},
            "seven_day": {"used_percentage": 60, "resets_at": 1700604800}
          }
        }
        """
        try Data(json.utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let snapshot = try await ClaudeUsageProvider(snapshotURL: fileURL).fetchUsage()

        XCTAssertEqual(snapshot.shortWindow?.remainingPercentage, 75)
        XCTAssertEqual(snapshot.weeklyWindow?.remainingPercentage, 40)
        XCTAssertEqual(snapshot.currentContextPercentage, 42)
        XCTAssertEqual(snapshot.currentSessionTokens?.total, 200)
        XCTAssertEqual(snapshot.estimatedCostUSD, 1.25)
        XCTAssertEqual(snapshot.updatedAt, Date(timeIntervalSince1970: 1_700_000_000))
    }
}

