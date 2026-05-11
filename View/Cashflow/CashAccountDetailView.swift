//
//  CashAccountDetailView.swift
//  Flamora app
//
//  Light-shell master template for secondary detail pages.
//  Structure: shellBg gradient → glass hero card (balance + chart + range)
//  → glass transactions card (grouped, inkDivider separators).
//

import SwiftUI
import Charts

struct CashAccountDetailView: View {
    let account: APIAccount
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPeriod: AccountHistoryRange = .oneMonth
    @State private var transactions: [Transaction] = []
    @State private var historySnapshots: [BalanceSnapshot] = []
    @State private var historyCache: [AccountHistoryRange: [BalanceSnapshot]] = [:]
    @State private var isLoading = true
    @State private var isHistoryLoading = true
    @State private var selectedTransaction: Transaction?

    init(account: APIAccount) {
        self.account = account

        let cache = TabContentCache.shared
        let cachedTransactions = cache.cashAccountTransactions(for: account.id) ?? []
        var cachedHistoryByRange: [AccountHistoryRange: [BalanceSnapshot]] = [:]
        for range in AccountHistoryRange.allCases {
            if let snapshots = cache.cashAccountHistory(for: account.id, range: range) {
                cachedHistoryByRange[range] = snapshots
            }
        }
        let initialSnapshots = cachedHistoryByRange[.oneMonth] ?? []

        _transactions = State(initialValue: cachedTransactions)
        _historySnapshots = State(initialValue: initialSnapshots)
        _historyCache = State(initialValue: cachedHistoryByRange)
        _isLoading = State(initialValue: cachedTransactions.isEmpty)
        _isHistoryLoading = State(initialValue: initialSnapshots.isEmpty)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        DetailSheetScaffold(title: account.name) {
            dismiss()
        } content: {
            heroCard
            transactionsCard
        }
        .task { await loadTransactionsIfNeeded() }
        .task(id: selectedPeriod) { await loadHistory() }
        .sheet(item: $selectedTransaction) { txn in
            let acct = Account(
                id: account.id,
                institution: account.institution ?? "",
                accountType: .bank,
                balance: account.balance ?? 0,
                connected: true,
                logoUrl: nil
            )
            TransactionDetailSheet(transaction: txn, linkedAccounts: [acct]) { updated in
                try await persistTransactionClassification(updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.shellBg1)
        }
    }

    // MARK: - Hero card (identity + balance + chart + range)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                BankLogoView(
                    logoBase64: account.institutionLogoBase64,
                    primaryColorHex: account.institutionPrimaryColor,
                    institutionName: account.institution,
                    fallbackSymbol: iconName,
                    fallbackColor: accentColor
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(balanceLabel)
                        .font(.cardHeader)
                        .foregroundStyle(AppColors.inkPrimary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Text(subtitleLine)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineLimit(1)
                }
                Spacer()
            }

            Text(formatCurrency(account.balance ?? 0))
                .font(.portfolioHero)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()

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

    @ViewBuilder
    private var balanceChart: some View {
        if isHistoryLoading && historySnapshots.isEmpty {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.inkTrack)
                .frame(height: 180)
                .overlay(
                    ProgressView().tint(AppColors.inkSoft)
                )
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
                    Text(emptyChartText)
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

            if isLoading {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView().tint(AppColors.inkSoft)
                    Text("Loading transactions…")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
            } else if transactions.isEmpty {
                Text("No transactions recorded for this account")
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.cardPadding)
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
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

        var groups: [(String, [Transaction])] = []
        var seen: [String] = []
        let sorted = transactions.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return ($0.time ?? "") > ($1.time ?? "")
        }

        for tx in sorted {
            let parts = tx.date.split(separator: "-")
            var label = tx.date
            if parts.count >= 3,
               let m = Int(parts[1]), let d = Int(parts[2]),
               m >= 1, m <= 12 {
                var comps = DateComponents()
                comps.year = Int(parts[0]); comps.month = m; comps.day = d
                if let txDate = calendar.date(from: comps) {
                    if calendar.isDate(txDate, inSameDayAs: today) { label = "TODAY" }
                    else if calendar.isDate(txDate, inSameDayAs: yesterday) { label = "YESTERDAY" }
                    else { label = "\(months[m - 1].uppercased()) \(d)" }
                }
            }
            if !seen.contains(label) {
                seen.append(label)
                groups.append((label, []))
            }
            if let idx = groups.firstIndex(where: { $0.0 == label }) {
                groups[idx].1.append(tx)
            }
        }
        return groups
    }

    // MARK: - Data (unchanged)

    private func loadTransactionsIfNeeded() async {
        if !transactions.isEmpty {
            isLoading = false
            return
        }

        isLoading = true
        if let resp = try? await APIService.shared.getTransactions(page: 1, limit: 100, accountId: account.id) {
            transactions = resp.transactions.map { Transaction(from: $0) }
            TabContentCache.shared.setCashAccountTransactions(transactions, for: account.id)
        }
        isLoading = false
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
        TabContentCache.shared.setCashAccountTransactions(transactions, for: account.id)
    }

    private func loadHistory() async {
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
        TabContentCache.shared.setCashAccountHistory(snapshots, for: account.id, range: selectedPeriod)

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
            TabContentCache.shared.setCashAccountHistory(snapshots, for: account.id, range: range)
        }
    }

    // MARK: - Helpers

    private var accentColor: Color {
        account.type == "credit" ? AppColors.warning : AppColors.budgetNeedsBlue
    }

    private var iconName: String {
        switch account.type {
        case "credit": return "creditcard"
        default:
            return account.subtype?.lowercased() == "savings" ? "banknote" : "building.columns"
        }
    }

    private var balanceLabel: String {
        account.type == "credit" ? "BALANCE OWED" : "CURRENT BALANCE"
    }

    private var emptyChartText: String {
        account.type == "credit"
            ? "Balance history will appear after your next few syncs"
            : "Balance history will appear after your next few syncs"
    }

    private var subtitleLine: String {
        var parts: [String] = []
        if let inst = account.institution, !inst.isEmpty { parts.append(inst) }
        if let sub = account.subtype, !sub.isEmpty { parts.append(sub.capitalized) }
        if let mask = account.mask, !mask.isEmpty { parts.append("••\(mask)") }
        return parts.isEmpty ? "Bank Account" : parts.joined(separator: " · ")
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }

    private static let accountHistoryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
