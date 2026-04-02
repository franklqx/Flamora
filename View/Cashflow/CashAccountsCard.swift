//
//  CashAccountsCard.swift
//  Flamora app
//
//  Cash 页账户列表卡片：分成 Cash Accounts（depository）和 Credit Cards（credit）两组。
//  数据来自 get-net-worth-summary.accounts，按 type 过滤后传入。
//

import SwiftUI

struct CashAccountsCard: View {
    let cashAccounts: [APIAccount]    // type == "depository"
    let creditAccounts: [APIAccount]  // type == "credit"
    var lastSyncedAt: String? = nil
    var onAddAccount: (() -> Void)? = nil

    @State private var selectedAccount: APIAccount? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ── Header
            HStack {
                Text("ACCOUNTS")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            divider

            // ── Cash Accounts section
            if !cashAccounts.isEmpty {
                sectionHeader("CASH ACCOUNTS", icon: "dollarsign.circle")
                ForEach(cashAccounts) { account in
                    Button { selectedAccount = account } label: {
                        CashAccountRow(account: account, lastSyncedAt: lastSyncedAt)
                    }
                    .buttonStyle(.plain)
                    if account.id != cashAccounts.last?.id { divider }
                }
                divider
            }

            // ── Credit Cards section
            if !creditAccounts.isEmpty {
                sectionHeader("CREDIT CARDS", icon: "creditcard")
                ForEach(creditAccounts) { account in
                    Button { selectedAccount = account } label: {
                        CashAccountRow(account: account, lastSyncedAt: lastSyncedAt)
                    }
                    .buttonStyle(.plain)
                    if account.id != creditAccounts.last?.id { divider }
                }
                divider
            }

            // ── Add Account
            Button(action: { onAddAccount?() }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.bodyRegular)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Add Account")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(.plain)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
        .fullScreenCover(item: $selectedAccount) { account in
            CashAccountDetailView(account: account)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.surfaceBorder)
            .frame(height: 0.5)
            .padding(.horizontal, AppSpacing.cardPadding)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary.opacity(0.6))
            Text(title)
                .font(.label)
                .foregroundColor(AppColors.textTertiary.opacity(0.6))
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - Account Row

private struct CashAccountRow: View {
    let account: APIAccount
    var lastSyncedAt: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.figureSecondarySemibold)
                    .foregroundColor(iconColor)
            }

            // Name + meta
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(metaLine)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(account.balance ?? 0))
                    .font(.cardFigureSecondary)
                    .foregroundStyle(AppColors.textPrimary)
                if account.type == "credit" {
                    Text("balance owed")
                        .font(.label)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }

    private var metaLine: String {
        var parts: [String] = []
        if let inst = account.institution, !inst.isEmpty { parts.append(inst) }
        if let sub = account.subtype, !sub.isEmpty { parts.append(sub.capitalized) }
        if let mask = account.mask, !mask.isEmpty { parts.append("••\(mask)") }
        return parts.joined(separator: " · ")
    }

    private var iconName: String {
        switch account.type {
        case "credit": return "creditcard"
        default:
            switch account.subtype?.lowercased() {
            case "savings": return "banknote"
            default: return "building.columns"
            }
        }
    }

    private var iconColor: Color {
        account.type == "credit" ? AppColors.accentPink : AppColors.accentGreen
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
