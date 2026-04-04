//
//  IncomeCard.swift
//  Flamora app
//
//  Donut-style Total Income card
//  单来源或 YTD 无明细：整环绿色渐变；多来源：按金额比例分段，`AppColors.incomeSegmentPalette` 同色索引与 Total Income 一致。
//
//  Monthly / YTD values come from `CashflowView` → `get-spending-summary` (total_income).
//

import SwiftUI

struct IncomeCard: View {

    /// Current month income (from spending summary `total_income`).
    let income: Income
    /// YTD income (sum of monthly summaries); nil falls back to `income` in UI.
    var yearlyIncome: Income? = nil

    var onCardTapped: (() -> Void)? = nil
    /// Called when the period toggle changes — lets parent reload data
    var onPeriodChanged: ((Bool) -> Void)? = nil   // true = year, false = month
    var isConnected: Bool = true
    var placeholderMessage: String = "Connect accounts to see income"

    // MARK: – Internal state

    @State private var period: Period = .month

    private enum Period { case month, year }

    // MARK: – Design tokens

    private let ringWidth: CGFloat = 14

    // MARK: – Derived values

    /// The Income object currently displayed (switches on toggle)
    private var displayed: Income {
        (period == .year ? yearlyIncome : nil) ?? income
    }

    /// 多段圆环：YTD 无 `sources` 时用整环单色（与计划一致）。
    private var shouldShowMultiSegmentDonut: Bool {
        displayed.sources.count >= 2 && displayed.total > 0
    }

    // Label shown inside the donut center
    private var centerSubLabel: String {
        period == .year ? "YTD \(currentYear)" : shortMonthLabel
    }

    // Label shown below the period toggle
    private var periodRangeLabel: String {
        period == .year ? yearRangeLabel : fullMonthLabel
    }

    private var shortMonthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return f.string(from: Date())
    }
    private var fullMonthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }
    private var yearRangeLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "Jan 1 – \(f.string(from: Date())), \(currentYear)"
    }
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    // MARK: – Body

    var body: some View {
        VStack(spacing: 0) {
            if isConnected {
                donutSection
                    .padding(.top, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.xs)

                divider

                VStack(spacing: AppSpacing.xs) {
                    periodToggle
                    periodLabel
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.cardPadding)
            } else {
                disconnectedIncomePlaceholder
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var disconnectedIncomePlaceholder: some View {
        VStack(spacing: 0) {
            HStack { Spacer() }
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.cardPadding)

            ZStack {
                Circle()
                    .stroke(AppColors.progressTrack, lineWidth: ringWidth)
                    .opacity(0.35)
                    .frame(width: 200, height: 200)
                VStack(spacing: AppSpacing.xs) {
                    Text("Total Income")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.textTertiary)
                    Text("$—")
                        .font(.cardFigurePrimary)
                        .foregroundStyle(AppColors.textTertiary)
                    Text(placeholderMessage)
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 200, height: 200)

            HStack { Spacer() }
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.cardPadding)

            divider

            VStack(spacing: AppSpacing.xs) {
                periodToggle
                    .opacity(0.35)
                    .allowsHitTesting(false)
                periodLabel
                    .opacity(0.35)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.cardPadding)
        }
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: – Donut section

    private var donutSection: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.cardPadding)

            // ── Donut ring + tappable center（分类明细在 Total Income 全屏页）──
            ZStack {
                donutRings

                Button { onCardTapped?() } label: {
                    VStack(spacing: 4) {
                        Text("Total Income")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                        Text(formatAmount(displayed.total))
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(centerSubLabel)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 200, height: 200)

            Text("Tap chart for breakdown")
                .font(.footnoteRegular)
                .foregroundColor(AppColors.textTertiary)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.cardPadding)
        }
    }

    // MARK: – Donut rings

    private var donutRings: some View {
        let betweenGap: CGFloat = 0.012
        let palette = AppColors.incomeSegmentPalette

        return ZStack {
            Circle()
                .stroke(AppColors.surfaceInput, lineWidth: ringWidth)
                .opacity(0.4)

            if shouldShowMultiSegmentDonut {
                let segments = incomeDonutSegments(
                    sources: displayed.sources,
                    total: displayed.total,
                    outerGap: 0,
                    betweenGap: betweenGap,
                    palette: palette
                )
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    Circle()
                        .trim(from: seg.start, to: seg.end)
                        .stroke(
                            seg.color,
                            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            } else {
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppColors.accentGreenDeep.opacity(0.75),
                                AppColors.accentGreenDeep,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 200, height: 200)
        .padding(ringWidth * 0.5)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    onCardTapped?()
                }
        )
    }

    private struct IncomeDonutSegment {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private func incomeDonutSegments(
        sources: [IncomeSource],
        total: Double,
        outerGap: CGFloat,
        betweenGap: CGFloat,
        palette: [Color]
    ) -> [IncomeDonutSegment] {
        let n = sources.count
        guard n >= 2, total > 0 else { return [] }
        let gapCount = CGFloat(n - 1)
        let usable = max(0.1, 1.0 - 2 * outerGap - gapCount * betweenGap)
        var cursor = outerGap
        var out: [IncomeDonutSegment] = []
        for (i, src) in sources.enumerated() {
            let frac = max(0, src.amount / total)
            let span = max(0.01, CGFloat(frac) * usable)
            let end = min(cursor + span, 1.0 - outerGap)
            out.append(IncomeDonutSegment(
                start: cursor,
                end: end,
                color: palette[i % palette.count]
            ))
            cursor = end + (i < n - 1 ? betweenGap : 0)
        }
        return out
    }

    // MARK: – Divider

    private var divider: some View {
        Rectangle()
            .fill(AppColors.surfaceBorder)
            .frame(height: 0.5)
            .padding(.horizontal, AppSpacing.cardPadding)
    }

    // MARK: – Period toggle

    private var periodToggle: some View {
        HStack(spacing: 2) {
            togglePill("This Month", selected: period == .month) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    period = .month
                    onPeriodChanged?(false)
                }
            }
            togglePill("This Year", selected: period == .year) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    period = .year
                    onPeriodChanged?(true)
                }
            }
        }
        .padding(3)
        .background(AppColors.surfaceInput)
        .clipShape(Capsule())
    }

    private func togglePill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.inlineLabel)
                .foregroundColor(selected ? AppColors.textInverse : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xs + 2)
                .background(
                    Capsule().fill(selected ? AppColors.textPrimary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: – Period label (below toggle)

    private var periodLabel: some View {
        Text(periodRangeLabel)
            .font(.footnoteRegular)
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: – Formatter

    private func formatAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle           = .currency
        f.currencyCode          = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        IncomeCard(
            income:       MockData.cashflowData.income,
            yearlyIncome: MockData.yearlyIncome,
            onCardTapped: {}
        )
        .padding(AppSpacing.md)
    }
}
