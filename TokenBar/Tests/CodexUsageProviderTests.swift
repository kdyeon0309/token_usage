import Foundation
import XCTest
@testable import TokenBar

final class CodexUsageProviderTests: XCTestCase {
    func testReadsLatestLimitsAndDailyTokens() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let day = root.appendingPathComponent("2026/09/27", isDirectory: true)
        try FileManager.default.createDirectory(at: day, withIntermediateDirectories: true)
        let file = day.appendingPathComponent("rollout.jsonl")
        let records = [
            tokenRecord(timestamp: "2026-09-27T01:00:00.000Z", lastTokens: 100, used: 20),
            tokenRecord(timestamp: "2026-09-27T02:00:00.000Z", lastTokens: 250, used: 40),
        ].joined(separator: "\n")
        try Data(records.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = CodexUsageProvider(
            sessionsURL: root,
            now: { Date(timeIntervalSince1970: 1_790_470_800) }
        )
        let snapshot = try await provider.fetchUsage()

        XCTAssertEqual(snapshot.shortWindow?.remainingPercentage, 60)
        XCTAssertEqual(snapshot.weeklyWindow?.remainingPercentage, 40)
        XCTAssertEqual(snapshot.currentContextPercentage ?? 0, 25, accuracy: 0.001)
        XCTAssertEqual(snapshot.currentSessionTokens?.total, 500)
        XCTAssertEqual(snapshot.todayTokens, 350)
    }

    private func tokenRecord(timestamp: String, lastTokens: Int, used: Int) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":400,"cached_input_tokens":100,"cache_write_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":0,"total_tokens":500},"last_token_usage":{"input_tokens":\(lastTokens),"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":0,"reasoning_output_tokens":0,"total_tokens":\(lastTokens)},"model_context_window":2000},"rate_limits":{"primary":{"used_percent":\(used),"window_minutes":300,"resets_at":1790474400},"secondary":{"used_percent":60,"window_minutes":10080,"resets_at":1791079200}}}}
        """
    }
}

