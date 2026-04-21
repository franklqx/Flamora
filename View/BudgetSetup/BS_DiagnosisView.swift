//
//  BS_DiagnosisView.swift
//  Flamora app
//
//  Budget Setup — Step 3: Your Reality
//

import SwiftUI

struct BS_DiagnosisView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    metricsRow
                        .padding(.horizontal, AppSpacing.lg)

                    trendCard
                        .padding(.horizontal, AppSpacing.lg)

                    if let note = oneTimeNote {
                        infoCard(title: "Typical month", body: note)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    if let note = completenessNote {
                        infoCard(title: "Data quality", body: note)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    spendMixCard
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }

            stickyBottomCTA
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your Reality")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            if let stats = viewModel.spendingStats {
                if stats.hasDeficit == true, let deficit = stats.deficitAmount {
                    Text("You're spending about $\(formatted(deficit)) more than you earn in a typical month.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.error)
                        .lineSpacing(3)
                } else {
                    Text("This is what a typical month looks like based on the data we have right now.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineSpacing(3)
                }
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            metricCard(title: "INCOME", value: viewModel.currentSnapshotIncome, tint: AppColors.budgetTeal)
            metricCard(title: "SPEND", value: viewModel.currentSnapshotSpend, tint: AppColors.budgetOrange)
            metricCard(title: "SAVE", value: savingsValue, tint: savingsValue >= 0 ? AppColors.accentAmber : AppColors.error)
        }
    }

    private func metricCard(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.miniLabel)
                .tracking(0.8)
                .foregroundStyle(AppColors.inkFaint)
            Text("\(value < 0 ? "-" : "")$\(formatted(abs(value)))")
                .font(.sheetPrimaryButton)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm + AppSpacing.xs)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    /// Three stacked mini sparklines — Income / Spend / Save — each tinted
    /// to match its metric card above. Replaces the old segmented-picker
    /// bar chart per spec ("Step 3 Reality: 3 metric blocks + sparkline").
    /// Per-row layout keeps trends comparable at a glance without forcing
    /// the user to flip between segments.
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("RECENT TREND")
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)

            if rawBreakdownRows.isEmpty {
                Text("No chart data yet")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                    sparklineRow(
                        label: "Income",
                        values: incomeSeries,
                        tint: AppColors.budgetTeal
                    )
                    sparklineRow(
                        label: "Spend",
                        values: spendSeries,
                        tint: AppColors.budgetOrange
                    )
                    sparklineRow(
                        label: "Save",
                        values: saveSeries,
                        tint: savingsTint
                    )
                }

                // Shared month axis aligned to the sparkline plot area (the
                // label column takes up `sparklineLabelWidth`, so indent
                // ticks by that amount to line them up under the lines).
                HStack(spacing: 0) {
                    Spacer().frame(width: Self.sparklineLabelWidth)
                    HStack {
                        ForEach(Array(chartLabels.enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(.cardRowMeta)
                                .foregroundStyle(AppColors.inkSoft)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    // MARK: - Sparkline primitive

    private static let sparklineLabelWidth: CGFloat = 64
    private static let sparklineHeight: CGFloat = 32

    /// One trend row: label on the left, mini line-sparkline filling the
    /// rest of the width. Line uses `tint`; a faint baseline is drawn for
    /// zero reference when the series spans positive + negative values
    /// (e.g. negative savings months).
    private func sparklineRow(label: String, values: [Double], tint: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(label)
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: Self.sparklineLabelWidth, alignment: .leading)

            SparklineShape(values: values)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(height: Self.sparklineHeight)
                .background(
                    SparklineBaseline(values: values)
                        .stroke(
                            AppColors.inkBorder.opacity(0.5),
                            style: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                        )
                )
                .overlay(alignment: .trailing) {
                    // Endpoint dot, painted over the line tail so it stays
                    // visible against the baseline.
                    if let last = values.last, values.count >= 2 {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)
                            .offset(x: 0, y: sparklineEndpointY(for: last, in: values))
                    }
                }
        }
    }

    /// Y-offset (from vertical center of the 32pt row) for the endpoint
    /// dot — keeps it on the line tail rather than the row midline.
    private func sparklineEndpointY(for last: Double, in values: [Double]) -> CGFloat {
        guard let minV = values.min(), let maxV = values.max(), maxV > minV else { return 0 }
        let h = Self.sparklineHeight
        let yNorm = (last - minV) / (maxV - minV)
        return h / 2 - CGFloat(yNorm) * h
    }

    /// Savings can go negative (deficit months). Tint the whole row red
    /// when the latest month is in deficit; otherwise use the amber
    /// accent matching the metric card above.
    private var savingsTint: Color {
        let last = saveSeries.last ?? 0
        return last < 0 ? AppColors.error : AppColors.accentAmber
    }

    private var spendMixCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("WHERE YOUR MONEY GOES NOW")
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)

            let needs = viewModel.currentSnapshotEssentialFloor
            let wants = max(0, viewModel.currentSnapshotSpend - needs)
            let total = max(0.01, viewModel.currentSnapshotSpend)

            mixRow(label: "Needs", amount: needs, ratio: needs / total, tint: AppColors.budgetTeal)
            mixRow(label: "Wants", amount: wants, ratio: wants / total, tint: AppColors.accentAmber)
            mixRow(label: "Savings", amount: max(0, savingsValue), ratio: max(0, savingsValue) / max(0.01, viewModel.currentSnapshotIncome), tint: AppColors.budgetOrange)
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private func mixRow(label: String, amount: Double, ratio: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(label)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
                Text("$\(formatted(amount))")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("· \(Int((ratio * 100).rounded()))%")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.inkBorder.opacity(0.35))
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(tint)
                        .frame(width: max(8, geo.size.width * min(1, max(0, ratio))))
                }
            }
            .frame(height: 8)
        }
    }

    private func infoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)
            Text(body)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                viewModel.seedDefaultsForTargetStep()
                viewModel.goToStep(.target)
            } label: {
                Text("Continue")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(AppColors.ctaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.inkPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    private var savingsValue: Double {
        viewModel.currentSnapshotIncome - viewModel.currentSnapshotSpend
    }

    private var rawBreakdownRows: [MonthlyBreakdownItem] {
        viewModel.spendingStats?.monthlyBreakdown ?? []
    }

    private var incomeSeries: [Double] { rawBreakdownRows.map(\.income) }
    private var spendSeries: [Double] { rawBreakdownRows.map { $0.fixed + $0.flexible } }
    private var saveSeries: [Double] { rawBreakdownRows.map(\.savings) }

    private var chartLabels: [String] {
        rawBreakdownRows.map { monthAbbreviation(from: $0.month) }
    }

    private var oneTimeNote: String? {
        guard let count = viewModel.spendingStats?.oneTimeTransactions?.count, count > 0 else { return nil }
        return count == 1
            ? "We excluded 1 one-time purchase so your typical monthly spend stays realistic."
            : "We excluded \(count) one-time purchases so your typical monthly spend stays realistic."
    }

    private var completenessNote: String? {
        guard let stats = viewModel.spendingStats else { return nil }
        let incompleteCount = stats.monthlyBreakdownV3?.filter { $0.status == "incomplete" }.count ?? 0
        guard incompleteCount > 0 else { return nil }
        return "\(incompleteCount) month(s) in this window have partial data, so we only used complete months for your averages."
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }

    private func monthAbbreviation(from monthString: String) -> String {
        let parts = monthString.split(separator: "-")
        guard parts.count >= 2, let monthNum = Int(parts[1]) else { return monthString }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard monthNum >= 1, monthNum <= 12 else { return monthString }
        return months[monthNum - 1]
    }
}

#Preview {
    BS_DiagnosisView(viewModel: BudgetSetupViewModel())
}

