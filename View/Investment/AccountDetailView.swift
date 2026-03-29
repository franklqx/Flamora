//
//  AccountDetailView.swift
//  Flamora app
//

import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: ChartPeriod = .oneMonth
    @State private var selectedTransaction: Transaction?
    @State private var transactions: [Transaction]
    @State private var dragOffset: CGFloat = 0

    init(account: Account) {
        self.account = account
        _transactions = State(initialValue:
            MockData.allTransactions.filter { $0.accountId == account.id }
        )
    }

    enum ChartPeriod: String, CaseIterable {
        case oneWeek      = "1W"
        case oneMonth     = "1M"
        case threeMonths  = "3M"
        case oneYear      = "1Y"
    }

    private var holdings: [Holding] {
        MockData.holdings.filter { $0.accountId == account.id }
    }

    private var filteredSnapshots: [BalanceSnapshot] {
        let all = MockData.accountBalanceHistory[account.id] ?? []
        let cal = Calendar.current
        let now = Date()
        let cutoff: Date
        switch selectedPeriod {
        case .oneWeek:     cutoff = cal.date(byAdding: .weekOfYear, value: -1,  to: now) ?? now
        case .oneMonth:    cutoff = cal.date(byAdding: .month,      value: -1,  to: now) ?? now
        case .threeMonths: cutoff = cal.date(byAdding: .month,      value: -3,  to: now) ?? now
        case .oneYear:     cutoff = cal.date(byAdding: .year,       value: -1,  to: now) ?? now
        }
        let filtered = all.filter { $0.date >= cutoff }
        return filtered.count >= 2 ? filtered : Array(all.suffix(2))
    }

    private var performancePercent: Double? {
        guard filteredSnapshots.count >= 2 else { return nil }
        let start   = filteredSnapshots.first!.balance
        let current = filteredSnapshots.last!.balance
        guard start > 0 else { return nil }
        return (current - start) / start * 100
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    balanceSection
                    chartSection
                    Divider()
                        .background(AppColors.surfaceBorder)
                        .padding(.horizontal, AppSpacing.cardPadding)
                    if account.accountType.isInvestment {
                        holdingsSection
                    } else {
                        transactionsSection
                    }
                    Spacer(minLength: AppSpacing.xl)
                }
            }
            .background(AppColors.backgroundPrimary)
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(item: $selectedTransaction) { txn in
            TransactionDetailSheet(transaction: txn) { updated in
                if let idx = transactions.firstIndex(where: { $0.id == updated.id }) {
                    transactions[idx] = updated
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: AppSpacing.md) {
            accountLogoView
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(account.institution)
                    .font(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text(lastUpdatedLabel)
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }

    // MARK: - Balance

    private var balanceSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(formatCurrency(account.balance))
                    .font(.h1)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Total balance")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            if let pct = performancePercent {
                Text(formatPercent(pct))
                    .font(.bodySemibold)
                    .foregroundColor(pct >= 0 ? AppColors.accentGreen : AppColors.accentRed)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Period selector
            HStack(spacing: AppSpacing.sm) {
                ForEach(ChartPeriod.allCases, id: \.self) { period in
                    Button(action: { selectedPeriod = period }) {
                        Text(period.rawValue)
                            .font(.smallLabel)
                            .foregroundColor(selectedPeriod == period
                                ? AppColors.textPrimary
                                : AppColors.textTertiary)
                            .frame(width: 36, height: 28)
                            .background(selectedPeriod == period
                                ? AppColors.surfaceElevated
                                : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)

            AccountLineChart(snapshots: filteredSnapshots, accentColor: accentColor)
                .frame(height: 120)
                .padding(.horizontal, AppSpacing.cardPadding)
        }
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: - Holdings

    private var holdingsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HOLDINGS")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)

            ForEach(holdings.indices, id: \.self) { i in
                HoldingRow(holding: holdings[i])
                if i < holdings.count - 1 {
                    Rectangle()
                        .fill(AppColors.surfaceBorder)
                        .frame(height: 0.5)
                        .padding(.horizontal, AppSpacing.cardPadding)
                }
            }
        }
    }

    // MARK: - Transactions

    private var transactionsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRANSACTIONS")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)

            if groupedTransactions.isEmpty {
                Text("No transactions for this account")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedTransactions, id: \.0) { dateLabel, group in
                        Text(dateLabel)
                            .font(.cardHeader)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.8)
                            .padding(.top, AppSpacing.lg)
                            .padding(.bottom, AppSpacing.sm)
                            .padding(.horizontal, AppSpacing.cardPadding)

                        ForEach(group) { txn in
                            TransactionRow(transaction: txn, onTap: { selectedTransaction = txn })
                                .padding(.horizontal, AppSpacing.cardPadding)
                                .padding(.bottom, AppSpacing.cardGap)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grouped Transactions

    private var groupedTransactions: [(String, [Transaction])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var groups: [(String, [Transaction])] = []
        var seen: [String] = []

        let sorted = transactions.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return (lhs.time ?? "") > (rhs.time ?? "")
        }

        for tx in sorted {
            let label = sectionLabel(for: tx.date, today: today, yesterday: yesterday)
            if !seen.contains(label) {
                seen.append(label)
                groups.append((label, []))
            }
            if let idx = groups.firstIndex(where: { $0.0 == label }) {
                var g = groups[idx]
                g.1.append(tx)
                groups[idx] = g
            }
        }
        return groups
    }

    private func sectionLabel(for raw: String, today: Date, yesterday: Date) -> String {
        let calendar = Calendar.current
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let parts = raw.split(separator: "-")
        var month: Int?
        var day: Int?

        if parts.count == 2 {
            month = Int(parts[0]); day = Int(parts[1])
        } else if parts.count == 3 {
            month = Int(parts[1]); day = Int(parts[2])
        }

        guard let m = month, let d = day, m >= 1, m <= 12 else { return raw }

        let year = calendar.component(.year, from: Date())
        var comps = DateComponents()
        comps.year = year; comps.month = m; comps.day = d
        if let txDate = calendar.date(from: comps) {
            if calendar.isDate(txDate, inSameDayAs: today) { return "TODAY" }
            if calendar.isDate(txDate, inSameDayAs: yesterday) { return "YESTERDAY" }
        }
        return "\(months[m - 1].uppercased()) \(d)"
    }

    // MARK: - Logo

    @ViewBuilder
    private var accountLogoView: some View {
        if let urlString = account.logoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                default:
                    fallbackLogo
                }
            }
        } else {
            fallbackLogo
        }
    }

    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: iconName)
                .font(.h4)
                .foregroundColor(accentColor)
        }
    }

    // MARK: - Helpers

    private var lastUpdatedLabel: String {
        guard let date = MockData.accountLastUpdated[account.id] else { return "Updated recently" }
        return timeAgo(from: date)
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60               { return "Updated just now" }
        let minutes = seconds / 60
        if minutes < 60               { return "Updated \(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24                 { return "Updated \(hours)h ago" }
        return "Updated \(hours / 24)d ago"
    }

    private var accentColor: Color {
        switch account.accountType {
        case .brokerage: return AppColors.accentBlue
        case .crypto:    return AppColors.accentPink
        case .bank:      return AppColors.accentGreen
        }
    }

    private var iconName: String {
        switch account.accountType {
        case .brokerage: return "building.columns"
        case .crypto:    return "bitcoinsign.circle"
        case .bank:      return "creditcard"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return String(format: "\(sign)%.1f%%", value)
    }
}

// MARK: - Account Line Chart

private struct AccountLineChart: View {
    let snapshots: [BalanceSnapshot]
    let accentColor: Color

    var body: some View {
        if snapshots.count < 2 {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.surfaceElevated)
        } else {
            GeometryReader { geo in
                let values  = snapshots.map { $0.balance }
                let minVal  = (values.min() ?? 0) * 0.98
                let maxVal  = (values.max() ?? 1) * 1.02
                let range   = max(maxVal - minVal, 1)
                let w = geo.size.width
                let h = geo.size.height

                let pts: [CGPoint] = snapshots.enumerated().map { i, s in
                    CGPoint(
                        x: w * CGFloat(i) / CGFloat(snapshots.count - 1),
                        y: h * CGFloat(1 - (s.balance - minVal) / range)
                    )
                }

                ZStack {
                    // Gradient fill
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.25), Color.black.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ))

                    // Line
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(accentColor, lineWidth: 2)

                    // End dot
                    if let last = pts.last {
                        Circle()
                            .fill(AppColors.textPrimary)
                            .frame(width: 8, height: 8)
                            .position(last)
                    }
                }
            }
        }
    }
}

// MARK: - Holding Row

private struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.surfaceElevated)
                    .frame(width: 44, height: 44)
                Text(holding.symbol)
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, AppSpacing.xs)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(holding.name)
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(sharesLabel)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Text(formatCurrency(holding.totalValue))
                .font(.cardFigureSecondary)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }

    private var sharesLabel: String {
        let shares = holding.shares
        if shares == shares.rounded() {
            return "\(Int(shares)) shares"
        }
        return String(format: "%.4f shares", shares)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    AccountDetailView(account: MockData.allAccounts[0])
}
