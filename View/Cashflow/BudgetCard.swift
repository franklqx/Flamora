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

    private var needsColor: Color { AppColors.chartBlue }
    private var wantsColor: Color { AppColors.chartAmber }

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
            HStack {
                Text("TOTAL SPEND")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
                HStack(spacing: 3) {
                    Text(currentMonthLabel)
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Image(systemName: "chevron.right")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.textTertiary)
                }
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
                        .font(.cardFigurePrimary)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("/ \(formatCurrency(spending.budgetLimit))")
                        .font(.inlineLabel)
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

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
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
                HStack(spacing: 0) {
                    Rectangle().fill(needsColor).frame(width: nWidth)
                    Rectangle().fill(wantsColor).frame(width: wWidth)
                }
                .clipShape(Capsule())
                .frame(height: 6)
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
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(current)
                    .font(.cardFigureSecondary)
                    .foregroundStyle(AppColors.textPrimary)
                Text("/ \(total)")
                    .font(.caption)
                    .fontWeight(.medium)
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
