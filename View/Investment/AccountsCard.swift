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
            // Header
            HStack {
                Text("ACCOUNTS")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.inkMeta)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            Rectangle()
                .fill(Color.white.opacity(0.45))
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isConnected {
                // Account rows
                ForEach(accounts.indices, id: \.self) { index in
                    Button(action: { selectedAccount = accounts[index] }) {
                        AccountRow(account: accounts[index], lastSyncedAt: lastSyncedAt)
                    }
                    .buttonStyle(.plain)

                    if index < accounts.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(height: 0.5)
                            .padding(.horizontal, AppSpacing.cardPadding)
                    }
                }

                // Add Account button
                Rectangle()
                    .fill(Color.white.opacity(0.45))
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

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
            } else {
                disconnectedContent
            }
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.86), Color(hex: "#F8F9FF").opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .fullScreenCover(item: $selectedAccount) { account in
            AccountDetailView(account: account)
        }
    }

    private var disconnectedContent: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "building.columns")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkMeta)
                Text("No accounts connected")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.inkSoft)
                Text("Connect your bank and investment accounts to see them here.")
                    .font(.caption)
                    .foregroundStyle(AppColors.inkMeta)
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
                Text(account.name ?? account.institution)
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(accountSubtypeLabel)
                    .font(.caption)
                    .foregroundColor(AppColors.inkMeta)
            }
            Spacer()
            Text(formatCurrency(account.balance))
                .font(.cardFigureSecondary)
                .foregroundStyle(AppColors.inkPrimary)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
    }

    /// e.g. "Brokerage • 7892" or just "Brokerage"
    private var accountSubtypeLabel: String {
        var parts: [String] = [account.accountType.displayLabel]
        if let mask = account.mask, !mask.isEmpty {
            parts.append("•\u{00A0}\(mask)")
        }
        return parts.joined(separator: " ")
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
        AppColors.backgroundPrimary.ignoresSafeArea()
        AccountsCard(accounts: MockData.allAccounts).padding()
    }
}
