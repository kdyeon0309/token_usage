import SwiftUI

@main
struct TokenBarApp: App {
    @StateObject private var store = UsageStore(
        providers: [ClaudeUsageProvider()]
    )

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
                .task {
                    store.start()
                }
        } label: {
            Label(store.menuBarTitle, systemImage: "gauge.with.dots.needle.67percent")
        }
        .menuBarExtraStyle(.window)
    }
}
