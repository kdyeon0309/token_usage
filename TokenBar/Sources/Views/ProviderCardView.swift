import SwiftUI

struct ProviderCardView: View {
    let provider: UsageProviderID
    let snapshot: UsageSnapshot?
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: provider.systemImage)
                    .frame(width: 18)
                Text(provider.displayName)
                    .font(.headline)
                Spacer()
                freshness
            }

            if let snapshot {
                if let window = snapshot.shortWindow {
                    UsageProgressRow(title: "5시간", window: window)
                }
                if let window = snapshot.weeklyWindow {
                    UsageProgressRow(title: "주간", window: window)
                }
                details(snapshot)
            } else {
                unavailable
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.separator.opacity(0.5))
        }
    }

    @ViewBuilder
    private var freshness: some View {
        if let snapshot {
            Text(snapshot.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(snapshot.isStale() ? .orange : .secondary)
        }
    }

    private var unavailable: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: error == nil ? "clock.badge.questionmark" : "exclamationmark.triangle")
            Text(error ?? "사용량 데이터를 기다리는 중입니다.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func details(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 16) {
            if let context = snapshot.currentContextPercentage {
                detail(label: "컨텍스트", value: "\(Int(context.rounded()))%")
            }
            if let tokens = snapshot.todayTokens {
                detail(label: "오늘", value: tokens.formatted(.number.notation(.compactName)))
            }
            if let cost = snapshot.estimatedCostUSD {
                detail(label: "세션 비용", value: cost.formatted(.currency(code: "USD")))
            }
            Spacer(minLength: 0)
        }
    }

    private func detail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}

private struct UsageProgressRow: View {
    let title: String
    let window: UsageWindow

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text("\(Int(window.remainingPercentage.rounded()))% 남음")
                    .font(.caption.monospacedDigit().weight(.medium))
                if let reset = window.resetsAt {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(reset, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: window.remainingPercentage, total: 100)
                .tint(tint)
        }
    }

    private var tint: Color {
        switch window.remainingPercentage {
        case ..<10: .red
        case ..<25: .orange
        default: .accentColor
        }
    }
}

