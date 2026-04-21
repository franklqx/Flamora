//
//  NetWorthDetailView.swift
//  Flamora app
//
//  Dedicated Home net-worth detail page in the current light-shell style.
//

import SwiftUI
import Charts

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

    private var breakdownItems: [BreakdownItem] {
        [
            BreakdownItem(id: "investments", label: "Investments", value: max(investments, 0), tint: AppColors.accentPurple, isLiability: false, note: "Brokerage and investing accounts"),
            BreakdownItem(id: "cash", label: "Cash", value: max(cash, 0), tint: AppColors.budgetNeedsBlue, isLiability: false, note: "Checking and savings balances"),
            BreakdownItem(id: "credit", label: "Credit card debt", value: credit, tint: AppColors.warning, isLiability: true, note: "Short-term revolving balances"),
            BreakdownItem(id: "loans", label: "Loans", value: loans, tint: AppColors.error, isLiability: true, note: "Student, auto, and other loans")
        ].filter { $0.value > 0 }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                    header
                    heroCard
                    trendCard
                    compositionCard
                    if let summary, !summary.accounts.isEmpty {
                        accountsCard(summary.accounts)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xl + AppSpacing.lg)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Net Worth")
                .font(.h1)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(-0.5)

            Spacer()

            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.inkTrack)
                        .frame(width: 34, height: 34)
                    Image(systemName: "xmark")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("CURRENT TOTAL")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)

            Text(formatCurrency(totalNetWorth))
                .font(.currencyHero)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()

            HStack(spacing: AppSpacing.sm) {
                deltaChip

                if let synced = summary?.lastSyncedAt, !synced.isEmpty {
                    Text("Last synced \(formattedSyncDate(synced))")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                summaryMetric(label: "Assets", value: formatCurrency(totalAssets))
                summaryDivider
                summaryMetric(label: "Debt", value: formatCurrency(totalLiabilities))
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

    @ViewBuilder
    private var deltaChip: some View {
        if let growthAmount = summary?.growthAmount, let growthPercentage = summary?.growthPercentage {
            let isPositive = growthAmount >= 0
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                Text("\(formatCurrency(abs(growthAmount))) (\(formatPercent(growthPercentage))) this month")
                    .font(.footnoteSemibold)
                    .monospacedDigit()
            }
            .foregroundStyle(isPositive ? AppColors.success : AppColors.error)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background((isPositive ? AppColors.success : AppColors.error).opacity(0.12))
            .clipShape(Capsule())
        } else {
            Text("More history will sharpen your net-worth trend.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
        }
    }

    private func summaryMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
            Text(value)
                .font(.footnoteBold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(AppColors.inkBorder)
            .frame(width: 1, height: 30)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("TREND")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkFaint)
                    .tracking(AppTypography.Tracking.cardHeader)

                Spacer()
            }

            if currentPoints.count >= 2 {
                Chart {
                    ForEach(currentPoints) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Net Worth", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AppColors.inkPrimary.opacity(0.16),
                                    AppColors.inkPrimary.opacity(0.02)
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
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(AppColors.inkDivider)
                        AxisValueLabel()
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: 220)
            } else {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.inkTrack)
                    .frame(height: 220)
                    .overlay(
                        Text("Not enough history yet")
                            .font(.bodyRegular)
                            .foregroundStyle(AppColors.inkSoft)
                    )
            }

            HStack(spacing: 0) {
                ForEach(NetWorthRange.allCases) { range in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedRange = range
                        }
                    } label: {
                        Text(range.label)
                            .font(.segmentLabel(selected: selectedRange == range))
                            .foregroundStyle(selectedRange == range ? AppColors.inkPrimary : AppColors.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedRange == range ? AppColors.ctaWhite.opacity(0.9) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(AppColors.inkTrack.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private var compositionCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("COMPOSITION")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                balanceBar(label: "Assets", value: totalAssets, total: max(totalAssets + totalLiabilities, 1), tint: AppColors.inkPrimary)
                balanceBar(label: "Debt", value: totalLiabilities, total: max(totalAssets + totalLiabilities, 1), tint: AppColors.error.opacity(0.85))
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

    private func balanceBar(label: String, value: Double, total: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(label)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
                Text(formatCurrency(value))
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                Capsule()
                    .fill(AppColors.inkTrack)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * CGFloat(value / total))
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
                .font(.detailTitle)
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
                    .foregroundStyle(AppColors.inkFaint)
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
            ZStack {
                Circle()
                    .fill(iconTint(for: account).opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName(for: account))
                    .font(.footnoteSemibold)
                    .foregroundStyle(iconTint(for: account))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(metaLine(for: account))
                    .font(.caption)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatCurrency(account.balance ?? 0))
                .font(.footnoteBold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }

    private func groupedAccounts(_ accounts: [APIAccount]) -> [(title: String, accounts: [APIAccount])] {
        let groups = Dictionary(grouping: accounts) { account -> String in
            switch account.type {
            case "investment": return "Investments"
            case "credit": return "Credit"
            case "loan": return "Loans"
            default: return "Cash"
            }
        }
        return ["Investments", "Cash", "Credit", "Loans"]
            .compactMap { key in
                guard let values = groups[key], !values.isEmpty else { return nil }
                return (key, values.sorted { ($0.balance ?? 0) > ($1.balance ?? 0) })
            }
    }

    private func iconName(for account: APIAccount) -> String {
        switch account.type {
        case "investment": return "chart.line.uptrend.xyaxis"
        case "credit": return "creditcard"
        case "loan": return "banknote"
        default: return "building.columns"
        }
    }

    private func iconTint(for account: APIAccount) -> Color {
        switch account.type {
        case "investment": return AppColors.accentPurple
        case "credit": return AppColors.warning
        case "loan": return AppColors.error
        default: return AppColors.budgetNeedsBlue
        }
    }

    private func metaLine(for account: APIAccount) -> String {
        var parts: [String] = []
        if let institution = account.institution, !institution.isEmpty {
            parts.append(institution)
        }
        if let subtype = account.subtype, !subtype.isEmpty {
            parts.append(subtype.capitalized)
        }
        if let mask = account.mask, !mask.isEmpty {
            parts.append("••\(mask)")
        }
        return parts.joined(separator: " · ")
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let sign = value < 0 ? "-" : ""
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0"
        return sign + formatted
    }

    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }

    private func formattedSyncDate(_ isoString: String) -> String {
        let input = ISO8601DateFormatter()
        guard let date = input.date(from: isoString) else { return "recently" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
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
            lastSyncedAt: "2026-04-20T08:30:00Z"
        ),
        history: HomeNetWorthCard.mockHistory()
    )
}
