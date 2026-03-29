//
//  SavingsRateCard.swift
//  Flamora app
//

import SwiftUI

struct SavingsRateCard: View {
    let apiBudget: APIMonthlyBudget
    var action: (() -> Void)? = nil

    private var totalBudget: Double {
        apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
    }
    private var actualRate: Double {
        totalBudget > 0 ? (apiBudget.savingsActual ?? 0) / totalBudget : 0
    }
    private var actualPct: Int { Int((actualRate * 100).rounded()) }
    private var savedAmount: Double { apiBudget.savingsActual ?? 0 }
    private var targetAmount: Double { apiBudget.savingsBudget }

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SAVINGS RATE")
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
                HStack(alignment: .bottom, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(actualPct)%")
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Saved \(formatCurrency(savedAmount)) this month")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GeometryReader { geo in
                        miniChart(height: geo.size.height)
                    }
                    .frame(width: 110)
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

    // MARK: - Mini Chart

    private func miniChart(height: CGFloat) -> some View {
        let entries = last6MonthsSavings()
        // Scale so the tallest bar among the six uses full `height` (not targetAmount / first column).
        let dataMax = entries.compactMap { $0.0 }.max() ?? 0
        let scaleMax = max(dataMax, 1)

        return HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            ForEach(0..<6, id: \.self) { i in
                let (amount, metTarget) = entries[i]
                let barHeight: CGFloat = amount == nil
                    ? 4
                    : max(4, height * CGFloat((amount ?? 0) / scaleMax))

                RoundedRectangle(cornerRadius: 3)
                    .fill(barFill(amount: amount, metTarget: metTarget))
                    .frame(width: 6, height: barHeight)
            }
        }
        .frame(width: 110, height: height, alignment: .trailing)
    }

    // MARK: - Helpers

    private func last6MonthsSavings() -> [(Double?, Bool)] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now) - 1

        return (0..<6).map { offset in
            var month = currentMonth - (5 - offset)
            var year = currentYear
            if month < 0 { month += 12; year -= 1 }
            let amount = MockData.savingsByYear[year]?[month]
            return (amount, (amount ?? 0) >= targetAmount)
        }
    }

    private func barFill(amount: Double?, metTarget: Bool) -> AnyShapeStyle {
        guard amount != nil else {
            return AnyShapeStyle(AppColors.surfaceBorder)
        }
        if metTarget {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "#A78BFA"), Color(hex: "#F9A8D4"), Color(hex: "#FCD34D")],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        return AnyShapeStyle(AppColors.surfaceElevated)
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
        Color.black.ignoresSafeArea()
        SavingsRateCard(apiBudget: MockData.apiMonthlyBudget)
    }
}
