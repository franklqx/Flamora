//
//  AssetAllocationDetailView.swift
//  Flamora app
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
    @State private var dragOffset: CGFloat = 0
    @State private var expandedIds: Set<String> = []

    private var totalAmount: Double {
        allocation.stocks.amount + allocation.bonds.amount +
        allocation.cash.amount + (allocation.other?.amount ?? 0)
    }

    private var sortedItems: [AllocDetailItem] {
        var items = [
            AllocDetailItem(id: "stocks",       title: "U.S. Stocks", percent: allocation.stocks.percent, amount: allocation.stocks.amount, color: AppColors.chartSteelBlue),
            AllocDetailItem(id: "crypto",       title: "Crypto",      percent: allocation.bonds.percent,  amount: allocation.bonds.amount,  color: AppColors.chartYellow),
            AllocDetailItem(id: "cash",         title: "Cash",        percent: allocation.cash.percent,   amount: allocation.cash.amount,   color: AppColors.chartSageGreen),
        ]
        if let other = allocation.other, other.percent > 0 {
            items.append(AllocDetailItem(id: "other", title: "Other", percent: other.percent, amount: other.amount, color: AppColors.chartCoral))
        }
        return items.sorted { $0.percent > $1.percent }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Asset Allocation")
                        .font(.h2)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.bodySmallSemibold)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        donutSection

                        VStack(spacing: AppSpacing.cardGap) {
                            ForEach(sortedItems) { item in
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
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .offset(y: dragOffset)
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { if $0.translation.height > 0 { dragOffset = $0.translation.height } }
                .onEnded {
                    if $0.translation.height > 150 { dismiss() }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 } }
                }
        )
        .preferredColorScheme(.dark)
    }

    // MARK: - Donut

    private var donutSection: some View {
        ZStack {
            AllocDonutChart(items: sortedItems)
                .frame(width: 200, height: 200)

            VStack(spacing: AppSpacing.xs) {
                Text(formatCompact(totalAmount))
                    .font(.h1)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Portfolio")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.top, AppSpacing.lg)
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
            Circle().stroke(AppColors.surfaceInput, lineWidth: 18)
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if item.percent > 0 {
                    AllocDonutSegment(
                        startAngle: startAngle(for: i),
                        endAngle: endAngle(for: i)
                    )
                    .stroke(item.color, lineWidth: 18)
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

// MARK: - Allocation Row

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
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("• \(item.percent)%")
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textTertiary)

                    Spacer()

                    Text(formatCurrency(item.amount))
                        .font(.cardFigureSecondary)
                        .foregroundStyle(AppColors.textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle()
                    .fill(AppColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                expandedContent
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
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
                                        fallbackSymbolIcon(holdings[i].symbol)
                                    }
                                }
                            } else {
                                fallbackSymbolIcon(holdings[i].symbol)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(holdings[i].name)
                                .font(.bodySmall)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                            Text(holdingSubtitle(holdings[i]))
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                        Text(formatCurrency(holdings[i].totalValue))
                            .font(.inlineFigureBold)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)

                    if i < holdings.count - 1 {
                        Rectangle()
                            .fill(AppColors.surfaceBorder)
                            .frame(height: 0.5)
                            .padding(.horizontal, AppSpacing.cardPadding)
                    }
                }
                .padding(.bottom, AppSpacing.sm)
            }
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
                            .font(.bodySmall)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(formatCurrency(cashAccounts[i].balance))
                            .font(.inlineFigureBold)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.vertical, AppSpacing.sm)

                    if i < cashAccounts.count - 1 {
                        Rectangle()
                            .fill(AppColors.surfaceBorder)
                            .frame(height: 0.5)
                            .padding(.horizontal, AppSpacing.cardPadding)
                    }
                }
                .padding(.bottom, AppSpacing.sm)
            }
        } else {
            Text("Detailed breakdown coming soon")
                .font(.footnoteRegular)
                .foregroundColor(AppColors.textTertiary)
                .padding(AppSpacing.cardPadding)
        }
    }

    private func fallbackSymbolIcon(_ symbol: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.chartAmber)
                .frame(width: 36, height: 36)
            Text(symbol)
                .font(.footnoteBold)
                .foregroundStyle(AppColors.textPrimary)
                .minimumScaleFactor(0.6)
        }
    }

    private var fallbackBankIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.surfaceElevated)
                .frame(width: 36, height: 36)
            Image(systemName: "building.columns")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private func sharesLabel(_ shares: Double) -> String {
        shares == shares.rounded() ? "\(Int(shares)) shares" : String(format: "%.4f shares", shares)
    }

    /// Combines shares count with account attribution when available.
    /// e.g. "12 shares · Chase • 7892" or just "12 shares"
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