// MARK: - Sparkline shapes
//
// Minimal line-sparkline built on SwiftUI `Shape`. Normalizes `values`
// against the series' own min/max so short amplitudes (e.g. narrow-band
// income) still read as a visible line instead of a flat stripe. For
// series that straddle zero (e.g. savings deficit months), the baseline
// helper exposes a reference y=0 rule so the user can see when a month
// went underwater.

private struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2 else {
            if values.count == 1 {
                // Degenerate single-point series — draw a flat midline so
                // the row still communicates "we have data, just no
                // variation yet".
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
            return path
        }

        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let range = maxV - minV
        let step = rect.width / CGFloat(values.count - 1)

        for (index, value) in values.enumerated() {
            let x = rect.minX + step * CGFloat(index)
            let y: CGFloat
            if range > 0 {
                let norm = CGFloat((value - minV) / range)
                y = rect.maxY - norm * rect.height
            } else {
                y = rect.midY
            }
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

private struct SparklineBaseline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let minV = values.min(), let maxV = values.max(), minV < 0, maxV > 0 else {
            return path
        }
        // Series crosses zero — draw a dashed zero-reference baseline so
        // the eye can anchor on the positive/negative split.
        let range = maxV - minV
        let zeroNorm = CGFloat((0 - minV) / range)
        let y = rect.maxY - zeroNorm * rect.height
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.maxX, y: y))
        return path
    }
}
