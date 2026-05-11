//
//  AccountsCard.swift
//  Flamora app
//

import SwiftUI

struct AccountsCard: View {
    let accounts: [Account]
    var isConnected: Bool = true
    var onAddAccount: (() -> Void)? = nil
    var lastSyncedAt: String? = nil
    @State private var selectedAccount: Account?

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
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

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isConnected {
                if groupedAccounts.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No investment accounts yet",
                        message: "Add a brokerage or retirement account to see your FIRE progress reflect real holdings.",
                        actionTitle: onAddAccount == nil ? nil : "Add account",
                        action: onAddAccount
                    )
                    .padding(.vertical, AppSpacing.sm)
                } else {
                    ForEach(Array(groupedAccounts.enumerated()), id: \.offset) { sectionIndex, section in
                        if sectionIndex > 0 {
                            divider
                        }

                        VStack(spacing: 0) {
                            sectionHeader(section.title)

                            ForEach(Array(section.accounts.enumerated()), id: \.element.id) { index, account in
                                Button(action: { selectedAccount = account }) {
                                    AccountRow(account: account, lastSyncedAt: lastSyncedAt)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(account.name ?? account.institution), balance \(Int(account.balance)) dollars")
                                .accessibilityHint("Open account details")

                                if index < section.accounts.count - 1 {
                                    divider
                                }
                            }
                        }
                    }

                    divider
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
                    .accessibilityLabel("Add account")
                    .accessibilityHint("Connect another investment or bank account")
                }
            } else {
                disconnectedContent
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .fullScreenCover(item: $selectedAccount) { account in
            AccountDetailView(account: account)
        }
    }

    private var groupedAccounts: [(title: String, accounts: [Account])] {
        let groups = Dictionary(grouping: accounts) { account -> String in
            switch account.accountType {
            case .brokerage:
                return "Investments"
            case .bank:
                return "Cash"
            case .crypto:
                return "Crypto"
            }
        }

        return ["Investments", "Cash", "Crypto"].compactMap { title in
            guard let values = groups[title], !values.isEmpty else { return nil }
            return (title, values.sorted { abs($0.balance) > abs($1.balance) })
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

    private var disconnectedContent: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "building.columns")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkFaint)
                Text("No accounts connected")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("Connect your bank and investment accounts to see them here.")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

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
            .accessibilityLabel("Add account")
            .accessibilityHint("Connect your first bank or investment account")
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: Account
    var lastSyncedAt: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            BankLogoView(
                logoBase64: account.institutionLogoBase64,
                primaryColorHex: account.institutionPrimaryColor,
                institutionName: account.institution,
                fallbackSymbol: iconName,
                fallbackColor: iconColor
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name ?? account.institution)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                Text(accountMaskText)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkFaint)
                    .lineLimit(1)
            }
            Spacer()
            Text(formatCurrency(account.balance))
                .font(.footnoteSemibold)
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
    private var fallbackIcon: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 38, height: 38)
            Image(systemName: iconName)
                .font(.footnoteSemibold)
                .foregroundStyle(iconColor)
        }
    }

    private var iconName: String {
        switch account.accountType {
        case .brokerage:
            return "chart.line.uptrend.xyaxis"
        case .crypto:
            return "bitcoinsign.circle"
        case .bank:
            return "building.columns"
        }
    }

    private var iconColor: Color {
        switch account.accountType {
        case .brokerage:
            return AppColors.allocEmerald
        case .crypto:
            return AppColors.allocAmber
        case .bank:
            return AppColors.allocIndigo
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
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        AccountsCard(accounts: MockData.allAccounts).padding()
    }
}
