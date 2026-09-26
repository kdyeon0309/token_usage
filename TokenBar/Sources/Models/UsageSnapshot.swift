import Foundation

enum UsageProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    var shortName: String {
        switch self {
        case .claude: "C"
        case .codex: "X"
        }
    }

    var systemImage: String {
        switch self {
        case .claude: "sparkles"
        case .codex: "terminal"
        }
    }
}

struct UsageWindow: Codable, Equatable, Sendable {
    let usedPercentage: Double
    let resetsAt: Date?
    let durationMinutes: Int?

    var remainingPercentage: Double {
        min(100, max(0, 100 - usedPercentage))
    }
}

struct TokenCounts: Codable, Equatable, Sendable {
    var input: Int64 = 0
    var output: Int64 = 0
    var cacheCreation: Int64 = 0
    var cacheRead: Int64 = 0

    var total: Int64 {
        input + output + cacheCreation + cacheRead
    }
}

struct UsageSnapshot: Codable, Equatable, Identifiable, Sendable {
    let provider: UsageProviderID
    var shortWindow: UsageWindow?
    var weeklyWindow: UsageWindow?
    var currentContextPercentage: Double?
    var currentSessionTokens: TokenCounts?
    var todayTokens: Int64?
    var lifetimeTokens: Int64?
    var estimatedCostUSD: Double?
    var updatedAt: Date
    var sourceDescription: String

    var id: UsageProviderID { provider }

    var mostConstrainedRemainingPercentage: Double? {
        [shortWindow?.remainingPercentage, weeklyWindow?.remainingPercentage]
            .compactMap { $0 }
            .min()
    }

    func isStale(at date: Date = .now, after interval: TimeInterval = 10 * 60) -> Bool {
        date.timeIntervalSince(updatedAt) > interval
    }
}

