import Foundation

struct UsageSample: Codable, Equatable, Sendable {
    let provider: UsageProviderID
    let capturedAt: Date
    let shortUsedPercentage: Double?
    let shortResetsAt: Date?

    init(snapshot: UsageSnapshot, capturedAt: Date) {
        provider = snapshot.provider
        self.capturedAt = capturedAt
        shortUsedPercentage = snapshot.shortWindow?.usedPercentage
        shortResetsAt = snapshot.shortWindow?.resetsAt
    }
}

enum UsagePace: Equatable, Sendable {
    case learning
    case stable
    case fast
}

struct ProviderUsageAdvice: Equatable, Sendable {
    let safeRatePerHour: Double?
    let recentRatePerHour: Double?
    let depletionDate: Date?
    let resetDate: Date?
    let pace: UsagePace
}

struct UsageRecommendation: Equatable, Sendable {
    let preferredProvider: UsageProviderID?
    let message: String
}

enum UsageAdvisor {
    private static let observationWindow: TimeInterval = 60 * 60
    private static let minimumObservationInterval: TimeInterval = 5 * 60

    static func makeAdvice(
        snapshots: [UsageProviderID: UsageSnapshot],
        history: [UsageSample],
        now: Date
    ) -> [UsageProviderID: ProviderUsageAdvice] {
        Dictionary(uniqueKeysWithValues: snapshots.compactMap { provider, snapshot in
            guard let advice = makeAdvice(for: snapshot, history: history, now: now) else {
                return nil
            }
            return (provider, advice)
        })
    }

    static func makeAdvice(
        for snapshot: UsageSnapshot,
        history: [UsageSample],
        now: Date
    ) -> ProviderUsageAdvice? {
        guard let window = snapshot.shortWindow else { return nil }

        let hoursUntilReset = window.resetsAt.map {
            max(0, $0.timeIntervalSince(now) / 3600)
        }
        let safeRate = hoursUntilReset.flatMap { hours in
            hours > 0 ? window.remainingPercentage / hours : nil
        }

        let matchingSamples = history
            .filter {
                $0.provider == snapshot.provider
                    && $0.capturedAt >= now.addingTimeInterval(-observationWindow)
                    && $0.capturedAt <= now
                    && sameResetCycle($0.shortResetsAt, window.resetsAt)
                    && $0.shortUsedPercentage != nil
            }
            .sorted { $0.capturedAt < $1.capturedAt }

        guard let latest = matchingSamples.last,
              let oldest = matchingSamples.first(where: {
                  latest.capturedAt.timeIntervalSince($0.capturedAt) >= minimumObservationInterval
              }),
              let oldestUsed = oldest.shortUsedPercentage,
              let latestUsed = latest.shortUsedPercentage else {
            return ProviderUsageAdvice(
                safeRatePerHour: safeRate,
                recentRatePerHour: nil,
                depletionDate: nil,
                resetDate: window.resetsAt,
                pace: .learning
            )
        }

        let elapsedHours = latest.capturedAt.timeIntervalSince(oldest.capturedAt) / 3600
        let usedDelta = max(0, latestUsed - oldestUsed)
        let recentRate = elapsedHours > 0 ? usedDelta / elapsedHours : 0
        let depletionDate = recentRate > 0
            ? now.addingTimeInterval(window.remainingPercentage / recentRate * 3600)
            : nil
        let isFast = safeRate.map { recentRate > $0 * 1.1 } ?? false

        return ProviderUsageAdvice(
            safeRatePerHour: safeRate,
            recentRatePerHour: recentRate,
            depletionDate: depletionDate,
            resetDate: window.resetsAt,
            pace: isFast ? .fast : .stable
        )
    }

    static func recommendation(
        snapshots: [UsageProviderID: UsageSnapshot],
        advice: [UsageProviderID: ProviderUsageAdvice]
    ) -> UsageRecommendation? {
        let available = UsageProviderID.allCases.compactMap { provider -> (UsageProviderID, Double)? in
            guard let remaining = snapshots[provider]?.mostConstrainedRemainingPercentage else {
                return nil
            }
            return (provider, remaining)
        }
        guard available.count == 2 else { return nil }

        if advice[.claude]?.pace == .fast, advice[.codex]?.pace != .fast {
            return UsageRecommendation(
                preferredProvider: .codex,
                message: "Claude 사용 속도가 빠릅니다. Codex 사용을 권장합니다."
            )
        }
        if advice[.codex]?.pace == .fast, advice[.claude]?.pace != .fast {
            return UsageRecommendation(
                preferredProvider: .claude,
                message: "Codex 사용 속도가 빠릅니다. Claude 사용을 권장합니다."
            )
        }

        let sorted = available.sorted { $0.1 > $1.1 }
        let difference = sorted[0].1 - sorted[1].1
        guard difference >= 10 else {
            return UsageRecommendation(
                preferredProvider: nil,
                message: "두 서비스의 잔여량이 비슷합니다."
            )
        }

        return UsageRecommendation(
            preferredProvider: sorted[0].0,
            message: "\(sorted[0].0.displayName)가 \(Int(difference.rounded()))%p 더 여유롭습니다."
        )
    }

    private static func sameResetCycle(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            true
        case let (.some(lhs), .some(rhs)):
            abs(lhs.timeIntervalSince(rhs)) < 60
        default:
            false
        }
    }
}
