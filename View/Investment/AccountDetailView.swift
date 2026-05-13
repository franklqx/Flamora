//
//  AccountDetailView.swift
//  Meridian
//
//  Light-shell detail page for a brokerage / crypto / bank account.
//  Shell pattern mirrors CashAccountDetailView: shellBg gradient →
//  glass hero card (balance + chart + range) → glass holdings/transactions card.
//

import SwiftUI
import Charts

struct AccountDetailView: View {
    let account: Account
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: AccountHistoryRange = .oneMonth
    @State private var selectedTransaction: Transaction?
    @State private var transactions: [Transaction] = []
    @State private var apiHoldings: [Holding] = []
    @State private var historySnapshots: [BalanceSnapshot] = []
    @State private var historyCache: [AccountHistoryRange: [BalanceSnapshot]] = [:]
    @State private var isHistoryLoading = true

    init(account: Account) {
        self.account = account

        let cache = TabContentCache.shared
        let cachedTransactions = cache.investmentAccountTransactions(for: account.id) ?? []
        var cachedHistoryByRange: [AccountHistoryRange: [BalanceSnapshot]] = [:]
        for range in AccountHistoryRange.allCases {
            if let snapshots = cache.investmentAccountHistory(for: account.id, range: range) {
                cachedHistoryByRange[range] = snapshots
            }
        }

        let cachedHoldings: [Holding]
        if let payload = cache.investmentHoldings {
            cachedHoldings = payload.holdings
                .filter { $0.plaidAccountId == account.id }
                .map { InvestmentAllocationBuilder.holding(from: $0) }
                .sorted { $0.totalValue > $1.totalValue }
        } else {
            cachedHoldings = []
        }

        _transactions = State(initialValue: cachedTransactions)
        _apiHoldings = State(initialValue: cachedHoldings)
        _historySnapshots = State(initialValue: cachedHistoryByRange[.oneMonth] ?? [])
        _historyCache = State(initialValue: cachedHistoryByRange)
        _isHistoryLoading = State(initialValue: (cachedHistoryByRange[.oneMonth] ?? []).isEmpty)
    }

    private var holdings: [Holding] { apiHoldings }
    private var filteredSnapshots: [BalanceSnapshot] { historySnapshots }

