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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ACCOUNTS")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.inkFaint)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.xs)

            Text("Your connected investment accounts.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isConnected {
                if accounts.isEmpty {
                    emptyConnectedContent
                } else {
                    ForEach(accounts.indices, id: \.self) { index in
                        Button(action: { selectedAccount = accounts[index] }) {
                            AccountRow(account: accounts[index], lastSyncedAt: lastSyncedAt)
                        }
                        .buttonStyle(.plain)

                        if index < accounts.count - 1 {
                            Rectangle()
                                .fill(AppColors.inkDivider)
                                .frame(height: 0.5)
                                .padding(.horizontal, AppSpacing.cardPadding)
                        }
                    }
                }
            } else {
                disconnectedContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .fill(AppColors.glassCardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                        .fill(AppColors.glassCardBg2)
                        .padding(1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.glassPanel))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .glassCardShadow()
        .fullScreenCover(item: $selectedAccount) { account in
            AccountDetailView(account: account)
        }
    }

    private var emptyConnectedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("No investment accounts found yet.")
                .font(.figureSecondarySemibold)
                .foregroundStyle(AppColors.inkPrimary)
            Text("We'll list each connected brokerage or crypto account here as soon as the sync completes.")
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }

    private var disconnectedContent: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "building.columns")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkFaint.opacity(0.7))
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
                        .foregroundStyle(AppColors.ctaWhite)
                    Text("Add Account")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.ctaWhite)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.ctaBlack)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)
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
        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            accountLogo
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(account.institution.isEmpty ? (account.name ?? "Investment Account") : account.institution)
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(accountSubtypeLabel)
                    .font(.caption)
                    .foregroundColor(AppColors.inkSoft)
            }
            Spacer()
            Text(formatCurrency(account.balance))
                .font(.cardFigureSecondary)
                .foregroundStyle(AppColors.inkPrimary)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }

    private var accountSubtypeLabel: String {
        if let mask = account.mask, !mask.isEmpty {
            return "•••• \(mask)"
        }
        return account.accountType.displayLabel
    }

    @ViewBuilder
    private var accountLogo: some View {
        if let urlString = account.logoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                default:
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 38, height: 38)
            Image(systemName: iconName)
                .font(.figureSecondarySemibold)
                .foregroundColor(iconColor)
        }
    }

    private var iconName: String {
        switch account.accountType {
        case .brokerage: return "building.columns"
        case .crypto:    return "bitcoinsign.circle"
        case .bank:      return "creditcard"
        }
    }

    private var iconColor: Color {
        switch account.accountType {
        case .brokerage: return AppColors.accentBlue
        case .crypto:    return AppColors.accentPink
        case .bank:      return AppColors.accentGreen
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
}

#Preview {
    ZStack {
        LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        AccountsCard(accounts: MockData.allAccounts).padding()
    }
}
