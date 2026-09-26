import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginController
    @EnvironmentObject private var usageNotifications: UsageNotificationController
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayModeRaw = MenuBarDisplayMode.allProviders.rawValue

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(spacing: 10) {
                ForEach(UsageProviderID.allCases) { provider in
                    ProviderCardView(
                        provider: provider,
                        snapshot: store.snapshots[provider],
                        error: store.errors[provider]
                    )
                }
            }
            .padding(12)

            Divider()

            footer
        }
        .frame(width: 340)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TokenBar")
                    .font(.headline)
                Text("Claude와 Codex 사용량")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack {
                Text("메뉴 막대")
                Spacer()
                Picker("메뉴 막대", selection: $menuBarDisplayModeRaw) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 145)
            }

            Toggle(
                "로그인 시 실행",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)

            Toggle(
                "잔여량 알림 (20·10·5%)",
                isOn: Binding(
                    get: { usageNotifications.isEnabled },
                    set: { enabled in
                        Task { await usageNotifications.setEnabled(enabled) }
                    }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.small)

            if let message = launchAtLogin.errorMessage
                ?? usageNotifications.errorMessage
                ?? store.setupMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            HStack {
                Button {
                    Task { await store.installClaudeBridge() }
                } label: {
                    if store.isInstallingClaudeBridge {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Label("Claude 연결", systemImage: "link")
                    }
                }
                .buttonStyle(.plain)
                .disabled(store.isInstallingClaudeBridge)

                Divider()
                    .frame(height: 12)

                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(store.isRefreshing)

                Spacer()

                Button("종료") {
                    store.quit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(12)
    }
}
