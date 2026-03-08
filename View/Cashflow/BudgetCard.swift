//
//  BudgetCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending
    let onCardTapped: (() -> Void)?
    let onNeedsTapped: (() -> Void)?
    let onWantsTapped: (() -> Void)?
    private let apiBudget = MockData.apiMonthlyBudget

    private var needsColor: Color { AppColors.accentPurple }
    private var wantsColor: Color { AppColors.accentBlue }

    init(
        spending: Spending,
        onCardTapped: (() -> Void)? = nil,
        onNeedsTapped: (() -> Void)? = nil,
        onWantsTapped: (() -> Void)? = nil
    ) {
        self.spending = spending
        self.onCardTapped = onCardTapped
        self.onNeedsTapped = onNeedsTapped
        self.onWantsTapped = onWantsTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("TOTAL SPEND")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(0.8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
            .onTapGesture { onCardTapped?() }

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            // Amount + bar
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatCurrency(spending.total))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("/ \(formatCurrency(spending.budgetLimit))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                }

                segmentedBar
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.md)
            .contentShape(Rectangle())
            .onTapGesture { onCardTapped?() }

            // Breakdown rows
            VStack(spacing: 12) {
                BudgetRowItem(
                    title: "Needs",
                    current: formatCurrency(spending.needs),
                    total: formatCurrency(apiBudget.needsBudget),
                    color: needsColor,
                    onTap: onNeedsTapped
                )
                BudgetRowItem(
                    title: "Wants",
                    current: formatCurrency(spending.wants),
                    total: formatCurrency(apiBudget.wantsBudget),
                    color: wantsColor,
                    onTap: onWantsTapped
                )
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.cardPadding)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var segmentedBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeW = w.isFinite && w >= 0 ? w : 0
            let limit = max(spending.budgetLimit, 1)
            let nRatio = min(max(spending.needs / limit, 0), 1)
            let wRatio = min(max(spending.wants / limit, 0), 1)
            let nWidth = max(0, safeW * CGFloat(nRatio))
            let wWidth = max(0, safeW * CGFloat(wRatio))

            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.progressTrack).frame(height: 6)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentBlueBright, AppColors.accentGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(nWidth + wWidth, 0), height: 6)
            }
        }
        .frame(height: 6)
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

private struct BudgetRowItem: View {
    let title: String
    let current: String
    let total: String
    let color: Color
    let onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap { Button(action: onTap) { rowContent }.buttonStyle(.plain) }
            else { rowContent }
        }
    }

    private var rowContent: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(current)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("/ \(total)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BudgetCard(spending: MockData.cashflowData.spending).padding()
    }
}
