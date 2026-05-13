//
//  BS_DiagnosisView.swift
//  Meridian
//
//  Budget Setup — Step 3: Your Reality
//

import SwiftUI
import Charts

struct BS_DiagnosisView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    @State private var selectedTrend: TrendMetric = .spend
    @State private var showTrendInfoSheet = false
    @State private var showHeader = false
    @State private var showTrend = false
    @State private var showCategories = false
    @State private var showInsights = false
    @State private var showCTA = false

    private var trendAccentGradient: LinearGradient {
        LinearGradient(
            colors: AppColors.gradientShellAccent,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var trendAccentColor: Color {
        AppColors.accentBlueBright
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)
                        .opacity(showHeader ? 1 : 0)
                        .offset(y: showHeader ? 0 : 12)

                    trendCard
                        .padding(.horizontal, AppSpacing.lg)
                        .opacity(showTrend ? 1 : 0)
                        .offset(y: showTrend ? 0 : 16)

                    spendingStructureCard
                        .padding(.horizontal, AppSpacing.lg)
                        .opacity(showCategories ? 1 : 0)
                        .offset(y: showCategories ? 0 : 18)

                    insightsSection
                        .padding(.horizontal, AppSpacing.lg)
                        .opacity(showInsights ? 1 : 0)
                        .offset(y: showInsights ? 0 : 20)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }

            stickyBottomCTA
                .opacity(showCTA ? 1 : 0)
                .offset(y: showCTA ? 0 : 18)
        }
        .sheet(isPresented: $showTrendInfoSheet) { trendInfoSheet }
        .onAppear(perform: startEntranceAnimation)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your Cash Flow Snapshot")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            Text(viewModel.isManualMode
                 ? "Here’s the snapshot built from the numbers you entered."
                 : "Here’s your income and spending over the last \(displayedMonthWord) complete \(displayedMonthNoun).")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("\(displayedMonthWord.uppercased())-MONTH TREND")
                    .font(.label)
                    .tracking(1)
                    .foregroundStyle(AppColors.inkFaint)
                Button {
                    showTrendInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            trendMetricTabs

            if trendRows.isEmpty {
                emptyTrendState
            } else {
                Chart {
                    ForEach(trendRows) { row in
                        BarMark(
                            x: .value("Month", row.label),
                            y: .value(selectedTrend.chartTitle, value(for: row, metric: selectedTrend))
                        )
                        .foregroundStyle(trendAccentGradient)
                        .cornerRadius(AppRadius.xs)
                    }

                    RuleMark(y: .value("Typical", typicalTrendValue))
                        .foregroundStyle(AppColors.inkBorder.opacity(0.9))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: trendRows.map(\.label)) { value in
                        AxisValueLabel {
                            if let month = value.as(String.self) {
                                Text(month)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.inkSoft)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        if let plotFrame = proxy.plotFrame,
                           let yPosition = proxy.position(forY: typicalTrendValue) {
                            let frame = geo[plotFrame]
                            Text("Typical \(selectedTrend.segmentTitle.lowercased()) $\(formatted(typicalTrendValue))")
                                .font(.caption)
                                .foregroundStyle(AppColors.inkSoft)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.shellBg1.opacity(0.94))
                                .clipShape(Capsule())
                                .position(
                                    x: max(frame.minX + 88, frame.maxX - 92),
                                    y: max(frame.minY + 14, frame.minY + yPosition - 12)
                                )
                        }
                    }
                }
                .frame(height: chartHeightLarge)
            }
        }
        .padding(AppSpacing.cardPadding)
        .bsGlassCard()
    }

    private let chartHeightLarge: CGFloat = 220
    private let chartHeightCompact: CGFloat = 180

    private var emptyTrendState: some View {
        VStack(spacing: AppSpacing.sm) {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.inkTrack.opacity(0.45))
                .frame(height: chartHeightCompact)
                .overlay(
                    Text("We’ll show your trend as soon as we have complete months to compare.")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                )
        }
    }

    private var spendingStructureCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("WHERE YOUR MONEY GOES")
                    .font(.label)
                    .tracking(1)
                    .foregroundStyle(AppColors.inkFaint)
                Spacer()
                Text("Top categories")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkSoft)
            }

            if topCategories.isEmpty {
                Text("We need a little more categorized spending before this view fills in.")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
            } else {
                VStack(spacing: AppSpacing.md) {
                    ForEach(topCategories) { category in
                        categoryRow(category)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .bsGlassCard()
    }

    private func categoryRow(_ category: CategorySnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(category.tint.opacity(0.12))
                        .frame(width: AppSpacing.lg + AppSpacing.xs, height: AppSpacing.lg + AppSpacing.xs)
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundStyle(category.tint)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(category.name)
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text(category.parentLabel)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                    Text("$\(formatted(category.amount))")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("\(Int((category.share * 100).rounded()))% of spend")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.inkBorder.opacity(0.3))
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(category.tint)
                        .frame(width: max(AppSpacing.sm + AppSpacing.xxs, geo.size.width * max(0, min(1, category.share))))
                }
            }
            .frame(height: AppSpacing.sm)
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("QUICK READS")
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)

            VStack(spacing: AppSpacing.sm) {
                ForEach(insights) { insight in
                    insightCard(insight)
                }
            }
        }
    }

    private func insightCard(_ insight: RealityInsight) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(insight.tint.opacity(0.14))
                    .frame(width: AppSpacing.xl, height: AppSpacing.xl)
                Image(systemName: insight.icon)
                    .font(.footnoteSemibold)
                    .foregroundStyle(insight.tint)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(insight.title)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(insight.body)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.cardPadding)
        .bsGlassCard(cornerRadius: AppRadius.glassBlock)
    }

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

    private func startEntranceAnimation() {
        showHeader = false
        showTrend = false
        showCategories = false
        showInsights = false
        showCTA = false

        withAnimation(.easeOut(duration: 0.28)) {
            showHeader = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.32)) {
                showTrend = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeOut(duration: 0.34)) {
                showCategories = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeOut(duration: 0.34)) {
                showInsights = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.34)) {
                showCTA = true
            }
        }
    }

    private var trendRows: [TrendMonthSnapshot] {
        if let rows = viewModel.spendingStats?.monthlyBreakdownV3, !rows.isEmpty {
            let completeRows = rows.filter { $0.status == "complete" }
            let sourceRows = completeRows.isEmpty ? rows : completeRows
            return sourceRows.map {
                TrendMonthSnapshot(
                    month: $0.month,
                    label: monthAbbreviation(from: $0.month),
                    income: $0.income,
                    spend: $0.totalSpend,
                    save: $0.savings
                )
            }
        }

        let legacyRows = viewModel.spendingStats?.monthlyBreakdown ?? []
        return legacyRows.map {
            TrendMonthSnapshot(
                month: $0.month,
                label: monthAbbreviation(from: $0.month),
                income: $0.income,
                spend: $0.fixed + $0.flexible,
                save: $0.savings
            )
        }
    }

    private var summaryIncome: Double { TrendMetric.income.typicalValue(in: trendRows) }
    private var summarySpend: Double { TrendMetric.spend.typicalValue(in: trendRows) }
    private var summarySave: Double { TrendMetric.save.typicalValue(in: trendRows) }

    private var topCategories: [CategorySnapshot] {
        let items = viewModel.spendingStats?.canonicalBreakdown ?? []
        let positiveItems = items.filter { $0.avgMonthly > 0 }
        let total = max(0.01, positiveItems.reduce(0) { $0 + $1.avgMonthly })

        return positiveItems
            .sorted { $0.avgMonthly > $1.avgMonthly }
            .prefix(6)
            .map { item in
                let category = TransactionCategoryCatalog.category(forStoredSubcategory: item.canonicalId)
                let tint = categoryTint(parent: item.parent, canonicalId: item.canonicalId)
                return CategorySnapshot(
                    canonicalId: item.canonicalId,
                    name: category?.name ?? fallbackCategoryName(for: item.canonicalId),
                    icon: category?.icon ?? "questionmark.circle.fill",
                    amount: item.avgMonthly,
                    share: item.avgMonthly / total,
                    parent: item.parent,
                    tint: tint
                )
            }
    }

    private var insights: [RealityInsight] {
        var built: [RealityInsight] = []

        if let topCategory = topCategories.first {
            built.append(
                RealityInsight(
                    title: "Biggest category",
                    body: "\(topCategory.name) is your biggest average monthly cost at $\(formatted(topCategory.amount)).",
                    icon: topCategory.icon,
                    tint: topCategory.tint
                )
            )
        }

        if let strongestMonth = highestSpendMonth {
            built.append(
                RealityInsight(
                    title: "Highest spend month",
                    body: "\(strongestMonth.label) was your highest spending month at $\(formatted(strongestMonth.spend)).",
                    icon: "calendar",
                    tint: AppColors.planDifficultyAccelerate
                )
            )
        }

        return built
    }

    private var oneTimeTransactionsCount: Int {
        viewModel.spendingStats?.oneTimeTransactions?.count ?? 0
    }

    private var highestSpendMonth: TrendMonthSnapshot? {
        trendRows.max { $0.spend < $1.spend }
    }

    private var displayedMonthCount: Int {
        let count = trendRows.count
        return max(1, count)
    }

    private var displayedMonthWord: String {
        switch displayedMonthCount {
        case 1: return "one"
        case 2: return "two"
        case 3: return "three"
        case 4: return "four"
        case 5: return "five"
        case 6: return "six"
        default: return "\(displayedMonthCount)"
        }
    }

    private var displayedMonthNoun: String {
        displayedMonthCount == 1 ? "month" : "months"
    }

    private var trendInfoSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("How this works")
                        .font(.h3)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("This trend only uses the accounts you selected in Build Plan.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    infoRow(
                        icon: "checklist.checked",
                        title: "Selected accounts",
                        body: viewModel.isManualMode
                            ? "This snapshot uses the manual numbers you entered instead of bank-linked accounts."
                            : "We only include the checking, savings, and credit accounts you selected."
                    )
                    infoRow(
                        icon: "calendar",
                        title: "Complete months only",
                        body: "We look at your last \(displayedMonthWord) complete calendar \(displayedMonthNoun) and skip the current in-progress month."
                    )
                    infoRow(
                        icon: "chart.line.horizontal.3",
                        title: "Typical line",
                        body: "The dashed line shows your typical month using the median, not a simple average."
                    )
                    infoRow(
                        icon: "wand.and.stars",
                        title: "One-time purchases",
                        body: oneTimeTransactionsCount > 0
                            ? "We excluded \(oneTimeTransactionsCount) large one-time purchase\(oneTimeTransactionsCount == 1 ? "" : "s") so this chart reflects your regular cash flow."
                            : "We didn’t find any large one-time purchases to exclude in this window."
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTrendInfoSheet = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    private func infoRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(AppColors.inkTrack.opacity(0.55))
                    .frame(width: AppSpacing.lg + AppSpacing.xs + AppSpacing.xxs, height: AppSpacing.lg + AppSpacing.xs + AppSpacing.xxs)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkPrimary)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(body)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(2)
            }
        }
    }

    private func categoryTint(parent: String, canonicalId: String) -> Color {
        if canonicalId == "uncategorized" { return AppColors.inkSoft }
        return parent == "needs" ? AppColors.budgetNeedsBlue : AppColors.budgetWantsPurple
    }

    private func fallbackCategoryName(for canonicalId: String) -> String {
        if canonicalId == "uncategorized" {
            return "Uncategorized"
        }
        return CategoryDisplay.displayName(canonicalId)
    }

    private func value(for row: TrendMonthSnapshot, metric: TrendMetric) -> Double {
        switch metric {
        case .income: return row.income
        case .spend: return row.spend
        case .save: return row.save
        }
    }

    private var typicalTrendValue: Double {
        selectedTrend.typicalValue(in: trendRows)
    }

    private var trendMetricTabs: some View {
        HStack(spacing: AppSpacing.xs) {
            metricTab(title: "INCOME", value: summaryIncome, metric: .income)
            metricTab(title: "SPEND", value: summarySpend, metric: .spend)
            metricTab(title: "SAVE", value: summarySave, metric: .save)
        }
    }

    private func metricTab(title: String, value: Double, metric: TrendMetric) -> some View {
        Button {
            selectedTrend = metric
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.miniLabel)
                    .tracking(0.8)
                    .foregroundStyle(selectedTrend == metric ? AppColors.inkPrimary : AppColors.inkFaint)

                Text("\(value < 0 ? "-" : "")$\(formatted(abs(value)))")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(selectedTrend == metric ? AnyShapeStyle(trendAccentGradient) : AnyShapeStyle(AppColors.inkPrimary))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(selectedTrend == metric ? AppColors.shellBg2.opacity(0.92) : AppColors.shellBg1.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(selectedTrend == metric ? trendAccentColor.opacity(0.28) : AppColors.inkBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

private enum TrendMetric: String, CaseIterable, Identifiable {
    case income
    case spend
    case save

    var id: String { rawValue }

    var segmentTitle: String {
        switch self {
        case .income: return "Income"
        case .spend: return "Spend"
        case .save: return "Save"
        }
    }

    var chartTitle: String {
        switch self {
        case .income: return "Income"
        case .spend: return "Spending"
        case .save: return "Savings"
        }
    }

    func typicalValue(in rows: [TrendMonthSnapshot]) -> Double {
        let values = rows.map { row in
            switch self {
            case .income: return row.income
            case .spend: return row.spend
            case .save: return row.save
            }
        }
        return median(values)
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}

private struct TrendMonthSnapshot: Identifiable {
    let month: String
    let label: String
    let income: Double
    let spend: Double
    let save: Double

    var id: String { month }
}

private struct CategorySnapshot: Identifiable {
    let canonicalId: String
    let name: String
    let icon: String
    let amount: Double
    let share: Double
    let parent: String
    let tint: Color

    var id: String { canonicalId }

    var parentLabel: String {
        switch parent {
        case "needs": return "Core spending"
        case "wants": return "Lifestyle spending"
        default: return "Other spending"
        }
    }
}

private struct RealityInsight: Identifiable {
    let title: String
    let body: String
    let icon: String
    let tint: Color

    var id: String { title }
}
