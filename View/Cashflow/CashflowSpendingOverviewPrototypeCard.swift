//
//  CashflowSpendingOverviewPrototypeCard.swift
//  Meridian
//
//  Unconnected Cash tab: Spending overview 单卡，对齐
//  design-reference/home-rebuild-glass-prototype.html `.cash-flow-card`（Spending overview）。
//

import SwiftUI

/// 未连接银行时的支出预览卡；连接后请使用 `CashflowView` 内真实 `BudgetCard` 等。
struct CashflowSpendingOverviewPrototypeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Spending overview")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("$3,420")
                        .font(.currencyHero)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("Monthly spending split into needs and wants.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("Spending")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.textInverse)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: AppSpacing.md) {
                budgetBlock(
                    title: "Needs",
                    total: "$2,120",
                    rows: [
                        ("Rent", "$1,480"),
                        ("Groceries", "$410"),
                        ("Utilities", "$230")
                    ],
                    accent: AppColors.accentBlue
                )

                budgetBlock(
                    title: "Wants",
                    total: "$1,300",
                    rows: [
                        ("Dining", "$420"),
                        ("Shopping", "$515"),
                        ("Travel", "$365")
                    ],
                    accent: AppColors.budgetWantsPurple
                )
            }
        }
    }

    private func budgetBlock(
        title: String,
        total: String,
        rows: [(String, String)],
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(title)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer(minLength: 0)
                Text(total)
                    .font(.inlineFigureBold)
                    .foregroundStyle(AppColors.inkPrimary)
            }

            Capsule()
                .fill(accent.opacity(0.35))
                .frame(height: 3)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.0)
                            .font(.bodySmall)
                            .foregroundStyle(AppColors.inkSoft)
                        Spacer(minLength: 0)
                        Text(row.1)
                            .font(.bodySmallSemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }
}

#Preview {
    CashflowSpendingOverviewPrototypeCard()
        .padding()
        .background(AppColors.backgroundPrimary)
}
