import SwiftUI

struct ProviderCardView: View {
    let provider: UsageProviderID
    let snapshot: UsageSnapshot?
    let advice: ProviderUsageAdvice?
    let nextBillingDate: Date?
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: provider.systemImage)
                    .frame(width: 18)
                Text(provider.displayName)
                    .font(.headline)
                Spacer()
                connectionBadge
            }

            if let snapshot {
                if let window = snapshot.shortWindow {
                    UsageProgressRow(title: "5시간", window: window)
                }
                if let window = snapshot.weeklyWindow {
                    UsageProgressRow(title: "주간", window: window)
                }
                if let advice {
                    paceDetails(advice)
                }
                details(snapshot)
                if let nextBillingDate {
                    billingDetails(nextBillingDate)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                sourceDetails(snapshot)
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

    private func billingDetails(_ date: Date) -> some View {
        let days = BillingSchedule.daysRemaining(until: date, from: .now)
        return HStack(spacing: 5) {
            Image(systemName: "creditcard")
            Text("다음 결제")
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .monospacedDigit()
            Spacer()
            Text(days == 0 ? "오늘" : "D-\(days)")
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .font(.caption2)
        .foregroundStyle(days <= 3 ? Color.orange : Color.secondary)
    }

    private func paceDetails(_ advice: ProviderUsageAdvice) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Label(paceTitle(advice.pace), systemImage: paceIcon(advice.pace))
                    .foregroundStyle(paceColor(advice.pace))
                Spacer()
                if let safeRate = advice.safeRatePerHour {
                    Text("권장 ≤ \(rateText(safeRate))%/시간")
                        .foregroundStyle(.secondary)
                }
            }

            if let recentRate = advice.recentRatePerHour {
                HStack {
                    Text("최근 \(rateText(recentRate))%/시간")
                    Spacer()
                    forecastText(advice)
                }
                .foregroundStyle(.secondary)
            } else {
                Text("5분 이상 사용하면 소진 시각을 예측합니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2.monospacedDigit())
        .padding(8)
        .background(paceColor(advice.pace).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func forecastText(_ advice: ProviderUsageAdvice) -> some View {
        if let depletionDate = advice.depletionDate,
           advice.resetDate.map({ depletionDate < $0 }) ?? true {
            Text("소진 예상 \(depletionDate.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(advice.pace == .fast ? .orange : .secondary)
        } else {
            Text("리셋까지 유지 가능")
                .foregroundStyle(.green)
        }
    }

    private func rateText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value >= 10 ? 0 : 1)))
    }

    private func paceTitle(_ pace: UsagePace) -> String {
        switch pace {
        case .learning: "속도 분석 중"
        case .stable: "안전한 속도"
        case .fast: "빠른 사용"
        }
    }

    private func paceIcon(_ pace: UsagePace) -> String {
        switch pace {
        case .learning: "hourglass"
        case .stable: "checkmark.circle.fill"
        case .fast: "speedometer"
        }
    }

    private func paceColor(_ pace: UsagePace) -> Color {
        switch pace {
        case .learning: .secondary
        case .stable: .green
        case .fast: .orange
        }
    }

    private var connectionBadge: some View {
        let status: (title: String, color: Color) = {
            if error != nil {
                return (snapshot == nil ? "연결 필요" : "갱신 실패", .red)
            }
            guard let snapshot else { return ("대기 중", .secondary) }
            return snapshot.isStale() ? ("데이터 지연", .orange) : ("연결됨", .green)
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.title)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(status.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.1), in: Capsule())
    }

    private func sourceDetails(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "externaldrive.badge.checkmark")
            Text(snapshot.sourceDescription)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))
                .monospacedDigit()
            Text("수집")
        }
        .font(.caption2)
        .foregroundStyle(snapshot.isStale() ? .orange : .secondary)
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
            if let reset = window.resetsAt {
                HStack {
                    Label(
                        reset.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar.badge.clock"
                    )
                    Spacer()
                    Text("초기화 후 100%")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
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
