//
//  SavingsRateCard.swift
//  Flamora app
//

import SwiftUI

struct SavingsRateCard: View {
    let apiBudget: APIMonthlyBudget
    var isConnected: Bool = true
    var action: (() -> Void)? = nil

    private var targetAmount: Double { apiBudget.savingsBudget }
    private var targetRate: Int { Int(apiBudget.savingsRatio.rounded()) }

    var body: some View {
        Button(action: { if isConnected { action?() } }) {
            VStack(spacing: 0) {
                HStack {
                    Text("SAVINGS")
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Spacer()
                    HStack(spacing: 3) {
                        Text(currentMonthLabel)
                            .font(.cardHeader)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(AppTypography.Tracking.cardHeader)
                        if isConnected {
                            Image(systemName: "chevron.right")
                                .font(.miniLabel)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.cardPadding)
                .padding(.bottom, 12)

                Rectangle()
                    .fill(AppColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                if isConnected {
                    HStack(spacing: AppSpacing.xl) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Savings goal")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textTertiary)
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                                Text(formatCurrency(targetAmount))
                                    .font(.cardFigurePrimary)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("/ month")
                                    .font(.bodyRegular)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Savings rate")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textTertiary)
                            Text("\(targetRate)%")
                                .font(.cardFigurePrimary)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.cardPadding)
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Savings goal")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                        Text("Connect accounts to track savings")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.cardPadding)
                }
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.screenPadding)
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
        SavingsRateCard(apiBudget: .empty)
    }
}
