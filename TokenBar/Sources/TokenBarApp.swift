import SwiftUI

@main
struct TokenBarApp: App {
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayModeRaw = MenuBarDisplayMode.allProviders.rawValue
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
            menuBarLabel
                .task { store.start() }
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let mode = MenuBarDisplayMode(rawValue: menuBarDisplayModeRaw) ?? .allProviders
        if mode == .iconOnly {
            Image(systemName: "gauge.with.dots.needle.67percent")
        } else {
            Label(
                store.menuBarTitle(for: mode),
                systemImage: "gauge.with.dots.needle.67percent"
            )
        }
    }
}
