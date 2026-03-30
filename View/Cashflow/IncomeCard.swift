//
//  IncomeCard.swift
//  Flamora app
//
//  Donut-style Total Income card
//  Active Income  →  AppColors.accentGreenDeep  (large arc)
//  Passive Income →  AppColors.accentPurpleMid (small arc)
//
//  NOTE: Uses mock data today. When bank accounts are linked,
//  replace `income` (monthly) and `yearlyIncome` with API responses.
//

import SwiftUI

struct IncomeCard: View {

    /// Current month income (mock → will come from API after bank link)
    let income: Income
    /// Current year-to-date income (mock → will come from API after bank link)
    var yearlyIncome: Income? = nil

    var onCardTapped:    (() -> Void)? = nil
    var onActiveTapped:  (() -> Void)? = nil
    var onPassiveTapped: (() -> Void)? = nil
    /// Called when the period toggle changes — lets parent reload data
    var onPeriodChanged: ((Bool) -> Void)? = nil   // true = year, false = month
    var isConnected: Bool = true

    // MARK: – Internal state

    @State private var period: Period = .month

    private enum Period { case month, year }

    // MARK: – Design tokens

    private let activeColor  = AppColors.accentGreenDeep
    private let passiveColor = AppColors.accentPurpleMid
    private let ringWidth: CGFloat = 14

    // MARK: – Derived values

    /// The Income object currently displayed (switches on toggle)
    private var displayed: Income {
        (period == .year ? yearlyIncome : nil) ?? income
    }

    private var activeFraction: Double {
        displayed.total > 0 ? max(0.01, displayed.active  / displayed.total) : 0.85
    }
    private var passiveFraction: Double {
        displayed.total > 0 ? max(0.01, displayed.passive / displayed.total) : 0.12
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
                    Text("Connect accounts to see income")
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

            // ── Passive label (top-trailing) ──────────────────────────────
            HStack {
                Spacer()
                Button { onPassiveTapped?() } label: {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(formatAmount(displayed.passive))
                            .font(.bodySemibold)
                            .foregroundStyle(.white)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(passiveColor)
                                .frame(width: 6, height: 6)
                            Text("Passive")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 44)
            .padding(.horizontal, AppSpacing.cardPadding)

            // ── Donut ring + tappable center ──────────────────────────────
            ZStack {
                donutRings

                Button { onCardTapped?() } label: {
                    VStack(spacing: 4) {
                        Text("Total Income")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                        Text(formatAmount(displayed.total))
                            .font(.cardFigurePrimary)
                            .foregroundStyle(.white)
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

            // ── Active label (bottom-left) ────────────────────────────────
            HStack {
                Button { onActiveTapped?() } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formatAmount(displayed.active))
                            .font(.bodySemibold)
                            .foregroundStyle(.white)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(activeColor)
                                .frame(width: 6, height: 6)
                            Text("Active")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, AppSpacing.cardPadding)
        }
    }

    // MARK: – Donut rings

    private var donutRings: some View {
        // halfGap applied symmetrically on both sides of every endpoint
        // → both gaps (active↔passive and passive↔active) become exactly 2×halfGap
        let halfGap = 0.015   // 2×halfGap ≈ 10.8° per gap, both gaps equal
        let pf = passiveFraction

        return ZStack {
            // Background track
            Circle()
                .stroke(AppColors.surfaceInput, lineWidth: ringWidth)
                .opacity(0.4)

            // Active arc (large – clockwise after passive segment)
            Circle()
                .trim(
                    from: pf + halfGap,
                    to:   max(pf + halfGap + 0.01, 1.0 - halfGap)
                )
                .stroke(
                    LinearGradient(
                        colors: [activeColor.opacity(0.75), activeColor],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Passive arc (small – at 12 o'clock)
            Circle()
                .trim(
                    from: halfGap,
                    to:   max(halfGap + 0.01, pf - halfGap)
                )
                .stroke(passiveColor,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 200, height: 200)
        .padding(ringWidth * 0.5)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    // Center of the 214×214 view (200 + 2×7 padding)
                    let center = CGPoint(x: 107, y: 107)
                    let dx = Double(value.location.x - center.x)
                    let dy = Double(value.location.y - center.y)
                    let distance = sqrt(dx * dx + dy * dy)
                    // Only respond to taps in the ring band (skip center button area)
                    guard distance > 60 && distance < 115 else { return }
                    // Convert to clockwise angle from 12 o'clock, normalized [0, 1)
                    var deg = atan2(dy, dx) * 180 / .pi
                    deg = (deg + 90 + 360).truncatingRemainder(dividingBy: 360)
                    let normalized = deg / 360.0
                    if normalized < pf {
                        onPassiveTapped?()
                    } else {
                        onActiveTapped?()
                    }
                }
        )
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
            onCardTapped:    {},
            onActiveTapped:  {},
            onPassiveTapped: {}
        )
        .padding(AppSpacing.md)
    }
}
