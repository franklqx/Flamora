//
//  AssetAllocationDetailView.swift
//  Flamora app
//
//  Light-shell asset allocation detail: donut on a glass hero card, then
//  glass breakdown card with expandable category rows (holdings / cash accounts).
//

import SwiftUI

// MARK: - File-level model

private struct AllocDetailItem: Identifiable {
    let id: String
    let title: String
    let percent: Int
    let amount: Double
    let color: Color
}

// MARK: - Main View

struct AssetAllocationDetailView: View {
    let allocation: Allocation
    var holdingsPayload: APIInvestmentHoldingsPayload? = nil
    var cashBankAccounts: [Account] = []
    @Environment(\.dismiss) private var dismiss
    @State private var expandedIds: Set<String> = []

    private var totalAmount: Double {
        allocation.stocks.amount + allocation.bonds.amount +
        allocation.cash.amount + (allocation.other?.amount ?? 0)
    }

    private var sortedItems: [AllocDetailItem] {
        var items = [
            AllocDetailItem(id: "stocks", title: "U.S. Stocks", percent: allocation.stocks.percent, amount: allocation.stocks.amount, color: AppColors.accentPurple),
            AllocDetailItem(id: "crypto", title: "Crypto",      percent: allocation.bonds.percent,  amount: allocation.bonds.amount,  color: AppColors.warning),
            AllocDetailItem(id: "cash",   title: "Cash",        percent: allocation.cash.percent,   amount: allocation.cash.amount,   color: AppColors.budgetNeedsBlue),
        ]
        if let other = allocation.other, other.percent > 0 {
            items.append(AllocDetailItem(id: "other", title: "Other", percent: other.percent, amount: other.amount, color: AppColors.error))
        }
        return items.sorted { $0.percent > $1.percent }
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        DetailSheetScaffold(title: "Asset Allocation") {
            dismiss()
        } content: {
            donutCard
            breakdownCard
        }
    }

    // MARK: - Donut card

    private var donutCard: some View {
        VStack(spacing: AppSpacing.md) {
            Text("PORTFOLIO")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                AllocDonutChart(items: sortedItems)
                    .frame(width: 200, height: 200)

                VStack(spacing: 2) {
                    Text(formatCompact(totalAmount))
                        .font(.h1)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                    Text("Total portfolio")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
        }
        .padding(AppSpacing.cardPadding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Breakdown card (expandable rows)

    private var breakdownCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BREAKDOWN")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.inkPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            ForEach(Array(sortedItems.enumerated()), id: \.element.id) { idx, item in
                AllocDetailRow(
                    item: item,
                    holdings: InvestmentAllocationBuilder.holdings(for: item.id, payload: holdingsPayload),
                    cashAccounts: item.id == "cash" ? cashBankAccounts : [],
                    isExpanded: expandedIds.contains(item.id)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if expandedIds.contains(item.id) {
                            expandedIds.remove(item.id)
                        } else {
                            expandedIds.insert(item.id)
                        }
                    }
                }

                if idx < sortedItems.count - 1 {
                    Rectangle()
                        .fill(AppColors.inkDivider)
                        .frame(height: 0.5)
                        .padding(.horizontal, AppSpacing.cardPadding)
                }
            }

            Spacer().frame(height: AppSpacing.sm)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.2fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.2fK", value / 1_000) }
        return "$\(Int(value))"
    }
}

// MARK: - Donut Chart

private struct AllocDonutChart: View {
    let items: [AllocDetailItem]

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.inkTrack, lineWidth: 18)
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if item.percent > 0 {
                    AllocDonutSegment(
                        startAngle: startAngle(for: i),
                        endAngle: endAngle(for: i)
                    )
                    .stroke(item.color, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                }
            }
        }
    }

    private func startAngle(for i: Int) -> Angle {
        .degrees(Double(items.prefix(i).map(\.percent).reduce(0, +)) / 100 * 360 - 90)
    }
    private func endAngle(for i: Int) -> Angle {
        .degrees(Double(items.prefix(i + 1).map(\.percent).reduce(0, +)) / 100 * 360 - 90)
    }
}

