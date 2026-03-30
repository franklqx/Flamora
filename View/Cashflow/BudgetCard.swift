//
//  BudgetCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending
    var isConnected: Bool = true
    var hasBudget: Bool = true
    var onSetupBudget: (() -> Void)? = nil
    let onCardTapped: (() -> Void)?
    let onNeedsTapped: (() -> Void)?
    let onWantsTapped: (() -> Void)?
    private let apiBudget = MockData.apiMonthlyBudget

    private var needsColor: Color { AppColors.chartBlue }
    private var wantsColor: Color { AppColors.chartAmber }

    init(
        spending: Spending,
        isConnected: Bool = true,
        hasBudget: Bool = true,
        onSetupBudget: (() -> Void)? = nil,
        onCardTapped: (() -> Void)? = nil,
        onNeedsTapped: (() -> Void)? = nil,
        onWantsTapped: (() -> Void)? = nil
    ) {
        self.spending = spending
        self.isConnected = isConnected
        self.hasBudget = hasBudget
        self.onSetupBudget = onSetupBudget
        self.onCardTapped = onCardTapped
        self.onNeedsTapped = onNeedsTapped
        self.onWantsTapped = onWantsTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TOTAL SPEND")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
                HStack(spacing: AppSpacing.xs) {
                    Text(currentMonthLabel)
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    if isConnected && hasBudget {
                        Image(systemName: "chevron.right")
                            .font(.miniLabel)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
            .contentShape(Rectangle())
            .onTapGesture {
                if isConnected && hasBudget { onCardTapped?() }
            }

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if !isConnected {
                lockedEmptyState
            } else if hasBudget {
                VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
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

                VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
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
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.cardPadding)
            } else {
                setupEmptyState
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var lockedEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("$—")
                    .font(.cardFigurePrimary)
                    .foregroundStyle(AppColors.textTertiary)
                Text("/ $—")
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textTertiary)
            }
            Text("Connect accounts to set up a budget")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textTertiary)
            Capsule()
                .fill(AppColors.progressTrack)
                .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
    }

    private var setupEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Build Your Plan")
                    .font(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Let AI analyze your spending and create a personalized budget.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { onSetupBudget?() }) {
                Text("Start Setup")
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: AppColors.gradientFlamePill,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
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
                Capsule().fill(AppColors.progressTrack).frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
                HStack(spacing: 0) {
                    Rectangle().fill(needsColor).frame(width: nWidth)
                    Rectangle().fill(wantsColor).frame(width: wWidth)
                }
                .clipShape(Capsule())
                .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
            }
        }
        .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
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
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                Text(title)
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
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
        AppColors.backgroundPrimary.ignoresSafeArea()
        BudgetCard(spending: MockData.cashflowData.spending).padding()
    }
}
