//
//  NetWorthCard.swift
//  Flamora app
//

import SwiftUI

struct NetWorthCard: View {
    let netWorth: NetWorth

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Text("Total Net Worth")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#B0B0B0"))

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(formatCurrencyInteger(netWorth.total))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)

                Text(formatCurrencyDecimal(netWorth.total))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#8A8F98"))
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))

                Text("+\(formatCurrency(netWorth.growthAmount)) (\(String(format: "%.1f", netWorth.growthPercent))%)")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#34C759"))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(hex: "#34C759").opacity(0.18))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func formatCurrencyInteger(_ value: Double) -> String {
        let integerPart = Int(value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(integerPart))) ?? "$0"
    }

    private func formatCurrencyDecimal(_ value: Double) -> String {
        let decimalPart = value.truncatingRemainder(dividingBy: 1)
        let cents = Int(decimalPart * 100)
        return String(format: ".%02d", cents)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NetWorthCard(netWorth: MockData.journeyData.netWorth)
    }
}
