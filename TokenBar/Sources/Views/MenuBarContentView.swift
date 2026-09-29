import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginController
    @EnvironmentObject private var usageNotifications: UsageNotificationController
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayModeRaw = MenuBarDisplayMode.allProviders.rawValue
    @AppStorage("claudeBillingDate") private var claudeBillingDateTimestamp = 0.0
    @AppStorage("codexBillingDate") private var codexBillingDateTimestamp = 0.0
    @State private var isBillingSettingsExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if let recommendation = store.recommendation {
                recommendationBanner(recommendation)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            if let event = store.recentUnexpectedResets.first {
                unexpectedResetBanner(event, count: store.recentUnexpectedResets.count)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            Divider()

            VStack(spacing: 10) {
                ForEach(UsageProviderID.allCases) { provider in
                    ProviderCardView(
                        provider: provider,
                        snapshot: store.snapshots[provider],
                        advice: store.advice[provider],
                        nextBillingDate: nextBillingDate(for: provider),
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

    private func recommendationBanner(_ recommendation: UsageRecommendation) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: recommendation.preferredProvider == nil
                ? "checkmark.circle.fill"
                : "arrow.triangle.swap")
                .foregroundStyle(
                    recommendation.preferredProvider == nil ? Color.green : Color.accentColor
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.preferredProvider == nil ? "사용 균형" : "사용 추천")
                    .font(.caption.weight(.semibold))
                Text(recommendation.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }

    private func unexpectedResetBanner(_ event: UsageResetEvent, count: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("예정 외 초기화 감지")
                        .font(.caption.weight(.semibold))
                    if count > 1 {
                        Text("+\(count - 1)건")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(
                    "\(event.provider.displayName) \(event.window.displayName) 사용 가능량이 "
                        + "\(Int(event.restoredPercentage.rounded()))%p 회복됨"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                Text(event.detectedAt, style: .relative)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
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

            DisclosureGroup("결제 예정일", isExpanded: $isBillingSettingsExpanded) {
                VStack(spacing: 7) {
                    billingDateEditor(
                        provider: .claude,
                        timestamp: $claudeBillingDateTimestamp
                    )
                    billingDateEditor(
                        provider: .codex,
                        timestamp: $codexBillingDateTimestamp
                    )
                    Text("구독 결제일은 서비스 데이터에 없어 직접 설정합니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 5)
            }

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

            Text("한도는 서비스가 제공하는 사용률(%) 기준입니다. 절대 토큰 한도는 제공되지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

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

    @ViewBuilder
    private func billingDateEditor(
        provider: UsageProviderID,
        timestamp: Binding<Double>
    ) -> some View {
        HStack {
            Toggle(
                provider.displayName,
                isOn: Binding(
                    get: { timestamp.wrappedValue > 0 },
                    set: { enabled in
                        let defaultDate = Calendar.current.date(
                            byAdding: .month,
                            value: 1,
                            to: .now
                        ) ?? .now
                        timestamp.wrappedValue = enabled ? defaultDate.timeIntervalSince1970 : 0
                    }
                )
            )
            .toggleStyle(.checkbox)

            Spacer()

            if timestamp.wrappedValue > 0 {
                DatePicker(
                    provider.displayName,
                    selection: Binding(
                        get: { Date(timeIntervalSince1970: timestamp.wrappedValue) },
                        set: { timestamp.wrappedValue = $0.timeIntervalSince1970 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
    }

    private func nextBillingDate(for provider: UsageProviderID) -> Date? {
        let timestamp = provider == .claude
            ? claudeBillingDateTimestamp
            : codexBillingDateTimestamp
        guard timestamp > 0 else { return nil }
        return BillingSchedule.nextBillingDate(
            from: Date(timeIntervalSince1970: timestamp),
            after: .now
        )
    }
}
