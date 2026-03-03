//
//  AccountsCard.swift
//  Flamora app
//

import SwiftUI

struct AccountsCard: View {
    let accounts: [Account]
    var onViewAllTapped: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("INVESTMENT ACCOUNTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(0.8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
            .onTapGesture { onViewAllTapped?() }

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            // Account rows
            ForEach(accounts.indices, id: \.self) { index in
                AccountRow(account: accounts[index])
                if index < accounts.count - 1 {
                    Rectangle()
                        .fill(AppColors.surfaceBorder)
                        .frame(height: 0.5)
                        .padding(.horizontal, AppSpacing.cardPadding)
                }
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(account.institution)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(account.type)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Text(formatCurrency(account.balance))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, 14)
    }

    private var iconName: String {
        switch account.type.lowercased() {
        case "investment": return "banknote"
        case "brokerage":  return "building.columns"
        case "crypto":     return "bitcoinsign.circle"
        default:           return "creditcard"
        }
    }

    private var iconColor: Color {
        switch account.type.lowercased() {
        case "investment": return AppColors.accentPurple
        case "brokerage":  return AppColors.accentBlue
        case "crypto":     return AppColors.accentPink
        default:           return AppColors.accentPurple
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
        Color.black.ignoresSafeArea()
        AccountsCard(accounts: MockData.investmentData.accounts).padding()
    }
}
