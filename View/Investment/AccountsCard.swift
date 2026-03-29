//
//  AccountsCard.swift
//  Flamora app
//

import SwiftUI

struct AccountsCard: View {
    let accounts: [Account]
    @State private var selectedAccount: Account?

    var body: some View {
        VStack(spacing: 0) {
            // Header
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

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            // Account rows
            ForEach(accounts.indices, id: \.self) { index in
                Button(action: { selectedAccount = accounts[index] }) {
                    AccountRow(account: accounts[index])
                }
                .buttonStyle(.plain)

                if index < accounts.count - 1 {
                    Rectangle()
                        .fill(AppColors.surfaceBorder)
                        .frame(height: 0.5)
                        .padding(.horizontal, AppSpacing.cardPadding)
                }
            }

            // Add Account button
            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            Button(action: { /* TODO: add account flow */ }) {
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
            AccountDetailView(account: account)
        }
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            accountLogo
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(account.institution)
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text(lastUpdatedLabel)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            Text(formatCurrency(account.balance))
                .font(.cardFigureSecondary)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.md)
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

    private var lastUpdatedLabel: String {
        guard let date = MockData.accountLastUpdated[account.id] else { return "Updated recently" }
        return timeAgo(from: date)
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60               { return "Updated just now" }
        let minutes = seconds / 60
        if minutes < 60               { return "Updated \(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24                 { return "Updated \(hours)h ago" }
        return "Updated \(hours / 24)d ago"
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
