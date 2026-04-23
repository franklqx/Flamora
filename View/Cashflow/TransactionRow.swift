//
//  TransactionRow.swift
//  Flamora app
//
//  Light-shell transaction row — slots into glass cards with inkDivider separators.
//  No own background; container provides card chrome.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    var titleOverride: String? = nil
    var contextLine: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(iconTint.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: categoryIcon)
                        .font(.footnoteSemibold)
                        .foregroundStyle(iconTint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleOverride ?? transaction.merchant)
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                    Text(metaLine)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkFaint)
                        .lineLimit(1)
                }

                Spacer()

                Text(formattedAmount(transaction.amount))
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meta line (category · date · time)

    private var metaLine: String {
        var parts: [String] = [categoryLabel]
        if let contextLine, !contextLine.isEmpty {
            parts.append(contextLine)
        } else {
            parts.append(dateTimeLabel)
        }
        return parts.joined(separator: "  ·  ")
    }

    private var categoryLabel: String {
        if let sub = transaction.subcategory,
           let name = TransactionCategoryCatalog.displayName(forStoredSubcategory: sub) {
            return name
        }
        if let cat = transaction.category {
            return cat == "needs" ? "Needs" : "Wants"
        }
        return "Uncategorized"
    }

    private var dateTimeLabel: String {
        let datePart = formattedDate(transaction.date)
        if let t = transaction.time, !t.isEmpty {
            return "\(datePart) · \(t)"
        }
        return datePart
    }

    // MARK: - Icon + tint

    private var iconTint: Color {
        let parent: String? = {
            if let sub = transaction.subcategory {
                return TransactionCategoryCatalog.parent(forStoredSubcategory: sub) ?? transaction.category
            }
            return transaction.category
        }()
        switch parent {
        case "needs": return AppColors.budgetNeedsBlue
        case "wants": return AppColors.accentPurple
        default: return AppColors.inkSoft
        }
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
