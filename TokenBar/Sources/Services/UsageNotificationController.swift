import Foundation
import UserNotifications

enum UsageNotificationPolicy {
    static let thresholds = [20, 10, 5]

    static func nextThreshold(remainingPercentage: Double, previousThreshold: Int?) -> Int? {
        let reachedThreshold = thresholds
            .filter { remainingPercentage <= Double($0) }
            .min()
        guard let reachedThreshold else { return nil }
        guard previousThreshold == nil || reachedThreshold < previousThreshold! else { return nil }
        return reachedThreshold
    }
}

@MainActor
final class UsageNotificationController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var errorMessage: String?

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private var notifiedThresholds: [String: Int]

    private enum Keys {
        static let enabled = "usageNotificationsEnabled"
        static let notifiedThresholds = "usageNotifiedThresholds"
    }

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Keys.enabled)
        notifiedThresholds = defaults.dictionary(forKey: Keys.notifiedThresholds)?
            .compactMapValues { ($0 as? NSNumber)?.intValue } ?? [:]
    }

    func setEnabled(_ enabled: Bool) async {
        errorMessage = nil
        guard enabled else {
            isEnabled = false
            defaults.set(false, forKey: Keys.enabled)
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else {
                isEnabled = false
                defaults.set(false, forKey: Keys.enabled)
                errorMessage = "알림 권한이 꺼져 있습니다. 시스템 설정에서 TokenBar 알림을 허용해 주세요."
                return
            }
            isEnabled = true
            defaults.set(true, forKey: Keys.enabled)
        } catch {
            isEnabled = false
            defaults.set(false, forKey: Keys.enabled)
            errorMessage = "알림 권한을 확인하지 못했습니다."
        }
    }

    func evaluate(_ snapshots: [UsageProviderID: UsageSnapshot]) async {
        guard isEnabled else { return }

        for provider in UsageProviderID.allCases {
            guard let snapshot = snapshots[provider] else { continue }
            await evaluate(
                snapshot.shortWindow,
                provider: provider,
                windowID: "short",
                windowName: "5시간"
            )
            await evaluate(
                snapshot.weeklyWindow,
                provider: provider,
                windowID: "weekly",
                windowName: "주간"
            )
        }
    }

    private func evaluate(
        _ window: UsageWindow?,
        provider: UsageProviderID,
        windowID: String,
        windowName: String
    ) async {
        guard let window else { return }
        let cycle = window.resetsAt.map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"
        let key = "\(provider.rawValue).\(windowID).\(cycle)"
        guard let threshold = UsageNotificationPolicy.nextThreshold(
            remainingPercentage: window.remainingPercentage,
            previousThreshold: notifiedThresholds[key]
        ) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(provider.displayName) 사용량 알림"
        content.body = "\(windowName) 한도가 \(threshold)% 남았습니다."
        content.sound = .default

        do {
            try await center.add(
                UNNotificationRequest(
                    identifier: "tokenbar.\(key).\(threshold)",
                    content: content,
                    trigger: nil
                )
            )
            notifiedThresholds[key] = threshold
            defaults.set(notifiedThresholds, forKey: Keys.notifiedThresholds)
        } catch {
            errorMessage = "사용량 알림을 표시하지 못했습니다."
        }
    }
}
