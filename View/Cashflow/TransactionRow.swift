//
//  TransactionRow.swift
//  Flamora app
//
//  Reusable transaction row — used in CashflowView and AllTransactionsView.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    var titleOverride: String? = nil
    var contextLine: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {

                // MARK: Icon
                ZStack {
                    Circle()
                        .fill(AppColors.surfaceElevated)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(AppColors.surfaceBorder, lineWidth: 0.75))
                    Image(systemName: categoryIcon)
                        .font(.inlineLabel)
                        .foregroundColor(AppColors.textSecondary)
                }

                // MARK: Merchant + date/time
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleOverride ?? transaction.merchant)
                        .font(.figureSecondarySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                    if let contextLine, !contextLine.isEmpty {
                        Text(contextLine)
                            .font(.inlineLabel)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    Text(dateTimeLabel)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                // MARK: Amount + badge
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formattedAmount(transaction.amount))
                        .font(.cardFigureSecondary)
                        .foregroundStyle(AppColors.textPrimary)
                    categoryBadge
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, 14)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badge

    @ViewBuilder
    private var categoryBadge: some View {
        let (label, bg, fg, showBorder) = badgeStyle
        Text(label)
            .font(.miniLabel)
            .foregroundColor(fg)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(bg)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    showBorder ? AppColors.surfaceBorder : Color.clear,
                    lineWidth: 0.75
                )
            )
    }

    private var badgeStyle: (String, Color, Color, Bool) {
        if let sub = transaction.subcategory {
            let resolvedParent = TransactionCategoryCatalog.parent(forStoredSubcategory: sub) ?? transaction.category
            let color = resolvedParent == "needs" ? AppColors.chartBlue : AppColors.chartGold
            let label = TransactionCategoryCatalog.displayName(forStoredSubcategory: sub) ?? sub
            return (label, color.opacity(0.2), color, false)
        }
        if let cat = transaction.category {
            let color = cat == "needs" ? AppColors.chartBlue : AppColors.chartGold
            let label = cat == "needs" ? "Needs" : "Wants"
            return (label, color.opacity(0.2), color, false)
        }
        return ("Classify", Color.clear, AppColors.textTertiary, true)
    }

    // MARK: - Helpers

    private var dateTimeLabel: String {
        let datePart = formattedDate(transaction.date)
        if let t = transaction.time, !t.isEmpty {
            return "\(datePart)  ·  \(t)"
        }
        return datePart
    }

    private var categoryIcon: String {
        if let icon = TransactionCategoryCatalog.icon(forStoredSubcategory: transaction.subcategory) {
            return icon
        }
        return merchantIcon(for: transaction.merchant)
    }

    private func merchantIcon(for merchant: String) -> String {
        let m = merchant.lowercased()
        if m.contains("rent") || m.contains("mortgage")                      { return "house.fill" }
        if m.contains("whole foods") || m.contains("grocery") || m.contains("market") { return "cart.fill" }
        if m.contains("netflix") || m.contains("spotify") || m.contains("apple music") || m.contains("hulu") { return "play.tv.fill" }
        if m.contains("gas") || m.contains("shell") || m.contains("chevron") { return "fuelpump.fill" }
        if m.contains("starbucks") || m.contains("coffee") || m.contains("cafe") { return "cup.and.saucer.fill" }
        if m.contains("uber") || m.contains("lyft")                          { return "car.fill" }
        if m.contains("amazon") || m.contains("target") || m.contains("walmart") { return "bag.fill" }
        if m.contains("eats") || m.contains("restaurant") || m.contains("dining") { return "fork.knife" }
        return "creditcard.fill"
    }

    private func formattedDate(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        if parts.count == 2, let m = Int(parts[0]), let d = Int(parts[1]), m >= 1, m <= 12 {
            return "\(months[m - 1]) \(d)"
        }
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]), m >= 1, m <= 12 {
            return "\(months[m - 1]) \(d)"
        }
        return raw
    }

    private func formattedAmount(_ amount: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        return fmt.string(from: NSNumber(value: -amount)) ?? "$0.00"
    }
}
