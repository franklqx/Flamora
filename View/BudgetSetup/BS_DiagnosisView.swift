//
//  BS_DiagnosisView.swift
//  Flamora app
//
//  Budget Setup — Step 2: Your Financial Snapshot
//  V2: Shows income/savings/expenses stat cards, interactive bar chart,
//  and AI insights. Needs/Wants breakdown moved to Step 3.
//

import SwiftUI

struct BS_DiagnosisView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    
    enum MetricTab: String, CaseIterable {
        case income, savings, expenses
    }
    
    @State private var selectedTab: MetricTab = .income
    @State private var showMetrics = false
    @State private var showChart = false
    @State private var showInsights = false
    @State private var showGoalGap = false
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundPrimary.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)

                    metricTabCards
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.md)
                        .opacity(showMetrics ? 1 : 0)
                        .offset(y: showMetrics ? 0 : AppSpacing.sm + AppSpacing.xs)
                    
                    barChartSection
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.md)
                        .opacity(showChart ? 1 : 0)
                        .offset(y: showChart ? 0 : AppSpacing.sm + AppSpacing.xs)

                    aiInsightsSection
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.md)
                        .opacity(showInsights ? 1 : 0)
                        .offset(y: showInsights ? 0 : AppSpacing.sm + AppSpacing.xs)

                    goalGapSection
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.md)
                        .opacity(showGoalGap ? 1 : 0)
                        .offset(y: showGoalGap ? 0 : AppSpacing.sm + AppSpacing.xs)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            
            stickyBottomCTA
        }
        .onAppear { triggerAppearAnimations() }
        .animation(.easeOut(duration: 0.3), value: selectedTab)
    }
    
    private func triggerAppearAnimations() {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) { showMetrics = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showChart = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) { showInsights = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.7)) { showGoalGap = true }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Financial Snapshot")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)
            
            if let stats = viewModel.spendingStats {
                Text("Based on \(stats.totalTransactions) transactions over \(stats.monthsAnalyzed) months.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }
        }
    }
    
    // MARK: - Metric Tab Cards

    // Compute AVGs directly from monthlyBreakdown using the same formulas as chartValues(),
    // so the cards and bar chart are always consistent (same data, same time range, same clipping).
    private var metricTabCards: some View {
        let breakdowns = viewModel.spendingStats?.monthlyBreakdown ?? []
        let n = Double(breakdowns.isEmpty ? 1 : breakdowns.count)
        let avgIncome   = breakdowns.map { $0.income }.reduce(0, +) / n
        let avgExpenses = breakdowns.map { $0.fixed + $0.flexible }.reduce(0, +) / n
        let avgSavings  = breakdowns.map { max(0, $0.savings) }.reduce(0, +) / n

        return HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            metricCard(tab: .income,   label: "AVG INCOME",   value: avgIncome)
            metricCard(tab: .expenses, label: "AVG EXPENSES", value: avgExpenses)
            metricCard(tab: .savings,  label: "AVG SAVINGS",  value: avgSavings)
        }
    }
    
    @ViewBuilder
    private func metricCard(tab: MetricTab, label: String, value: Double) -> some View {
        let isSelected = selectedTab == tab
        let isNegative = value < 0
        
        Button { selectedTab = tab } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(label)
                    .font(.miniLabel)
                    .tracking(0.08 * 9)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

                Text("\(isNegative ? "-" : "")$\(formatted(abs(value)))")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(isNegative ? AppColors.error : AppColors.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm + AppSpacing.xs)
            .background(isSelected ? AppColors.overlayWhiteMid : AppColors.overlayWhiteWash)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(
                        isSelected ? AppColors.overlayWhiteAt25 : AppColors.overlayWhiteStroke,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bar Chart
    
    private var barChartSection: some View {
        let breakdowns = viewModel.spendingStats?.monthlyBreakdown ?? []
        let barValues = chartValues(for: selectedTab, breakdowns: breakdowns)
        let average = barValues.isEmpty ? 0 : barValues.reduce(0, +) / Double(barValues.count)
        let maxVal = max(barValues.max() ?? 1, 1)
        let _ = { print("📊 [Chart] tab=\(selectedTab), breakdowns=\(breakdowns.count), barValues=\(barValues), maxVal=\(maxVal)") }()
        
        return VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
            if barValues.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Text("No data yet")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            } else {
                GeometryReader { geo in
                    let chartHeight = geo.size.height
                    let barCount = barValues.count
                    let spacing: CGFloat = AppSpacing.sm + AppSpacing.xs
                    let totalSpacing = spacing * CGFloat(max(1, barCount) - 1)
                    let fullBarWidth = barCount > 0 ? (geo.size.width - totalSpacing) / CGFloat(barCount) : 0
                    let barWidth = fullBarWidth * 0.7  // 30% narrower

                    ZStack(alignment: .bottom) {
                        if average > 0 {
                            let avgY = chartHeight - (average / maxVal) * chartHeight * 0.85
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: avgY))
                                path.addLine(to: CGPoint(x: geo.size.width, y: avgY))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(AppColors.overlayWhiteAt25)
                        }

                        if average > 0 {
                            Text("avg $\(formatted(average))")
                                .font(.cardRowMeta)
                                .foregroundStyle(AppColors.overlayWhiteForegroundSoft)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }

                        HStack(alignment: .bottom, spacing: spacing) {
                            ForEach(Array(barValues.enumerated()), id: \.offset) { _, value in
                                let normalizedHeight = (value / maxVal) * chartHeight * 0.85
                                UnevenRoundedRectangle(topLeadingRadius: AppSpacing.xs, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: AppSpacing.xs)
                                    .fill(AppColors.overlayWhiteMid)
                                    .frame(width: barWidth, height: max(6, normalizedHeight))
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
            
            let labels = breakdowns.map { monthAbbreviation(from: $0.month) }
            if !labels.isEmpty {
                HStack {
                    ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.cardRowMeta)
                            .foregroundStyle(AppColors.overlayWhiteForegroundSoft)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }
    
    private func chartValues(for tab: MetricTab, breakdowns: [MonthlyBreakdownItem]) -> [Double] {
        switch tab {
        case .income:
            return breakdowns.map { $0.income }
        case .savings:
            return breakdowns.map { max(0, $0.savings) }
        case .expenses:
            return breakdowns.map { $0.fixed + $0.flexible }
        }
    }
    
    // MARK: - AI Insights
    
    private var aiInsightsSection: some View {
        let insights = viewModel.diagnosis?.aiDiagnosis.insights ?? []
        
        return VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
            Text("AI INSIGHTS")
                .font(.label)
                .tracking(1.0)
                .foregroundStyle(AppColors.overlayWhiteForegroundSoft)
                .padding(.bottom, AppSpacing.xs)
            
            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                insightCard(insight: insight)
            }
        }
    }
    
    @ViewBuilder
    private func insightCard(insight: DiagnosisInsight) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(insight.title)
                .font(.figureSecondarySemibold)
                .foregroundStyle(AppColors.textPrimary)

            Text(insight.description)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                .lineSpacing(4)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.type) insight: \(insight.title). \(insight.description)")
    }
    
    // MARK: - Goal Gap

    @ViewBuilder
    private var goalGapSection: some View {
        if viewModel.isLoadingFeasibility {
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                    .tint(AppColors.textSecondary)
                Text("Analyzing your goal...")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
            .background(AppColors.overlayWhiteWash)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
            )
        } else if let f = viewModel.goalFeasibility {
            goalGapCard(f)
        }
    }

    @ViewBuilder
    private func goalGapCard(_ f: GoalFeasibilityResult) -> some View {
        let (statusLabel, statusColor, copy) = feasibilityDisplay(f)
        let isOnTrack = f.phaseSub == "0a" || f.phaseSub == "0b" || f.phaseSub == "0c"
        let gap = max(0, f.requiredMonthlyContribution - f.currentPath.monthlySavings)

        VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
            Text("YOUR GOAL GAP")
                .font(.label)
                .tracking(1.0)
                .foregroundStyle(AppColors.overlayWhiteForegroundSoft)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(statusLabel)
                    .font(.footnoteSemibold)
                    .foregroundStyle(statusColor)
                Text(copy)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isOnTrack {
                Rectangle()
                    .fill(AppColors.overlayWhiteStroke)
                    .frame(height: 1)
                    .padding(.vertical, AppSpacing.xs)

                goalStatRow(label: "Current savings",
                            amount: f.currentPath.monthlySavings,
                            rate: f.currentPath.savingsRate)
                goalStatRow(label: "Required for goal",
                            amount: f.requiredMonthlyContribution,
                            rate: f.requiredSavingsRate)

                HStack {
                    Text("Gap")
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(gap > 0 ? "+$\(formatted(gap))/mo" : "None")
                        .font(.inlineFigureBold)
                        .foregroundStyle(gap > 0 ? statusColor : AppColors.success)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func goalStatRow(label: String, amount: Double, rate: Double) -> some View {
        HStack {
            Text(label)
                .font(.inlineLabel)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                Text("$\(formatted(amount))")
                    .font(.inlineFigureBold)
                    .foregroundStyle(AppColors.textPrimary)
                Text("(\(Int(rate.rounded()))%)")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func feasibilityDisplay(_ f: GoalFeasibilityResult) -> (label: String, color: Color, copy: String) {
        let gap = max(0, f.requiredMonthlyContribution - f.currentPath.monthlySavings)
        let gapStr = formatted(gap)

        switch f.phaseSub {
        case "0a":
            return ("ON TRACK", AppColors.success,
                    "You've already hit your FIRE number.")
        case "0b", "0c":
            return ("ON TRACK", AppColors.success,
                    "You're on track to retire at \(viewModel.targetRetirementAge).")
        case "0d":
            return ("ACHIEVABLE", AppColors.warning,
                    "Achievable — you need $\(gapStr) more/month.")
        default:
            if f.phase == 2 {
                return ("NEEDS ADJUSTMENT", AppColors.error,
                        "Goal needs adjustment — current income can't support this timeline.")
            }
            let planFeasibility = f.planA?.feasibility ?? f.currentPath.feasibility
            switch planFeasibility {
            case "comfortable", "balanced":
                return ("ACHIEVABLE", AppColors.warning,
                        "Achievable — you need $\(gapStr) more/month.")
            case "aggressive":
                return ("AMBITIOUS", AppColors.progressOrange,
                        "Ambitious — requires significant lifestyle change.")
            default:
                return ("NEEDS ADJUSTMENT", AppColors.error,
                        "Goal needs adjustment — current income can't support this timeline.")
            }
        }
    }

    // MARK: - Sticky CTA
    
    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [AppColors.backgroundPrimary.opacity(0), AppColors.backgroundPrimary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)
            
            Button {
                viewModel.goToStep(.choosePath)
            } label: {
                Text("Continue")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: AppColors.gradientFire, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundPrimary)
        }
    }
    
    // MARK: - Helpers
    
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
