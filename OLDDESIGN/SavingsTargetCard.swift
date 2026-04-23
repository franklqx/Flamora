//
//  SavingsTargetCard.swift
//  Flamora app
//

import SwiftUI

struct SavingsCheckinMonth: Identifiable {
    let id: String
    let label: String
    let amount: Double?
}

struct SavingsTargetCard: View {
    @Binding var currentAmount: Double
    var targetAmount: Double
    var actualRate: Double?
    var targetRatePercent: Double
    var monthlyCheckins: [SavingsCheckinMonth] = []
    var isConnected: Bool = true
    var hasBudgetSetup: Bool = true
    var onAdd: () -> Void
    var onCardTap: (() -> Void)? = nil

    private enum SavingsStatus: String {
        case onTrack = "On track"
        case atRisk = "At risk"
        case offTrack = "Off track"
    }

    private enum CheckinSymbol {
        case done
        case pending
        case missed

        var text: String {
            switch self {
            case .done: return "✓"
            case .pending: return "+"
            case .missed: return "✕"
            }
        }
    }

    private var status: SavingsStatus {
        guard let actualRate else { return .atRisk }
        let actualPercent = actualRate * 100
        if actualPercent >= (targetRatePercent - 2) { return .onTrack }
        if actualPercent >= (targetRatePercent - 7) { return .atRisk }
        return .offTrack
    }

    private var statusColor: Color {
        switch status {
        case .onTrack: return AppColors.success
        case .atRisk: return AppColors.warning
        case .offTrack: return AppColors.error
        }
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var achievedPercentText: String {
        guard let actualRate else { return "—" }
        return "\(Int((actualRate * 100).rounded()))%"
    }

    private var normalizedCheckins: [SavingsCheckinMonth] {
        if monthlyCheckins.isEmpty {
            return fallbackCheckins
        }
        return monthlyCheckins
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            Group {
                if isConnected && !hasBudgetSetup {
                    placeholderState("Complete budget setup to track savings")
                } else if !isConnected {
                    placeholderState("Connect accounts to track savings")
                } else {
                    contentState
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                if isConnected && hasBudgetSetup {
                    onCardTap?()
                }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text("SAVING RATE")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                Text(currentMonthLabel)
                    .font(.cardHeader)
                    .foregroundColor(AppColors.inkFaint)
                    .tracking(AppTypography.Tracking.cardHeader)
                if isConnected && hasBudgetSetup {
                    Image(systemName: "chevron.right")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.inkFaint)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
    }

    private var contentState: some View {
        VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Savings amount")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.inkSoft)
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        Text(formatCurrency(currentAmount))
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("/ month")
                            .font(.bodyRegular)
                            .foregroundColor(AppColors.inkFaint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Savings rate")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.inkSoft)
                    Text(achievedPercentText)
                        .font(.cardFigurePrimary)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: AppSpacing.sm) {
                statusPill
                Text("Target \(Int(targetRatePercent.rounded()))%")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.inkFaint)
                Spacer()
                Button("Edit amount") { onAdd() }
                    .buttonStyle(.plain)
                    .font(.smallLabel)
                    .foregroundColor(AppColors.budgetNeedsBlue)
            }

            HStack(spacing: AppSpacing.sm) {
                ForEach(normalizedCheckins) { item in
                    checkinBubble(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.xs)
        }
    }

    private func checkinBubble(_ item: SavingsCheckinMonth) -> some View {
        let symbol = checkinSymbol(for: item.amount)

        return VStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle()
                    .fill(circleFill(for: symbol))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(AppColors.inkBorder, lineWidth: 1)
                    )

                Text(symbol.text)
                    .font(.h4)
                    .foregroundColor(symbolColor(for: symbol))
            }

            Text(item.label)
                .font(.caption)
                .foregroundColor(AppColors.inkSoft)

            Text(checkinAmountText(item.amount))
                .font(.miniLabel)
                .foregroundColor(AppColors.inkFaint)
        }
        .frame(width: 62)
    }

    private func checkinSymbol(for amount: Double?) -> CheckinSymbol {
        guard let amount else { return .pending }
        if amount > 0.005 { return .done }
        return .missed
    }

    private func symbolColor(for symbol: CheckinSymbol) -> Color {
        switch symbol {
        case .done: return AppColors.success
        case .pending: return AppColors.inkPrimary
        case .missed: return AppColors.inkFaint
        }
    }

    private func circleFill(for symbol: CheckinSymbol) -> Color {
        switch symbol {
        case .done: return AppColors.success.opacity(0.16)
        case .pending: return AppColors.ctaWhite.opacity(0.86)
        case .missed: return AppColors.inkTrack
        }
    }

    private func checkinAmountText(_ amount: Double?) -> String {
        guard let amount else { return "-" }
        return formatCurrency(amount)
    }

    private var statusPill: some View {
        Text(status.rawValue)
            .font(.segmentLabel(selected: true))
            .foregroundColor(statusColor)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private func placeholderState(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("$—")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkFaint)
            Text(text)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
            HStack(spacing: AppSpacing.sm) {
                ForEach(fallbackCheckins) { item in
                    checkinBubble(item)
                }
            }
            .padding(.top, AppSpacing.xs)
        }
    }

    private var fallbackCheckins: [SavingsCheckinMonth] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        return (0..<4).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset - 3, to: Date()) else { return nil }
            return SavingsCheckinMonth(
                id: "fallback-\(offset)",
                label: formatter.string(from: date).uppercased(),
                amount: offset == 3 ? currentAmount : nil
            )
        }
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        SavingsTargetCard(
            currentAmount: .constant(1000),
            targetAmount: 1200,
            actualRate: 0.18,
            targetRatePercent: 22,
            monthlyCheckins: [
                SavingsCheckinMonth(id: "a", label: "JUL", amount: nil),
                SavingsCheckinMonth(id: "b", label: "AUG", amount: 800),
                SavingsCheckinMonth(id: "c", label: "SEP", amount: 0),
                SavingsCheckinMonth(id: "d", label: "OCT", amount: nil)
            ],
            onAdd: {}
        )
        .padding()
    }
}
