import SwiftUI

@main
struct TokenBarApp: App {
    @StateObject private var store = UsageStore(
        providers: [
            ClaudeUsageProvider(),
            CodexUsageProvider(),
        ]
    )
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
                .environmentObject(launchAtLogin)
                .task {
                    store.start()
                }
        } label: {
            Label(store.menuBarTitle, systemImage: "gauge.with.dots.needle.67percent")
                .task {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
