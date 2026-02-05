//
//  AccountsCard.swift
//  Flamora app
//

import SwiftUI

struct AccountsCard: View {
    let accounts: [Account]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(accounts.indices, id: \.self) { index in
                AccountRow(account: accounts[index])

                if index < accounts.count - 1 {
                    Divider()
                        .overlay(Color(hex: "#1A1A1A"))
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 6)
        .background(Color(hex: "#121212"))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(account.institution)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(account.type)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#6B7280"))
            }

            Spacer()

            Text(formatCurrency(account.balance))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var iconName: String {
        switch account.type.lowercased() {
        case "investment": return "banknote"
        case "brokerage": return "building.columns"
        case "crypto": return "bitcoinsign.circle"
        default: return "creditcard"
        }
    }

    private var iconColor: Color {
        switch account.type.lowercased() {
        case "investment": return Color(hex: "#60A5FA")
        case "brokerage": return Color(hex: "#F87171")
        case "crypto": return Color(hex: "#F59E0B")
        default: return Color(hex: "#A78BFA")
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.2)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AccountsCard(accounts: MockData.investmentData.accounts)
            .padding()
    }
}
