import Foundation
import OSLog

struct ClaudeUsageProvider: UsageProvider {
    private static let logger = Logger(
        subsystem: "com.kdyeon0309.TokenBar",
        category: "ClaudeUsage"
    )

    let id: UsageProviderID = .claude
    private let snapshotURL: URL
    private let remoteUsageFetcher: @Sendable () async throws -> ClaudeRemoteUsage

    init(
        snapshotURL: URL = Self.defaultSnapshotURL,
        remoteUsageFetcher: (@Sendable () async throws -> ClaudeRemoteUsage)? = nil
    ) {
        self.snapshotURL = snapshotURL
        if let remoteUsageFetcher {
            self.remoteUsageFetcher = remoteUsageFetcher
        } else {
            let client = ClaudeOAuthUsageClient()
            self.remoteUsageFetcher = { try await client.fetchUsage() }
        }
    }

    static var defaultSnapshotURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TokenBar/claude.json")
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let localSnapshot = try? fetchLocalSnapshot()

        do {
            let remote = try await remoteUsageFetcher()
            Self.logger.notice("Claude usage loaded successfully")
            return UsageSnapshot(
                provider: .claude,
                shortWindow: remote.shortWindow ?? localSnapshot?.shortWindow,
                weeklyWindow: remote.weeklyWindow ?? localSnapshot?.weeklyWindow,
                currentContextPercentage: localSnapshot?.currentContextPercentage,
                currentSessionTokens: localSnapshot?.currentSessionTokens,
                estimatedCostUSD: localSnapshot?.estimatedCostUSD,
                updatedAt: remote.fetchedAt,
                sourceDescription: "Anthropic usage API"
            )
        } catch {
            Self.logger.error("Claude live usage failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func fetchLocalSnapshot() throws -> UsageSnapshot {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            throw UsageProviderError.unavailable("Claude 로컬 사용량 파일을 찾을 수 없습니다.")
        }
        let data: Data
        do {
            data = try Data(contentsOf: snapshotURL)
        } catch {
            throw UsageProviderError.unavailable("Claude 사용량 파일을 읽을 수 없습니다.")
        }

        do {
            return try ClaudeStatusSnapshot.decode(data).usageSnapshot
        } catch {
            throw UsageProviderError.invalidData("Claude 사용량 형식이 올바르지 않습니다.")
        }
    }
}

private struct ClaudeStatusSnapshot: Decodable {
    struct Model: Decodable {
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    struct Cost: Decodable {
        let totalCostUSD: Double?

        enum CodingKeys: String, CodingKey {
            case totalCostUSD = "total_cost_usd"
        }
    }

    struct ContextWindow: Decodable {
        struct CurrentUsage: Decodable {
            let inputTokens: Int64?
            let outputTokens: Int64?
            let cacheCreationInputTokens: Int64?
            let cacheReadInputTokens: Int64?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }

        let usedPercentage: Double?
        let currentUsage: CurrentUsage?

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case currentUsage = "current_usage"
        }
    }

    struct RateLimits: Decodable {
        struct Window: Decodable {
            let usedPercentage: Double
            let resetsAt: TimeInterval?

            enum CodingKeys: String, CodingKey {
                case usedPercentage = "used_percentage"
                case resetsAt = "resets_at"
            }

            var usageWindow: UsageWindow {
                UsageWindow(
                    usedPercentage: usedPercentage,
                    resetsAt: resetsAt.map(Date.init(timeIntervalSince1970:)),
                    durationMinutes: nil
                )
            }
        }

        let fiveHour: Window?
        let sevenDay: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    let capturedAt: TimeInterval
    let model: Model?
    let cost: Cost?
    let contextWindow: ContextWindow?
    let rateLimits: RateLimits?

    enum CodingKeys: String, CodingKey {
        case capturedAt = "captured_at"
        case model
        case cost
        case contextWindow = "context_window"
        case rateLimits = "rate_limits"
    }

    static func decode(_ data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    var usageSnapshot: UsageSnapshot {
        let currentUsage = contextWindow?.currentUsage
        let tokens = currentUsage.map {
            TokenCounts(
                input: $0.inputTokens ?? 0,
                output: $0.outputTokens ?? 0,
                cacheCreation: $0.cacheCreationInputTokens ?? 0,
                cacheRead: $0.cacheReadInputTokens ?? 0
            )
        }

        return UsageSnapshot(
            provider: .claude,
            shortWindow: rateLimits?.fiveHour?.usageWindow,
            weeklyWindow: rateLimits?.sevenDay?.usageWindow,
            currentContextPercentage: contextWindow?.usedPercentage,
            currentSessionTokens: tokens,
            estimatedCostUSD: cost?.totalCostUSD,
            updatedAt: Date(timeIntervalSince1970: capturedAt),
            sourceDescription: "Claude Code Status Line"
        )
    }
}

