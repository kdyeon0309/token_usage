import AppKit
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [UsageProviderID: UsageSnapshot] = [:]
    @Published private(set) var errors: [UsageProviderID: String] = [:]
    @Published private(set) var advice: [UsageProviderID: ProviderUsageAdvice] = [:]
    @Published private(set) var recommendation: UsageRecommendation?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isInstallingClaudeBridge = false
    @Published private(set) var setupMessage: String?

    private let providers: [any UsageProvider]
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: Duration
    private let historyStore: UsageHistoryStore
    private let now: @Sendable () -> Date

    init(
        providers: [any UsageProvider],
        refreshInterval: Duration = .seconds(60),
        historyStore: UsageHistoryStore = UsageHistoryStore(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.providers = providers
        self.refreshInterval = refreshInterval
        self.historyStore = historyStore
        self.now = now
    }

    deinit {
        refreshTask?.cancel()
    }

    func menuBarTitle(for mode: MenuBarDisplayMode) -> String {
        let parts = UsageProviderID.allCases.compactMap { provider -> String? in
            guard let percentage = snapshots[provider]?.mostConstrainedRemainingPercentage else {
                return nil
            }
            return "\(provider.shortName) \(Int(percentage.rounded()))%"
        }
        guard !parts.isEmpty else { return "--" }

        switch mode {
        case .allProviders:
            return parts.joined(separator: " · ")
        case .lowestRemaining:
            return UsageProviderID.allCases
                .compactMap { provider -> (UsageProviderID, Double)? in
                    guard let remaining = snapshots[provider]?.mostConstrainedRemainingPercentage else {
                        return nil
                    }
                    return (provider, remaining)
                }
                .min { $0.1 < $1.1 }
                .map { "\($0.0.shortName) \(Int($0.1.rounded()))%" } ?? "--"
        case .iconOnly:
            return ""
        }
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: refreshInterval)
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: (UsageProviderID, Result<UsageSnapshot, Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return (provider.id, .success(try await provider.fetchUsage()))
                    } catch {
                        return (provider.id, .failure(error))
                    }
                }
            }

            for await (id, result) in group {
                switch result {
                case .success(let snapshot):
                    snapshots[id] = snapshot
                    errors[id] = nil
                case .failure(let error):
                    errors[id] = error.localizedDescription
                }
            }
        }

        await updateAdvice()
    }

    private func updateAdvice() async {
        let currentDate = now()
        let history = (try? await historyStore.record(Array(snapshots.values), at: currentDate)) ?? []
        advice = UsageAdvisor.makeAdvice(
            snapshots: snapshots,
            history: history,
            now: currentDate
        )
        recommendation = UsageAdvisor.recommendation(snapshots: snapshots, advice: advice)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func installClaudeBridge() async {
        guard !isInstallingClaudeBridge else { return }
        isInstallingClaudeBridge = true
        defer { isInstallingClaudeBridge = false }

        do {
            setupMessage = try await ClaudeBridgeInstaller().install()
        } catch {
            setupMessage = error.localizedDescription
        }
    }
}
