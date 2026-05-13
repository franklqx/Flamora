//
//  NetWorthDetailView.swift
//  Meridian
//
//  Dedicated Home net-worth detail page in the current light-shell style.
//

import SwiftUI
import Charts
import UIKit

struct NetWorthDetailView: View {
    private struct BreakdownItem: Identifiable {
        let id: String
        let label: String
        let value: Double
        let tint: Color
        let isLiability: Bool
        let note: String
    }

    let summary: APINetWorthSummary?
    let history: [NetWorthRange: [NetWorthPoint]]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: NetWorthRange = .year
    @State private var scrubbedPoint: NetWorthPoint?

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var totalNetWorth: Double { summary?.totalNetWorth ?? 0 }
    private var investments: Double { summary?.breakdown.investmentTotal ?? 0 }
    private var cash: Double { summary?.breakdown.depositoryTotal ?? 0 }
    private var credit: Double { abs(summary?.breakdown.creditTotal ?? 0) }
    private var loans: Double { abs(summary?.breakdown.loanTotal ?? 0) }
    private var totalAssets: Double { max(investments, 0) + max(cash, 0) }
    private var totalLiabilities: Double { credit + loans }
    private var currentPoints: [NetWorthPoint] { history[selectedRange] ?? [] }

    private var rangeStartValue: Double {
        currentPoints.first?.value ?? 0
    }

    private var displayedValue: Double {
        scrubbedPoint?.value ?? totalNetWorth
    }

    private var deltaAmount: Double {
        displayedValue - rangeStartValue
    }

    private var deltaPercent: Double {
        guard rangeStartValue != 0 else { return 0 }
        return (deltaAmount / abs(rangeStartValue)) * 100
    }

    private var rangePeriodLabel: String {
        switch selectedRange {
        case .week: return "past 1 week"
        case .month: return "past 1 month"
        case .threeMonths: return "past 3 months"
        case .year: return "past 1 year"
        case .all: return "all-time"
        }
    }

    private var deltaTrailingLabel: String {
        if let scrubbed = scrubbedPoint {
            return formattedScrubDateFull(scrubbed.date)
        }
        return rangePeriodLabel
    }

    private var breakdownItems: [BreakdownItem] {
        [
            BreakdownItem(id: "investments", label: "Investments", value: max(investments, 0), tint: AppColors.allocEmerald, isLiability: false, note: "Brokerage and investing accounts"),
            BreakdownItem(id: "cash", label: "Cash", value: max(cash, 0), tint: AppColors.allocIndigo, isLiability: false, note: "Checking and savings balances"),
            BreakdownItem(id: "credit", label: "Credit card debt", value: credit, tint: AppColors.allocAmber, isLiability: true, note: "Short-term revolving balances"),
            BreakdownItem(id: "loans", label: "Loans", value: loans, tint: AppColors.allocCoral, isLiability: true, note: "Student, auto, and other loans")
        ].filter { $0.value > 0 }
    }

    var body: some View {
        DetailSheetScaffold(title: "Net Worth") {
            dismiss()
        } content: {
            heroTrendCard
            compositionCard
            if let summary, !summary.accounts.isEmpty {
                accountsCard(summary.accounts)
            }
        }
    }

