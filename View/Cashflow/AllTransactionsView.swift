//
//  AllTransactionsView.swift
//  Flamora app
//
//  Full transaction list — date-grouped, filterable by All / Needs / Wants.
//

import SwiftUI

struct AllTransactionsView: View {
    @Binding var transactions: [Transaction]
    var linkedAccounts: [Account] = []
    let onUpdate: (Transaction) async throws -> Void

    @State private var filter: String = "all"   // "all" | "needs" | "wants"
    @State private var selectedTransaction: Transaction? = nil
    @State private var dragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    Text("Transactions")
                        .font(.h2)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.bodySmallSemibold)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surfaceElevated)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

                // MARK: Filter tabs
                HStack(spacing: AppSpacing.sm) {
                    filterTab(label: "All",   value: "all")
                    filterTab(label: "Needs", value: "needs")
                    filterTab(label: "Wants", value: "wants")
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.md)

                // MARK: Transaction list
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(groupedTransactions, id: \.0) { dateLabel, group in
                            // Section header
                            Text(dateLabel)
                                .font(.cardHeader)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(0.8)
                                .padding(.top, AppSpacing.lg)
                                .padding(.bottom, AppSpacing.sm)
                                .padding(.horizontal, AppSpacing.screenPadding)

                            // Rows
                            ForEach(group) { transaction in
                                TransactionRow(transaction: transaction) {
                                    selectedTransaction = transaction
                                }
                                .padding(.horizontal, AppSpacing.screenPadding)
                                .padding(.bottom, AppSpacing.cardGap)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .background(AppColors.backgroundPrimary)
            }
            .offset(y: dragOffset)
        }
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
        .preferredColorScheme(.dark)
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction, linkedAccounts: linkedAccounts) { updated in
                try await onUpdate(updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Filter tab

    @ViewBuilder
    private func filterTab(label: String, value: String) -> some View {
        let isSelected = filter == value
        Button(action: { filter = value }) {
            Text(label)
                .font(.inlineLabel)
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.vertical, AppSpacing.sm)
                .padding(.horizontal, AppSpacing.md)
                .background(isSelected ? AppColors.surfaceElevated : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? AppColors.surfaceBorder : AppColors.surfaceBorder.opacity(0.5),
                        lineWidth: 0.75
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var filteredTransactions: [Transaction] {
        switch filter {
        case "needs": return transactions.filter { $0.category == "needs" }
        case "wants": return transactions.filter { $0.category == "wants" }
        default:      return transactions
        }
    }

    /// Groups transactions by date label, sorted newest first.
    private var groupedTransactions: [(String, [Transaction])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var groups: [(String, [Transaction])] = []
        var seen: [String] = []

        let sorted = filteredTransactions.sorted { lhs, rhs in
            // Sort by date desc, then time desc
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
                groups[idx].1.append(tx)
            }
        }
        return groups
    }

    private func sectionLabel(for raw: String, today: Date, yesterday: Date) -> String {
        let calendar = Calendar.current
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        let parts = raw.split(separator: "-")
        var month: Int?
        var day: Int?

        if parts.count == 2 {
            month = Int(parts[0]); day = Int(parts[1])
        } else if parts.count == 3 {
            month = Int(parts[1]); day = Int(parts[2])
        }

        guard let m = month, let d = day, m >= 1, m <= 12 else { return raw }

        // Build a comparable date for today/yesterday check
        let year = calendar.component(.year, from: Date())
        var comps = DateComponents()
        comps.year = year; comps.month = m; comps.day = d
        if let txDate = calendar.date(from: comps) {
            if calendar.isDate(txDate, inSameDayAs: today)     { return "TODAY" }
            if calendar.isDate(txDate, inSameDayAs: yesterday) { return "YESTERDAY" }
        }

        return "\(months[m - 1].uppercased()) \(d)"
    }
}