private struct AllocDonutSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: min(rect.width, rect.height) / 2,
                 startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return p
    }
}

// MARK: - Allocation Row (light-shell, slotted into glass card)

private struct AllocDetailRow: View {
    let item: AllocDetailItem
    let holdings: [Holding]
    let cashAccounts: [Account]
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)

                    Text(item.title)
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkPrimary)

                    Text("· \(item.percent)%")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkFaint)

                    Spacer()

                    Text(formatCurrency(item.amount))
                        .font(.footnoteBold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.inkFaint)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle()
                    .fill(AppColors.inkDivider)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                expandedContent
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    @ViewBuilder
    private var expandedContent: some View {
        if !holdings.isEmpty {
            VStack(spacing: 0) {
                ForEach(holdings.indices, id: \.self) { i in
                    HStack(spacing: AppSpacing.md) {
                        Group {
                            if let urlStr = holdings[i].logoUrl, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                            .frame(width: 36, height: 36)
                                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                    default:
                                        fallbackSymbolIcon(holdings[i].symbol, tint: item.color)
                                    }
                                }
                            } else {
                                fallbackSymbolIcon(holdings[i].symbol, tint: item.color)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holdings[i].name)
                                .font(.footnoteSemibold)
                                .foregroundStyle(AppColors.inkPrimary)
                                .lineLimit(1)
                            Text(holdingSubtitle(holdings[i]))
                                .font(.caption)
                                .foregroundStyle(AppColors.inkFaint)
                        }
                        Spacer()
                        Text(formatCurrency(holdings[i].totalValue))
                            .font(.footnoteBold)
                            .foregroundStyle(AppColors.inkPrimary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm + 2)

                    if i < holdings.count - 1 {
                        Rectangle()
                            .fill(AppColors.inkDivider)
                            .frame(height: 0.5)
                            .padding(.horizontal, AppSpacing.cardPadding)
                    }
                }
            }
            .padding(.bottom, AppSpacing.sm)
        } else if !cashAccounts.isEmpty {
            VStack(spacing: 0) {
                ForEach(cashAccounts.indices, id: \.self) { i in
                    HStack(spacing: AppSpacing.md) {
                        Group {
                            if let urlStr = cashAccounts[i].logoUrl, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                            .frame(width: 36, height: 36)
                                            .clipShape(Circle())
                                    default:
                                        fallbackBankIcon
                                    }
                                }
                            } else {
                                fallbackBankIcon
                            }
                        }
                        Text(cashAccounts[i].institution)
                            .font(.footnoteSemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                        Spacer()
                        Text(formatCurrency(cashAccounts[i].balance))
                            .font(.footnoteBold)
                            .foregroundStyle(AppColors.inkPrimary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm + 2)

                    if i < cashAccounts.count - 1 {
                        Rectangle()
                            .fill(AppColors.inkDivider)
                            .frame(height: 0.5)
                            .padding(.horizontal, AppSpacing.cardPadding)
                    }
                }
            }
            .padding(.bottom, AppSpacing.sm)
        } else {
            Text("Detailed breakdown coming soon")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
        }
    }

    private func fallbackSymbolIcon(_ symbol: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(tint.opacity(0.16))
                .frame(width: 36, height: 36)
            Text(symbol)
                .font(.footnoteBold)
                .foregroundStyle(AppColors.inkPrimary)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
        }
    }

    private var fallbackBankIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.inkTrack)
                .frame(width: 36, height: 36)
            Image(systemName: "building.columns")
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
        }
    }

    private func sharesLabel(_ shares: Double) -> String {
        shares == shares.rounded() ? "\(Int(shares)) shares" : String(format: "%.4f shares", shares)
    }

    private func holdingSubtitle(_ holding: Holding) -> String {
        var parts: [String] = [sharesLabel(holding.shares)]
        if let acctName = holding.accountName, !acctName.isEmpty {
            var acct = acctName
            if let mask = holding.accountMask, !mask.isEmpty {
                acct += "\u{00A0}•\u{00A0}\(mask)"
            }
            parts.append(acct)
        }
        return parts.joined(separator: " · ")
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    AssetAllocationDetailView(allocation: MockData.investmentData.allocation)
}