    private var heroTrendCard: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.xs) {
                Text(formatCurrency(displayedValue))
                    .font(.portfolioHero)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: displayedValue)

                deltaRow
            }
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.sm)

            trendChart

            rangeSelector
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var rangeSelector: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(NetWorthRange.allCases) { range in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedRange = range
                        scrubbedPoint = nil
                    }
                } label: {
                    Text(range.label)
                        .font(.segmentLabel(selected: selectedRange == range))
                        .foregroundStyle(selectedRange == range ? AppColors.inkPrimary : AppColors.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedRange == range ? AppColors.inkTrack : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var deltaRow: some View {
        if currentPoints.count >= 2 {
            let isPositive = deltaAmount >= 0
            let accent = isPositive ? AppColors.success : AppColors.error
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.footnoteBold)
                    .foregroundStyle(accent)
                Text(formatCurrency(abs(deltaAmount)))
                    .font(.footnoteSemibold)
                    .foregroundStyle(accent)
                    .monospacedDigit()
                Text("(\(formatPercent(deltaPercent)))")
                    .font(.footnoteSemibold)
                    .foregroundStyle(accent)
                    .monospacedDigit()
                Text(deltaTrailingLabel)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
            }
            .animation(.easeOut(duration: 0.15), value: deltaAmount)
        } else {
            Text("More history will sharpen your net-worth trend.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
        }
    }

    @ViewBuilder
    private var trendChart: some View {
        if currentPoints.count >= 2 {
            interactiveChart
        } else {
            NetWorthEmptyHistoryView(chartHeight: 220)
                .padding(.vertical, AppSpacing.sm)
        }
    }

    private var interactiveChart: some View {
        Chart {
            ForEach(currentPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Net Worth", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#60A5FA").opacity(0.30),
                            Color(hex: "#818CF8").opacity(0.08),
                            Color(hex: "#818CF8").opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Net Worth", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: AppColors.gradientShellAccent,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartXScale(range: .plotDimension(startPadding: 8, endPadding: 8))
        .chartYScale(domain: chartDomain)
        .frame(height: 220)
        .clipped()
        .chartOverlay { proxy in
            GeometryReader { geo in
                let plotFrame = geo[proxy.plotAreaFrame]

                ZStack(alignment: .topLeading) {
                    if let scrubbed = scrubbedPoint,
                       let xPos = proxy.position(forX: scrubbed.date),
                       let yPos = proxy.position(forY: scrubbed.value) {
                        let absX = xPos + plotFrame.minX
                        let absY = yPos + plotFrame.minY

                        Rectangle()
                            .fill(AppColors.inkDivider)
                            .frame(width: 1, height: plotFrame.height)
                            .position(x: absX, y: plotFrame.midY)
                            .allowsHitTesting(false)

                        Text(formattedScrubDateShort(scrubbed.date))
                            .font(.smallLabel)
                            .foregroundStyle(AppColors.inkPrimary)
                            .monospacedDigit()
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 4)
                            .background(AppColors.ctaWhite.opacity(0.95))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.glassCardBorder, lineWidth: 1)
                            )
                            .position(x: absX, y: plotFrame.minY + 10)
                            .allowsHitTesting(false)

                        Circle()
                            .fill(Color(hex: "#60A5FA"))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.ctaWhite, lineWidth: 2)
                            )
                            .position(x: absX, y: absY)
                            .allowsHitTesting(false)
                    }

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let localX = value.location.x - plotFrame.minX
                                    guard localX >= 0, localX <= plotFrame.width else { return }
                                    guard let date: Date = proxy.value(atX: localX, as: Date.self) else { return }
                                    guard let nearest = currentPoints.min(by: {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    }) else { return }
                                    if scrubbedPoint?.id != nearest.id {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        scrubbedPoint = nearest
                                    }
                                }
                                .onEnded { _ in
                                    if scrubbedPoint != nil {
                                        scrubbedPoint = nil
                                    }
                                }
                        )
                }
            }
        }
    }

    private var compositionCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("COMPOSITION")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                balanceBar(
                    label: "Assets",
                    value: totalAssets,
                    total: max(totalAssets + totalLiabilities, 1),
                    segments: assetCompositionSegments
                )
                balanceBar(
                    label: "Debt",
                    value: totalLiabilities,
                    total: max(totalAssets + totalLiabilities, 1),
                    segments: debtCompositionSegments
                )
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppSpacing.sm + AppSpacing.xs
            ) {
                ForEach(breakdownItems) { item in
                    breakdownCard(item)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var assetCompositionSegments: [(value: Double, tint: Color)] {
        [
            (value: max(investments, 0), tint: AppColors.allocEmerald),
            (value: max(cash, 0), tint: AppColors.allocIndigo)
        ].filter { $0.value > 0 }
    }

    private var debtCompositionSegments: [(value: Double, tint: Color)] {
        [
            (value: credit, tint: AppColors.allocAmber),
            (value: loans, tint: AppColors.allocCoral)
        ].filter { $0.value > 0 }
    }

    private func balanceBar(label: String, value: Double, total: Double, segments: [(value: Double, tint: Color)]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(label)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
                Text(formatCurrency(value))
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                Capsule()
                    .fill(AppColors.inkTrack)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 0) {
                            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                                Rectangle()
                                    .fill(segment.tint)
                                    .frame(width: geo.size.width * CGFloat(segment.value / total))
                            }
                        }
                        .clipShape(Capsule())
                    }
            }
            .frame(height: 8)
        }
    }

    private func breakdownCard(_ item: BreakdownItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(item.tint)
                    .frame(width: 8, height: 8)
                Text(item.label)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
            }

            Text(formatCurrency(item.isLiability ? -item.value : item.value))
                .font(.figureMedium)
                .foregroundStyle(item.isLiability ? AppColors.inkSoft : AppColors.inkPrimary)
                .monospacedDigit()

            Text(item.note)
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.ctaWhite.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private func accountsCard(_ accounts: [APIAccount]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("ACCOUNTS")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            ForEach(Array(groupedAccounts(accounts).enumerated()), id: \.offset) { sectionIndex, section in
                if sectionIndex > 0 {
                    divider
                }

                VStack(spacing: 0) {
                    HStack {
                        Text(section.title)
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)

                    ForEach(Array(section.accounts.enumerated()), id: \.element.id) { idx, account in
                        accountRow(account)
                        if idx != section.accounts.count - 1 {
                            divider
                        }
                    }
                }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.inkDivider)
            .frame(height: 0.5)
            .padding(.horizontal, AppSpacing.cardPadding)
    }

    private func accountRow(_ account: APIAccount) -> some View {
        HStack(spacing: AppSpacing.md) {
            BankLogoView(
                logoBase64: account.institutionLogoBase64,
                primaryColorHex: account.institutionPrimaryColor,
                institutionName: account.institution,
                fallbackSymbol: iconName(for: account),
                fallbackColor: iconTint(for: account)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                Text(accountMaskText(account))
                    .font(.caption)
                    .foregroundStyle(AppColors.inkFaint)
                    .lineLimit(1)
            }
            Spacer()

            Text(formatCurrency(account.balance ?? 0))
                .font(.footnoteSemibold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }


    private func accountMaskText(_ account: APIAccount) -> String {
        let last4 = (account.mask ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return last4.isEmpty ? "••••" : "•••• \(last4)"
    }
    private func groupedAccounts(_ accounts: [APIAccount]) -> [(title: String, accounts: [APIAccount])] {
        let groups = Dictionary(grouping: accounts) { account -> String in
            switch account.type {
            case "investment":
                return "Investments"
            case "credit", "loan":
                return "Debt"
            default:
                return "Cash"
            }
        }

        return ["Investments", "Cash", "Debt"].compactMap { title in
            guard let values = groups[title], !values.isEmpty else { return nil }
            return (title, values.sorted { abs($0.balance ?? 0) > abs($1.balance ?? 0) })
        }
    }

    private func iconName(for account: APIAccount) -> String {
        switch account.type {
        case "investment":
            return "chart.line.uptrend.xyaxis"
        case "credit":
            return "creditcard"
        case "loan":
            return "banknote"
        default:
            return account.subtype?.lowercased() == "savings" ? "banknote" : "building.columns"
        }
    }

    private func iconTint(for account: APIAccount) -> Color {
        switch account.type {
        case "investment":
            return AppColors.allocEmerald
        case "credit":
            return AppColors.allocAmber
        case "loan":
            return AppColors.allocCoral
        default:
            return AppColors.allocIndigo
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let sign = value < 0 ? "-" : ""
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0.00"
        return sign + formatted
    }

    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }

    // Robinhood-style：紧贴真实 min/max，上下各留 ~12% 呼吸空间。
    // 单调上升的 net worth 不会再把起点钉在左下角，而是落在中下偏上。
    private var chartDomain: ClosedRange<Double> {
        let values = currentPoints.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...1
        }
        let span = max(maxValue - minValue, max(abs(maxValue) * 0.01, 1))
        let padding = span * 0.12
        return (minValue - padding)...(maxValue + padding)
    }

    private func formatCompactCurrency(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        let compactValue = Int((abs(value) / 1_000).rounded())
        return "\(sign)$\(compactValue)k"
    }

    private func formattedSyncDate(_ isoString: String) -> String {
        let input = ISO8601DateFormatter()
        guard let date = input.date(from: isoString) else { return "recently" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formattedScrubDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formattedScrubDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    NetWorthDetailView(
        summary: APINetWorthSummary(
            totalNetWorth: 248_360,
            previousNetWorth: 241_000,
            growthAmount: 7_360,
            growthPercentage: 3.05,
            asOfDate: "2026-04-20",
            breakdown: APINetWorthSummary.NetWorthBreakdown(
                investmentTotal: 182_000,
                depositoryTotal: 78_500,
                creditTotal: 2_400,
                loanTotal: 9_740
            ),
            accounts: [
                APIAccount(id: "1", name: "Brokerage", type: "investment", subtype: "brokerage", balance: 182_000, mask: "8877", institution: "Fidelity"),
                APIAccount(id: "2", name: "Checking", type: "depository", subtype: "checking", balance: 31_500, mask: "2211", institution: "Chase"),
                APIAccount(id: "3", name: "Savings", type: "depository", subtype: "savings", balance: 47_000, mask: "7788", institution: "Ally"),
                APIAccount(id: "4", name: "Freedom", type: "credit", subtype: "credit card", balance: 2_400, mask: "9900", institution: "Chase")
            ],
            startingPortfolioBalance: 182_000,
            startingPortfolioSource: "plaid_investment",
            lastSyncedAt: "2026-04-20T08:30:00Z"
        ),
        history: [:]
    )
}
