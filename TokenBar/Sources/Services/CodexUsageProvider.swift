import Foundation

struct CodexUsageProvider: UsageProvider {
    let id: UsageProviderID = .codex
    private let sessionsURL: URL
    private let now: @Sendable () -> Date

    init(
        sessionsURL: URL = Self.defaultSessionsURL,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.sessionsURL = sessionsURL
        self.now = now
    }

    static var defaultSessionsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard FileManager.default.fileExists(atPath: sessionsURL.path) else {
            throw UsageProviderError.unavailable("Codex 세션 폴더를 찾을 수 없습니다.")
        }

        let files = try recentSessionFiles()
        guard let latest = try latestTokenRecord(in: files) else {
            throw UsageProviderError.unavailable("Codex를 한 번 사용하면 사용량이 표시됩니다.")
        }
        guard let info = latest.payload.info else {
            throw UsageProviderError.invalidData("Codex 토큰 사용량 필드가 없습니다.")
        }

        let windows = latest.rateLimitWindows
        let totals = info.totalTokenUsage
        let cachedInput = min(totals?.cachedInputTokens ?? 0, totals?.inputTokens ?? 0)
        let tokenCounts = totals.map {
            TokenCounts(
                input: max(0, $0.inputTokens - cachedInput),
                output: $0.outputTokens,
                cacheCreation: $0.cacheWriteInputTokens,
                cacheRead: cachedInput
            )
        }
        let contextPercentage: Double?
        if let total = totals?.totalTokens,
           let window = info.modelContextWindow,
           window > 0 {
            contextPercentage = min(100, Double(total) / Double(window) * 100)
        } else {
            contextPercentage = nil
        }

        return UsageSnapshot(
            provider: .codex,
            shortWindow: windows.short,
            weeklyWindow: windows.weekly,
            currentContextPercentage: contextPercentage,
            currentSessionTokens: tokenCounts,
            todayTokens: try todayTokenTotal(),
            updatedAt: latest.date ?? now(),
            sourceDescription: "Codex local session log"
        )
    }

    private func recentSessionFiles() throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var datedFiles: [(url: URL, date: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            datedFiles.append((url, values?.contentModificationDate ?? .distantPast))
        }
        return datedFiles
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map(\.url)
    }

    private func latestTokenRecord(in files: [URL]) throws -> CodexTokenRecord? {
        for file in files {
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            for line in data.split(separator: 0x0A).reversed() {
                guard let record = try? JSONDecoder().decode(CodexTokenRecord.self, from: Data(line)),
                      record.payload.type == "token_count",
                      record.payload.info != nil else {
                    continue
                }
                return record
            }
        }
        return nil
    }

    private func todayTokenTotal() throws -> Int64? {
        let calendar = Calendar.current
        let date = now()
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return nil
        }

        let dayDirectory = sessionsURL
            .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", day), isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dayDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var total: Int64 = 0
        var foundUsage = false
        for file in files where file.pathExtension == "jsonl" {
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            for line in data.split(separator: 0x0A) {
                guard let record = try? JSONDecoder().decode(CodexTokenRecord.self, from: Data(line)),
                      record.payload.type == "token_count",
                      let lastUsage = record.payload.info?.lastTokenUsage else {
                    continue
                }
                total += lastUsage.totalTokens
                foundUsage = true
            }
        }
        return foundUsage ? total : nil
    }
}

private struct CodexTokenRecord: Decodable {
    struct Payload: Decodable {
        struct Info: Decodable {
            let totalTokenUsage: TokenUsage?
            let lastTokenUsage: TokenUsage?
            let modelContextWindow: Int64?

            enum CodingKeys: String, CodingKey {
                case totalTokenUsage = "total_token_usage"
                case lastTokenUsage = "last_token_usage"
                case modelContextWindow = "model_context_window"
            }
        }

        struct RateLimits: Decodable {
            let primary: RateLimitWindow?
            let secondary: RateLimitWindow?
        }

        let type: String
        let info: Info?
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case type
            case info
            case rateLimits = "rate_limits"
        }
    }

    struct TokenUsage: Decodable {
        let inputTokens: Int64
        let cachedInputTokens: Int64
        let cacheWriteInputTokens: Int64
        let outputTokens: Int64
        let totalTokens: Int64

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cachedInputTokens = "cached_input_tokens"
            case cacheWriteInputTokens = "cache_write_input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
        }
    }

    struct RateLimitWindow: Decodable {
        let usedPercent: Double
        let windowMinutes: Int?
        let resetsAt: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case windowMinutes = "window_minutes"
            case resetsAt = "resets_at"
        }

        var usageWindow: UsageWindow {
            UsageWindow(
                usedPercentage: usedPercent,
                resetsAt: resetsAt.map(Date.init(timeIntervalSince1970:)),
                durationMinutes: windowMinutes
            )
        }
    }

    let timestamp: String?
    let payload: Payload

    var date: Date? {
        guard let timestamp else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp)
            ?? ISO8601DateFormatter().date(from: timestamp)
    }

    var rateLimitWindows: (short: UsageWindow?, weekly: UsageWindow?) {
        let values = [payload.rateLimits?.primary, payload.rateLimits?.secondary].compactMap { $0 }
        let short = values
            .filter { ($0.windowMinutes ?? .max) < 24 * 60 }
            .min { ($0.windowMinutes ?? .max) < ($1.windowMinutes ?? .max) }
            .map(\.usageWindow)
        let weekly = values
            .filter { ($0.windowMinutes ?? 0) >= 24 * 60 }
            .max { ($0.windowMinutes ?? 0) < ($1.windowMinutes ?? 0) }
            .map(\.usageWindow)
        return (short, weekly)
    }
}
