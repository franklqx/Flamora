//
//  IncomeCard.swift
//  Flamora app
//

import SwiftUI

struct IncomeCard: View {
    let income: Income
    let monthDates: [Date]
    let selectedMonthIndex: Int
    var onMonthSelected: ((Int) -> Void)? = nil
    var onCardTapped: (() -> Void)? = nil
    var onActiveTapped: (() -> Void)? = nil
    var onPassiveTapped: (() -> Void)? = nil

    // Relative bar heights per month (last 5 visible months)
    // These are proportion values 0.0–1.0 representing historical income levels
    private let monthBarRatios: [Double] = [0.68, 0.55, 0.62, 0.80, 0.95, 1.0, 0.88, 0.92, 0.78, 0.85, 0.90, 1.0]

    private var visibleMonthIndices: [Int] {
        let total = monthDates.count
        guard total > 0 else { return [] }
        let end = min(selectedMonthIndex + 1, total)
        let start = max(end - 5, 0)
        return Array(start..<end)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("TOTAL INCOME")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
                .tracking(1.0)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.cardPadding)
                .padding(.bottom, 2)
                .contentShape(Rectangle())
                .onTapGesture { onCardTapped?() }

            // Large total amount
            totalAmountView
                .padding(.horizontal, AppSpacing.cardPadding)
                .contentShape(Rectangle())
                .onTapGesture { onCardTapped?() }

            // Monthly bar chart
            monthlyBarChart
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, 16)
                .padding(.bottom, 4)

            // Divider
            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, 12)

            // Breakdown rows
            VStack(spacing: 14) {
                incomeRow(
                    title: "Active Income",
                    amount: income.active,
                    color: AppColors.accentBlue,
                    onTap: onActiveTapped
                )
                incomeRow(
                    title: "Passive Income",
                    amount: income.passive,
                    color: AppColors.accentBlue,
                    onTap: onPassiveTapped
                )
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.cardPadding)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    // MARK: - Sub-views

    private var totalAmountView: some View {
        let parts = formatCurrencyWithCents(income.total)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.dollars)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            Text(parts.cents)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var monthlyBarChart: some View {
        let indices = visibleMonthIndices

        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(indices, id: \.self) { idx in
                let isSelected = idx == selectedMonthIndex
                let ratioIdx = min(idx, monthBarRatios.count - 1)
                let ratio = monthBarRatios[ratioIdx]
                let barH = CGFloat(20 + ratio * 60)
                let monthLabel = Self.barMonthFormatter.string(from: monthDates[idx])

                VStack(spacing: 6) {
                    // Bar
                    ZStack(alignment: .bottom) {
                        // Background capsule
                        Capsule()
                            .fill(AppColors.surfaceInput)
                            .frame(width: 16, height: 80)

                        // Fill capsule
                        Capsule()
                            .fill(
                                isSelected
                                ? LinearGradient(
                                    colors: [AppColors.accentBlueBright, AppColors.accentPurple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                  )
                                : LinearGradient(
                                    colors: [AppColors.accentBlue.opacity(0.5), AppColors.accentBlue.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                  )
                            )
                            .frame(width: 16, height: max(12, barH * 0.85))
                    }

                    // Month label
                    Text(monthLabel)
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onMonthSelected?(idx)
                }
            }
        }
        .frame(height: 100)
    }

    private func incomeRow(title: String, amount: Double, color: Color, onTap: (() -> Void)?) -> some View {
        Button { onTap?() } label: {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(formatCurrencyWithCents(amount).full)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    // MARK: - Formatters

    private static let barMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM''yy"
        return f
    }()

    private func formatCurrencyWithCents(_ value: Double) -> CurrencyParts {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        let formatted = f.string(from: NSNumber(value: value)) ?? "$0.00"
        let pieces = formatted.split(separator: ".")
        let dollars = pieces.first.map(String.init) ?? "$0"
        let cents = pieces.count > 1 ? ".\(pieces[1])" : ".00"
        return CurrencyParts(dollars: dollars, cents: cents, full: formatted)
    }
}

private struct CurrencyParts { let dollars: String; let cents: String; let full: String }

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        let dates: [Date] = {
            let cal = Calendar.current
            let now = Date()
            let base = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            return (-4...0).compactMap { cal.date(byAdding: .month, value: $0, to: base) }
        }()
        IncomeCard(
            income: MockData.cashflowData.income,
            monthDates: dates,
            selectedMonthIndex: dates.count - 1,
            onCardTapped: {},
            onActiveTapped: {},
            onPassiveTapped: {}
        ).padding()
    }
}
