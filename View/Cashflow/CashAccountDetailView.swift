//
//  CashAccountDetailView.swift
//  Flamora app
//
//  Cashflow-semantic account detail：balance + transactions。
//  只用于 depository / credit 账户，不显示 holdings。
//

import SwiftUI

struct CashAccountDetailView: View {
    let account: APIAccount
    @Environment(\.dismiss) private var dismiss

    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var selectedTransaction: Transaction?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    balanceSection
                    Divider()
                        .background(AppColors.surfaceBorder)
                        .padding(.horizontal, AppSpacing.cardPadding)
                    transactionsSection
                    Spacer(minLength: AppSpacing.xl)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await loadTransactions() }
        .offset(y: dragOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { v in
                    if v.translation.height > 0 { dragOffset = v.translation.height }
                }
                .onEnded { v in
                    if v.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(item: $selectedTransaction) { txn in
            let acct = Account(
                id: account.id,
                institution: account.institution ?? "",
                accountType: account.type == "credit" ? .bank : .bank,
                balance: account.balance ?? 0,
                connected: true,
                logoUrl: nil
            )
            TransactionDetailSheet(transaction: txn, linkedAccounts: [acct]) { updated in
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
            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.h4)
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitleLine)
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }

    // MARK: - Balance

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(formatCurrency(account.balance ?? 0))
                .font(.h1)
                .foregroundStyle(AppColors.textPrimary)
            Text(account.type == "credit" ? "Balance owed" : "Current balance")
                .font(.footnoteRegular)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.lg)
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

            if isLoading {
                HStack {
                    ProgressView()
                        .tint(AppColors.textTertiary)
                    Text("Loading transactions…")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.lg)
            } else if transactions.isEmpty {
                Text("No transactions found")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedTransactions, id: \.0) { label, group in
                        Text(label)
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

    // MARK: - Data

    private func loadTransactions() async {
        isLoading = true
        if let resp = try? await APIService.shared.getTransactions(page: 1, limit: 100, accountId: account.id) {
            transactions = resp.transactions.map { Transaction(from: $0) }
        }
        isLoading = false
    }

    // MARK: - Helpers

    private var accentColor: Color {
        account.type == "credit" ? AppColors.accentPink : AppColors.accentGreen
    }

    private var iconName: String {
        switch account.type {
        case "credit": return "creditcard"
        default:
            return account.subtype?.lowercased() == "savings" ? "banknote" : "building.columns"
        }
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
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }
}
