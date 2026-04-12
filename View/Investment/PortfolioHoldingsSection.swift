//
//  PortfolioHoldingsSection.swift
//  Flamora app
//
//  Investment 页下拉区：按日历卡片风格展示持仓列表
//  颜色 / 卡片样式参考 CashFlow 的 SavingsTargetDetailView2 monthCard 设计
//

import SwiftUI

// MARK: - Section

struct PortfolioHoldingsSection: View {
    let holdings: [APIInvestmentHoldingRow]
    let isConnected: Bool

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.cardGap),
        GridItem(.flexible(), spacing: AppSpacing.cardGap)
    ]

    private var sortedHoldings: [APIInvestmentHoldingRow] {
        holdings.sorted { ($0.value ?? 0) > ($1.value ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader

            if !isConnected {
                disconnectedContent
            } else if sortedHoldings.isEmpty {
                emptyContent
            } else {
                LazyVGrid(columns: columns, spacing: AppSpacing.cardGap) {
                    ForEach(sortedHoldings, id: \.id) { holding in
                        HoldingCell(holding: holding)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
        }
    }

    // MARK: Header

    private var sectionHeader: some View {
        HStack {
            Text("HOLDINGS")
                .font(.smallLabel)
                .foregroundColor(AppColors.textTertiary)
                .tracking(AppTypography.Tracking.cardHeader)

            Spacer()

            if isConnected && !holdings.isEmpty {
                Text("\(holdings.count) positions")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: Empty / Disconnected

    private var disconnectedContent: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "lock.fill")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textTertiary.opacity(0.45))
            Text("Connect accounts to see your holdings")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.vertical, AppSpacing.md)
    }

    private var emptyContent: some View {
        Text("No holdings found")
            .font(.footnoteRegular)
            .foregroundStyle(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.vertical, AppSpacing.md)
    }
}

// MARK: - Holding Cell

/// 单个持仓卡片，风格与 SavingsTargetDetailView2 中的 monthCard 保持一致：
/// surface 底色 · cardBorder 描边 · AppRadius.card 圆角 · 火焰渐变 / 绿色 / 红色增益标签
private struct HoldingCell: View {
    let holding: APIInvestmentHoldingRow

    private var gainLossPct: Double? { holding.gainLossPct }
    private var isPositive: Bool { (holding.gainLoss ?? 0) >= 0 }
    private var hasGainData: Bool { holding.gainLoss != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
            // Row 1: ticker · gain%
            HStack(alignment: .top) {
                Text(tickerLabel)
                    .font(.smallLabel)
                    .foregroundColor(hasGainData ? AppColors.textSecondary : AppColors.textTertiary)

                Spacer()

                if let pct = gainLossPct {
                    gainBadge(pct: pct)
                }
            }

            // Row 2: current value
            Text(formatCurrency(holding.value ?? 0))
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)

            // Row 3: name (truncated)
            Text(holding.name)
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(
                    hasGainData ? AppColors.surfaceBorder : AppColors.surfaceBorder.opacity(0.5),
                    lineWidth: 1
                )
        )
        .opacity(hasGainData ? 1.0 : 0.75)
    }

    // MARK: Helpers

    private var tickerLabel: String {
        if let t = holding.ticker, !t.isEmpty { return t.uppercased() }
        if let ty = holding.type, !ty.isEmpty { return ty.uppercased() }
        return "—"
    }

    @ViewBuilder
    private func gainBadge(pct: Double) -> some View {
        let isUp = pct >= 0
        let sign = isUp ? "+" : ""
        let label = "\(sign)\(String(format: "%.1f", pct))%"

        if isUp && pct >= 5 {
            // 大幅正收益：火焰渐变（对齐 SavingsTargetDetailView2 flameBadge 风格）
            Text(label)
                .font(.cardHeader)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accentPurple, AppColors.accentPink, AppColors.accentAmber],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            // 普通正收益：绿色；负收益：红色
            Text(label)
                .font(.cardHeader)
                .foregroundStyle(isUp ? AppColors.accentGreen : AppColors.error)
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

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                PortfolioHoldingsSection(
                    holdings: [
                        APIInvestmentHoldingRow(id: "1", plaidAccountId: nil, name: "Vanguard Total Stock Market ETF", ticker: "VTI", type: "etf", quantity: 40, price: 240.5, value: 9620, costBasis: 8000, gainLoss: 1620, gainLossPct: 20.25, accountName: "Roth IRA", accountMask: "4431"),
                        APIInvestmentHoldingRow(id: "2", plaidAccountId: nil, name: "Apple Inc.", ticker: "AAPL", type: "equity", quantity: 25, price: 178.2, value: 4455, costBasis: 4000, gainLoss: 455, gainLossPct: 11.38, accountName: "Taxable", accountMask: "7892"),
                        APIInvestmentHoldingRow(id: "3", plaidAccountId: nil, name: "iShares Core S&P 500 ETF", ticker: "IVV", type: "etf", quantity: 10, price: 510.0, value: 5100, costBasis: 4800, gainLoss: 300, gainLossPct: 6.25, accountName: "Roth IRA", accountMask: "4431"),
                        APIInvestmentHoldingRow(id: "4", plaidAccountId: nil, name: "Tesla Inc.", ticker: "TSLA", type: "equity", quantity: 15, price: 250.0, value: 3750, costBasis: 4200, gainLoss: -450, gainLossPct: -10.71, accountName: "Taxable", accountMask: "7892"),
                        APIInvestmentHoldingRow(id: "5", plaidAccountId: nil, name: "Cash & Money Market", ticker: nil, type: "cash", quantity: nil, price: nil, value: 3200, costBasis: nil, gainLoss: nil, gainLossPct: nil, accountName: "Roth IRA", accountMask: "4431"),
                    ],
                    isConnected: true
                )
                .padding(.top, AppSpacing.lg)
            }
        }
    }
    .preferredColorScheme(.dark)
}
