import AppKit
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [UsageProviderID: UsageSnapshot] = [:]
    @Published private(set) var errors: [UsageProviderID: String] = [:]
    @Published private(set) var isRefreshing = false

    private let providers: [any UsageProvider]
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: Duration

    init(providers: [any UsageProvider], refreshInterval: Duration = .seconds(60)) {
        self.providers = providers
        self.refreshInterval = refreshInterval
    }

    deinit {
        refreshTask?.cancel()
    }

    var menuBarTitle: String {
        let parts = UsageProviderID.allCases.compactMap { provider -> String? in
            guard let percentage = snapshots[provider]?.mostConstrainedRemainingPercentage else {
                return nil
            }
            return "\(provider.shortName) \(Int(percentage.rounded()))%"
        }
        return parts.isEmpty ? "--" : parts.joined(separator: " · ")
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
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}

