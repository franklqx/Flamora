//
//  BS_DiagnosisView.swift
//  Flamora app
//
//  Budget Setup — Step 2: Your Financial Snapshot
//  V2: Shows income/savings/expenses stat cards, interactive bar chart,
//  and AI insights. Fixed/Flexible breakdown moved to Step 3.
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
    
    private let gradientColors = [Color(hex: "F5D76E"), Color(hex: "E8829B"), Color(hex: "B4A0E5")]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 60)

                    headerSection
                        .padding(.horizontal, 26)
                        .padding(.bottom, 24)

                    metricTabCards
                        .padding(.horizontal, 26)
                        .padding(.bottom, 16)
                        .opacity(showMetrics ? 1 : 0)
                        .offset(y: showMetrics ? 0 : 10)
                    
                    barChartSection
                        .padding(.horizontal, 26)
                        .padding(.bottom, 16)
                        .opacity(showChart ? 1 : 0)
                        .offset(y: showChart ? 0 : 10)

                    aiInsightsSection
                        .padding(.horizontal, 26)
                        .padding(.bottom, 16)
                        .opacity(showInsights ? 1 : 0)
                        .offset(y: showInsights ? 0 : 10)
                    
                    Spacer().frame(height: 140)
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
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Financial Snapshot")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            
            if let stats = viewModel.spendingStats {
                Text("Based on \(stats.totalTransactions) transactions over \(stats.monthsAnalyzed) months.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "ABABAB"))
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

        return HStack(spacing: 10) {
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
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.08 * 9)
                    .foregroundStyle(Color.white.opacity(0.35))

                Text("\(isNegative ? "-" : "")$\(formatted(abs(value)))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isNegative ? Color(hex: "EF4444") : .white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06),
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
        
        return VStack(alignment: .leading, spacing: 12) {
            if barValues.isEmpty {
                VStack(spacing: 8) {
                    Text("No data yet")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "ABABAB"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            } else {
                GeometryReader { geo in
                    let chartHeight = geo.size.height
                    let barCount = barValues.count
                    let spacing: CGFloat = 12
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
                            .foregroundStyle(.white.opacity(0.15))
                        }

                        if average > 0 {
                            Text("avg $\(formatted(average))")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.3))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }

                        HStack(alignment: .bottom, spacing: spacing) {
                            ForEach(Array(barValues.enumerated()), id: \.offset) { _, value in
                                let normalizedHeight = (value / maxVal) * chartHeight * 0.85
                                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 4)
                                    .fill(Color.white.opacity(0.15))
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
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("AI INSIGHTS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 4)
            
            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                insightCard(insight: insight)
            }
        }
    }
    
    @ViewBuilder
    private func insightCard(insight: DiagnosisInsight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(insight.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(insight.description)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .lineSpacing(4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.type) insight: \(insight.title). \(insight.description)")
    }
    
    // MARK: - Sticky CTA
    
    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.black.opacity(0), Color.black], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
            
            Button {
                viewModel.goToStep(.spendingBreakdown)
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 100))
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
            .background(Color.black)
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
