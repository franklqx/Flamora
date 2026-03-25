//
//  BudgetPlanCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetPlanCard: View {
    let apiBudget: APIMonthlyBudget
    let daysLeft: Int
    var action: (() -> Void)? = nil

    private var spent: Double {
        (apiBudget.needsSpent ?? 0) + (apiBudget.wantsSpent ?? 0)
    }
    private var limit: Double {
        apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
    }
    private var remaining: Double { limit - spent }
    private var spentPercent: Int {
        limit > 0 ? Int((spent / limit * 100).rounded()) : 0
    }

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("BUDGET")
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

                Rectangle()
                    .fill(AppColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                // Content
                VStack(spacing: AppSpacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formatCurrency(remaining))
                                    .font(.cardFigurePrimary)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("left")
                                    .font(.inlineLabel)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Text("\(formatCurrency(spent)) spent this month")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(daysLeft)")
                                .font(.h3)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("days left")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    HStack(spacing: AppSpacing.xs) {
                        GeometryReader { geo in
                            let w = max(geo.size.width, 1)
                            let safeLimit = max(limit, 1)
                            let nRatio = min(max((apiBudget.needsSpent ?? 0) / safeLimit, 0), 1)
                            let wRatio = min(max((apiBudget.wantsSpent ?? 0) / safeLimit, 0), 1)
                            let nWidth = w * CGFloat(nRatio)
                            let wWidth = w * CGFloat(wRatio)

                            ZStack(alignment: .leading) {
                                Capsule().fill(AppColors.progressTrack).frame(height: 6)
                                HStack(spacing: 0) {
                                    Rectangle().fill(AppColors.accentPurple).frame(width: nWidth)
                                    Rectangle().fill(AppColors.accentBlue).frame(width: wWidth)
                                }
                                .clipShape(Capsule())
                                .frame(height: 6)
                            }
                        }
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)

                        Text("\(spentPercent)%")
                            .font(.inlineFigureBold)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.cardPadding)
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

    // MARK: - Helpers

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
        Color.black.ignoresSafeArea()
        BudgetPlanCard(
            apiBudget: MockData.apiMonthlyBudget,
            daysLeft: MockData.journeyData.budget.daysLeft
        )
    }
}
