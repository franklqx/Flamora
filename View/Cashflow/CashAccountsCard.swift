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

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header
            HStack {
                Text("ACCOUNTS")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            divider

            if !cashAccounts.isEmpty {
                sectionHeader("Cash")
                ForEach(cashAccounts) { account in
                    Button { selectedAccount = account } label: {
                        CashAccountRow(account: account, lastSyncedAt: lastSyncedAt)
                    }
                    .buttonStyle(.plain)
                    if account.id != cashAccounts.last?.id { divider }
                }
                divider
            }

            if !creditAccounts.isEmpty {
                sectionHeader("Debt")
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
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("Add Account")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(.plain)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .fullScreenCover(item: $selectedAccount) { account in
            CashAccountDetailView(account: account)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.inkDivider)
            .frame(height: 0.5)
            .padding(.horizontal, AppSpacing.cardPadding)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
            Spacer()
        }
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
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.footnoteSemibold)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                Text(accountMaskText)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkFaint)
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


    private var accountMaskText: String {
        let last4 = (account.mask ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return last4.isEmpty ? "••••" : "•••• \(last4)"
    }
    private var iconName: String {
        switch account.type {
        case "credit":
            return "creditcard"
        case "loan":
            return "banknote"
        default:
            switch account.subtype?.lowercased() {
            case "savings":
                return "banknote"
            default:
                return "building.columns"
            }
        }
    }

    private var iconColor: Color {
        switch account.type {
        case "credit":
            return AppColors.warning
        case "loan":
            return AppColors.error
        default:
            return AppColors.budgetNeedsBlue
        }
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
