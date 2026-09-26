import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var store: UsageStore

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
        HStack {
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
        .font(.caption)
        .padding(12)
    }
}

