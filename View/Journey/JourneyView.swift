//
//  JourneyView.swift
//  Flamora app
//
//  Journey 主页面 - 使用 MockData.journeyData + AppSpacing
//

import SwiftUI

struct JourneyView: View {
    private let data = MockData.journeyData
    var onFireTapped: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    header

                    netWorthCard

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Plan")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.screenPadding)

                        VStack(spacing: AppSpacing.cardGap) {
                            budgetCard
                            passiveIncomeCard
                            savingsRateCard
                            aiInsightsCard
                        }
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.vertical, AppSpacing.md)
            }
        }
    }
}

// MARK: - Subviews
private extension JourneyView {
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back,")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#7C7C7C"))

                Text("Alex Sterling")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            FlameTogglePill(isOn: false, action: {
                onFireTapped?()
            })
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var netWorthCard: some View {
        let netWorth = data.netWorth

        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Total Net Worth")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#7C7C7C"))

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(formatCurrencyInteger(netWorth.total))
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(.white)

                Text(formatCurrencyDecimal(netWorth.total))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))

                Text("+\(formatCurrency(netWorth.growthAmount)) (\(String(format: "%.1f", netWorth.growthPercent))%)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#34C759"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#34C759").opacity(0.15))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color(hex: "#121212"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var budgetCard: some View {
        let budget = data.budget
        let progress = Double(budget.percent) / 100.0

        return VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(budget.period) • \(budget.daysLeft) days left")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B7280"))
                }

                Spacer()

                Text("\(budget.percent)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            ProgressBar(
                progress: progress,
                color: Color(hex: "#FF6B47")
            )

            HStack {
                Text("\(formatCurrency(budget.spent)) spent")
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                Spacer()

                Text("Limit: \(formatCurrency(budget.limit))")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var passiveIncomeCard: some View {
        let income = data.passiveIncome
        let progress = Double(income.percent) / 100.0

        return VStack(spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Passive Income")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("CAPACITY REPORT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#3B82F6"))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("PROJECTED")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#6B7280"))

                        Text(formatCurrency(income.projected))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Circle()
                            .fill(Color(hex: "#3B82F6"))
                            .frame(width: 6, height: 6)
                    }

                    HStack(spacing: 4) {
                        Text("TARGET")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#6B7280"))

                        Text(formatCurrency(income.target))
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#6B7280"))

                        Circle()
                            .fill(Color(hex: "#4B5563"))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            ProgressBar(
                progress: progress,
                color: Color(hex: "#3B82F6")
            )

            Text("Based on 4% safe withdrawal rate")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#6B7280"))
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var savingsRateCard: some View {
        let savings = data.savingsRate
        let currentPercent = Int(savings.current * 100)
        let targetPercent = Int(savings.target * 100)

        return VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings Rate")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Target: \(targetPercent)% of income")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B7280"))
                }

                Spacer()

                Text("\(currentPercent)%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: AppSpacing.lg) {
                ForEach(savings.months, id: \.month) { monthStatus in
                    MonthIndicator(
                        month: monthStatus.month,
                        status: statusFromString(monthStatus.status)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    var aiInsightsCard: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: 48, height: 48)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA"), Color(hex: "#EC4899")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Insights")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text("Evaluate your spending patterns")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#9CA3AF"))
        }
        .padding(AppSpacing.cardPadding)
        .background(Color(hex: "#121212"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#1D4ED8"),
                            Color(hex: "#7C3AED"),
                            Color(hex: "#DB2777")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Helpers
private extension JourneyView {
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    func formatCurrencyInteger(_ value: Double) -> String {
        let integerPart = Int(value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(integerPart))) ?? "$0"
    }

    func formatCurrencyDecimal(_ value: Double) -> String {
        let decimalPart = value.truncatingRemainder(dividingBy: 1)
        let cents = Int(decimalPart * 100)
        return String(format: ".%02d", cents)
    }

    func statusFromString(_ statusString: String) -> MonthIndicator.Status {
        switch statusString.lowercased() {
        case "success":
            return .success
        case "failed":
            return .failed
        default:
            return .pending
        }
    }
}

#Preview {
    JourneyView(onFireTapped: {})
}
