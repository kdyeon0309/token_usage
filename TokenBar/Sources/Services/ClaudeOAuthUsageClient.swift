import Foundation

struct ClaudeRemoteUsage: Sendable {
    let shortWindow: UsageWindow?
    let weeklyWindow: UsageWindow?
}

struct ClaudeOAuthUsageClient: Sendable {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func fetchUsage() async throws -> ClaudeRemoteUsage {
        let credentials = try await loadCredentials()
        return try await requestUsage(accessToken: credentials.claudeAiOauth.accessToken)
    }

    private func loadCredentials() async throws -> ClaudeCredentials {
        let data = try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            process.arguments = [
                "find-generic-password",
                "-s", "Claude Code-credentials",
                "-w",
            ]

            let standardOutput = Pipe()
            let standardError = Pipe()
            process.standardOutput = standardOutput
            process.standardError = standardError

            do {
                try process.run()
            } catch {
                throw UsageProviderError.processFailed("Claude 로그인 정보를 읽을 수 없습니다.")
            }

            let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
            _ = standardError.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0, !output.isEmpty else {
                throw UsageProviderError.unavailable(
                    "Claude Code 로그인을 찾을 수 없습니다. 터미널에서 Claude Code에 로그인해 주세요."
                )
            }
            return output
        }.value

        do {
            return try JSONDecoder().decode(ClaudeCredentials.self, from: data)
        } catch {
            throw UsageProviderError.invalidData("Claude 로그인 정보 형식이 올바르지 않습니다.")
        }
    }

    private func requestUsage(accessToken: String) async throws -> ClaudeRemoteUsage {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageProviderError.unavailable("Anthropic 사용량 서버에 연결할 수 없습니다.")
        }

        guard let response = response as? HTTPURLResponse else {
            throw UsageProviderError.invalidData("Anthropic 사용량 응답을 확인할 수 없습니다.")
        }
        guard response.statusCode == 200 else {
            if response.statusCode == 401 {
                throw UsageProviderError.unavailable(
                    "Claude 로그인이 만료되었습니다. Claude Code를 실행해 로그인을 갱신해 주세요."
                )
            }
            if response.statusCode == 429 {
                throw UsageProviderError.unavailable("Claude 사용량 조회가 잠시 제한되었습니다.")
            }
            throw UsageProviderError.unavailable(
                "Claude 사용량 조회에 실패했습니다. (HTTP \(response.statusCode))"
            )
        }

        let report: ClaudeUsageReport
        do {
            report = try JSONDecoder().decode(ClaudeUsageReport.self, from: data)
        } catch {
            throw UsageProviderError.invalidData("Claude 사용량 응답 형식이 올바르지 않습니다.")
        }

        return ClaudeRemoteUsage(
            shortWindow: report.fiveHour?.usageWindow(durationMinutes: 5 * 60),
            weeklyWindow: report.sevenDay?.usageWindow(durationMinutes: 7 * 24 * 60)
        )
    }
}

private struct ClaudeCredentials: Decodable {
    struct OAuth: Decodable {
        let accessToken: String
    }

    let claudeAiOauth: OAuth
}

private struct ClaudeUsageReport: Decodable {
    struct Window: Decodable {
        let utilization: Double
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }

        func usageWindow(durationMinutes: Int) -> UsageWindow {
            UsageWindow(
                usedPercentage: utilization,
                resetsAt: resetsAt.flatMap(Self.parseDate),
                durationMinutes: durationMinutes
            )
        }

        private static func parseDate(_ value: String) -> Date? {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}
