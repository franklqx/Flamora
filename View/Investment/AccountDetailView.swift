//
//  AccountDetailView.swift
//  Flamora app
//

import SwiftUI

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
    @State private var dragOffset: CGFloat = 0

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
        .task {
            await loadAccountDataIfNeeded()
        }
        .task(id: selectedPeriod) {
            await loadAccountHistory()
        }
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
            TransactionDetailSheet(transaction: txn, linkedAccounts: [account]) { updated in
                try await persistTransactionClassification(updated)
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
                Text(account.name ?? account.institution)
                    .font(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text(headerSubtitle)
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

    /// e.g. "Brokerage • 7892" or just "Brokerage"
    private var headerSubtitle: String {
        var parts: [String] = [account.accountType.displayLabel]
        if let mask = account.mask, !mask.isEmpty {
            parts.append("•\u{00A0}\(mask)")
        }
        return parts.joined(separator: " ")
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
        AccountHistoryCard(
            snapshots: filteredSnapshots,
            selectedRange: selectedPeriod,
            isLoading: isHistoryLoading,
            emptyTitle: "Balance history is starting",
            emptySubtitle: "We'll show account value after your next few syncs.",
            onSelectRange: { selectedPeriod = $0 }
        )
        .padding(.horizontal, AppSpacing.cardPadding)
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

    private static let accountHistoryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
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

struct AccountHistoryCard: View {
    let snapshots: [BalanceSnapshot]
    let selectedRange: AccountHistoryRange
    let isLoading: Bool
    let emptyTitle: String
    let emptySubtitle: String
    let onSelectRange: (AccountHistoryRange) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            rangeSelector

            ZStack {
                if snapshots.count >= 2 {
                    AccountHistoryLineChart(snapshots: snapshots)
                        .transition(.opacity)
                } else if isLoading {
                    loadingState
                        .transition(.opacity)
                } else {
                    emptyState
                        .transition(.opacity)
                }
            }
            .frame(height: 164)
            .animation(.easeInOut(duration: 0.2), value: snapshots.map(\.id).joined())
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppSpacing.sm)
    }

    private var loadingState: some View {
        AccountHistoryLineChart(snapshots: placeholderSnapshots)
            .opacity(0.55)
            .overlay(
                LinearGradient(
                    colors: [Color.clear, AppColors.overlayWhiteWash, Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blur(radius: 6)
            )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Rectangle()
                .fill(AppColors.progressTrack.opacity(0.35))
                .frame(height: 1)
            Text(emptyTitle)
                .font(.footnoteRegular)
                .foregroundColor(AppColors.textTertiary)
            Text(emptySubtitle)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var rangeSelector: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(AccountHistoryRange.allCases, id: \.self) { range in
                Button(action: { onSelectRange(range) }) {
                    Text(range.rawValue)
                        .font(.cardHeader)
                        .foregroundStyle(selectedRange == range ? AppColors.textInverse : AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? AppColors.textPrimary : AppColors.surface)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var placeholderSnapshots: [BalanceSnapshot] {
        let today = Date()
        return [
            BalanceSnapshot(id: "loading-1", accountId: "loading", date: today.addingTimeInterval(-86400 * 3), balance: 100),
            BalanceSnapshot(id: "loading-2", accountId: "loading", date: today.addingTimeInterval(-86400 * 2), balance: 101),
            BalanceSnapshot(id: "loading-3", accountId: "loading", date: today.addingTimeInterval(-86400), balance: 100.7),
            BalanceSnapshot(id: "loading-4", accountId: "loading", date: today, balance: 101.2),
        ]
    }
}

private struct AccountHistoryLineChart: View {
    let snapshots: [BalanceSnapshot]

    var body: some View {
        GeometryReader { geo in
            let values = snapshots.map { $0.balance }
            let minVal = (values.min() ?? 0) * 0.98
            let maxVal = (values.max() ?? 1) * 1.02
            let range = max(maxVal - minVal, 1)
            let width = max(geo.size.width, 1)
            let height = max(geo.size.height, 1)
            let lineColor = AppColors.accentBlue
            let glowColor = AppColors.accentBlueBright

            let points = snapshots.enumerated().map { index, snapshot in
                CGPoint(
                    x: width * CGFloat(index) / CGFloat(max(snapshots.count - 1, 1)),
                    y: height * CGFloat(1 - (snapshot.balance - minVal) / range)
                )
            }

            ZStack {
                Path { path in
                    guard let first = points.first, let last = points.last else { return }
                    path.move(to: CGPoint(x: first.x, y: height))
                    points.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: last.x, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [glowColor.opacity(0.16), glowColor.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 2)

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(glowColor.opacity(0.22), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .blur(radius: 5)

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(AppColors.textPrimary)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(lineColor.opacity(0.85), lineWidth: 1.5)
                        )
                        .position(last)
                }
            }
        }
    }
}

#Preview {
    AccountDetailView(account: MockData.allAccounts[0])
}