    private var performancePercent: Double? {
        guard let first = filteredSnapshots.first?.balance,
              let last = filteredSnapshots.last?.balance,
              first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Body

    var body: some View {
        DetailSheetScaffold(title: account.name ?? account.institution) {
            dismiss()
        } content: {
            heroCard
            if account.accountType.isInvestment {
                holdingsCard
            } else {
                transactionsCard
            }
        }
        .task { await loadAccountDataIfNeeded() }
        .task(id: selectedPeriod) { await loadAccountHistory() }
        .sheet(item: $selectedTransaction) { txn in
            TransactionDetailSheet(transaction: txn, linkedAccounts: [account]) { updated in
                try await persistTransactionClassification(updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.shellBg1)
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                accountLogoView
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL BALANCE")
                        .font(.cardHeader)
                        .foregroundStyle(AppColors.inkPrimary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(formatCurrency(account.balance))
                    .font(.portfolioHero)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
                Spacer()
                if let pct = performancePercent {
                    perfChip(pct)
                }
            }

            balanceChart

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

    private func perfChip(_ pct: Double) -> some View {
        let isPositive = pct >= 0
        return HStack(spacing: AppSpacing.xs) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption.weight(.bold))
            Text(formatPercent(pct))
                .font(.footnoteSemibold)
                .monospacedDigit()
        }
        .foregroundStyle(isPositive ? AppColors.success : AppColors.error)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 6)
        .background((isPositive ? AppColors.success : AppColors.error).opacity(0.12))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var balanceChart: some View {
        if isHistoryLoading && historySnapshots.isEmpty {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.inkTrack)
                .frame(height: 180)
                .overlay(ProgressView().tint(AppColors.inkSoft))
        } else if historySnapshots.count >= 2 {
            Chart {
                ForEach(historySnapshots) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.allocIndigo.opacity(0.16),
                                AppColors.allocIndigo.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(AppColors.allocIndigo)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 4))
            .frame(height: 180)
        } else {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.inkTrack)
                .frame(height: 180)
                .overlay(
                    Text("Balance history will appear after your next few syncs")
                        .font(.bodyRegular)
                        .foregroundStyle(AppColors.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                )
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(AccountHistoryRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedPeriod = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.segmentLabel(selected: selectedPeriod == range))
                        .foregroundStyle(selectedPeriod == range ? AppColors.inkPrimary : AppColors.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPeriod == range ? AppColors.inkTrack : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// e.g. "Brokerage • 7892" or just "Brokerage"
    private var headerSubtitle: String {
        var parts: [String] = [account.accountType.displayLabel]
        if let mask = account.mask, !mask.isEmpty {
            parts.append("•\u{00A0}\(mask)")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Holdings card

    private var holdingsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HOLDINGS")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            if holdings.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No holdings yet",
                    message: "Once your brokerage syncs, your positions will appear here with live allocation and growth."
                )
                .padding(.bottom, AppSpacing.sm)
            } else {
                ForEach(Array(holdings.enumerated()), id: \.element.id) { idx, holding in
                    HoldingRow(holding: holding)
                    if idx < holdings.count - 1 {
                        divider
                    }
                }
                Spacer().frame(height: AppSpacing.sm)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Transactions card

    private var transactionsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRANSACTIONS")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            if groupedTransactions.isEmpty {
                EmptyStateView(
                    icon: "creditcard",
                    title: "No transactions yet",
                    message: "Recent activity will appear here within 24 hours of syncing this account."
                )
                .padding(.bottom, AppSpacing.sm)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groupedTransactions.enumerated()), id: \.element.0) { sectionIndex, group in
                        if sectionIndex > 0 {
                            divider
                        }
                        HStack {
                            Text(group.0)
                                .font(.caption)
                                .foregroundStyle(AppColors.inkFaint)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.sm)

                        ForEach(Array(group.1.enumerated()), id: \.element.id) { idx, txn in
                            TransactionRow(transaction: txn) { selectedTransaction = txn }
                            if idx != group.1.count - 1 {
                                divider
                            }
                        }
                    }
                }
                .padding(.bottom, AppSpacing.sm)
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

    // MARK: - Grouped transactions

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

    private var accountLogoView: some View {
        BankLogoView(
            logoBase64: account.institutionLogoBase64,
            primaryColorHex: account.institutionPrimaryColor,
            institutionName: account.institution,
            fallbackSymbol: iconName,
            fallbackColor: accentColor
        )
    }

    // MARK: - Data

    private func loadAccountDataIfNeeded() async {
        async let holdingsTask = apiHoldings.isEmpty ? loadHoldingsForAccount() : apiHoldings
        async let txTask = transactions.isEmpty ? loadTransactionsForAccount() : transactions
        let (h, t) = await (holdingsTask, txTask)
        await MainActor.run {
            apiHoldings = h
            transactions = t
        }
    }

    @MainActor
    private func persistTransactionClassification(_ updated: Transaction) async throws {
        let response = try await APIService.shared.updateTransactionClassification(
            transactionId: updated.id,
            category: updated.category,
            subcategory: updated.subcategory
        )
        let persisted = Transaction(from: response)
        if let idx = transactions.firstIndex(where: { $0.id == persisted.id }) {
            transactions[idx] = persisted
        }
        TabContentCache.shared.setInvestmentAccountTransactions(transactions, for: account.id)
    }

    private func loadAccountHistory() async {
        if let cached = historyCache[selectedPeriod] {
            await MainActor.run {
                historySnapshots = cached
                isHistoryLoading = false
            }
            return
        }

        let shouldShowLoader = historySnapshots.isEmpty
        if shouldShowLoader {
            await MainActor.run { isHistoryLoading = true }
        }

        guard let response = try? await APIService.shared.getAccountBalanceHistory(
            accountId: account.id,
            range: selectedPeriod.apiValue
        ) else {
            await MainActor.run {
                if shouldShowLoader { historySnapshots = [] }
                isHistoryLoading = false
            }
            return
        }

        let snapshots = response.points.compactMap { point -> BalanceSnapshot? in
            guard let date = Self.accountHistoryDateFormatter.date(from: point.date) else { return nil }
            return BalanceSnapshot(
                id: "\(account.id)-\(point.date)",
                accountId: account.id,
                date: date,
                balance: point.currentBalance
            )
        }

        await MainActor.run {
            historyCache[selectedPeriod] = snapshots
            historySnapshots = snapshots
            isHistoryLoading = false
        }
        TabContentCache.shared.setInvestmentAccountHistory(snapshots, for: account.id, range: selectedPeriod)

        await prefetchOtherRanges(excluding: selectedPeriod)
    }

    private func prefetchOtherRanges(excluding current: AccountHistoryRange) async {
        for range in AccountHistoryRange.allCases where range != current && historyCache[range] == nil {
            guard let response = try? await APIService.shared.getAccountBalanceHistory(
                accountId: account.id,
                range: range.apiValue
            ) else { continue }

            let snapshots = response.points.compactMap { point -> BalanceSnapshot? in
                guard let date = Self.accountHistoryDateFormatter.date(from: point.date) else { return nil }
                return BalanceSnapshot(
                    id: "\(account.id)-\(point.date)",
                    accountId: account.id,
                    date: date,
                    balance: point.currentBalance
                )
            }

            await MainActor.run {
                historyCache[range] = snapshots
            }
            TabContentCache.shared.setInvestmentAccountHistory(snapshots, for: account.id, range: range)
        }
    }

    private func loadHoldingsForAccount() async -> [Holding] {
        if let payload = TabContentCache.shared.investmentHoldings {
            return payload.holdings
                .filter { $0.plaidAccountId == account.id }
                .map { InvestmentAllocationBuilder.holding(from: $0) }
                .sorted { $0.totalValue > $1.totalValue }
        }
        guard let payload = try? await APIService.shared.getInvestmentHoldings() else { return [] }
        TabContentCache.shared.setInvestmentHoldings(payload)
        return payload.holdings
            .filter { $0.plaidAccountId == account.id }
            .map { InvestmentAllocationBuilder.holding(from: $0) }
            .sorted { $0.totalValue > $1.totalValue }
    }

    private func loadTransactionsForAccount() async -> [Transaction] {
        if let cached = TabContentCache.shared.investmentAccountTransactions(for: account.id) {
            return cached
        }
        guard let response = try? await APIService.shared.getTransactions(
            page: 1,
            limit: 100,
            accountId: account.id
        ) else { return [] }
        let mapped = response.transactions.map { Transaction(from: $0) }
        TabContentCache.shared.setInvestmentAccountTransactions(mapped, for: account.id)
        return mapped
    }

    // MARK: - Helpers

    private var accentColor: Color {
        switch account.accountType {
        case .brokerage: return AppColors.allocEmerald
        case .crypto:    return AppColors.allocAmber
        case .bank:      return AppColors.allocIndigo
        }
    }

    private var iconName: String {
        switch account.accountType {
        case .brokerage: return "chart.line.uptrend.xyaxis"
        case .crypto:    return "bitcoinsign.circle"
        case .bank:      return "building.columns"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return String(format: "\(sign)%.1f%%", value)
    }

    private static let accountHistoryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - Holding Row (light-shell)

private struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            TickerBadge(symbol: holding.symbol)

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.name)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                Text(sharesLabel)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkFaint)
            }

            Spacer()

            Text(formatCurrency(holding.totalValue))
                .font(.footnoteSemibold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
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
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Range enum (shared with CashAccountDetailView)

enum AccountHistoryRange: String, CaseIterable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"

    var apiValue: String {
        switch self {
        case .oneWeek: return "1w"
        case .oneMonth: return "1m"
        case .threeMonths: return "3m"
        case .oneYear: return "1y"
        }
    }
}

#Preview {
    AccountDetailView(account: MockData.allAccounts[0])
}
