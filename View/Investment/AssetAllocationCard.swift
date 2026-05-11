//
//  AssetAllocationCard.swift
//  Flamora app
//

import SwiftUI

struct AssetAllocationCard: View {
    let allocation: Allocation
    var isConnected: Bool = true
    var holdingsPayload: APIInvestmentHoldingsPayload? = nil
    var cashBankAccounts: [Account] = []
    @State private var showDetail = false

    private var totalAmount: Double {
        [
            allocation.stocks.amount,
            allocation.funds.amount,
            allocation.bonds.amount,
            allocation.cash.amount,
            allocation.crypto.amount,
            allocation.other.amount
        ].reduce(0, +)
    }

    private struct AllocRow {
        let title: String
        let percent: Int
        let amount: Double
        let color: Color
    }

    /// Only includes asset classes the user actually holds. A row with $0 / 0%
    /// is misleading (looks like an unloaded slot), so we omit it entirely.
    private var sortedRows: [AllocRow] {
        var rows: [AllocRow] = []
        if allocation.stocks.amount > 0.005 {
            rows.append(AllocRow(title: "Equity", percent: allocation.stocks.percent, amount: allocation.stocks.amount, color: AppColors.assetEquity))
        }
        if allocation.funds.amount > 0.005 {
            rows.append(AllocRow(title: "ETFs & Funds", percent: allocation.funds.percent, amount: allocation.funds.amount, color: AppColors.assetFunds))
        }
        if allocation.bonds.amount > 0.005 {
            rows.append(AllocRow(title: "Bonds", percent: allocation.bonds.percent, amount: allocation.bonds.amount, color: AppColors.assetBonds))
        }
        if allocation.cash.amount > 0.005 {
            rows.append(AllocRow(title: "Cash", percent: allocation.cash.percent, amount: allocation.cash.amount, color: AppColors.assetCash))
        }
        if allocation.crypto.amount > 0.005 {
            rows.append(AllocRow(title: "Crypto", percent: allocation.crypto.percent, amount: allocation.crypto.amount, color: AppColors.assetCrypto))
        }
        if allocation.other.amount > 0.005 {
            rows.append(AllocRow(title: "Other", percent: allocation.other.percent, amount: allocation.other.amount, color: AppColors.assetOther))
        }
        return rows.sorted { $0.percent > $1.percent }
    }

    private var allocationSegments: [ChartSegment] {
        sortedRows.map { ChartSegment(percent: $0.percent, color: $0.color) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header（仅 title，无 chevron；点击区已上移到整张卡片）
            HStack {
                Text("ASSET ALLOCATION")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.inkPrimary)
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
                // Chart + breakdown
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        DonutChart(segments: allocationSegments)
                            .frame(width: 140, height: 140)

                        VStack(spacing: 1) {
                            Text("TOTAL")
                                .font(.miniLabel)
                                .foregroundColor(AppColors.inkMeta)
                                .tracking(AppTypography.Tracking.miniUppercase)
                            Text(formatCompact(totalAmount))
                                .font(.bodySemibold)
                                .foregroundStyle(AppColors.inkPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedRows.indices, id: \.self) { i in
                            AllocationRow(
                                title: sortedRows[i].title,
                                percent: sortedRows[i].percent,
                                amount: sortedRows[i].amount,
                                color: sortedRows[i].color
                            )
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.vertical, AppSpacing.cardPadding)
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
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .onTapGesture { if isConnected { showDetail = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Asset allocation")
        .accessibilityHint(isConnected ? "View full allocation breakdown" : "Connect accounts to unlock")
        .fullScreenCover(isPresented: $showDetail) {
            AssetAllocationDetailView(
                allocation: allocation,
                holdingsPayload: holdingsPayload,
                cashBankAccounts: cashBankAccounts
            )
        }
    }

    private var disconnectedContent: some View {
        HStack(spacing: AppSpacing.md) {
            // Ghost donut
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 14)
                    .frame(width: 140, height: 140)

                VStack(spacing: 1) {
                    Text("TOTAL")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.inkMeta)
                        .tracking(AppTypography.Tracking.miniUppercase)
                    Text("$—")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }

            // Ghost rows (locked placeholder)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(["Equity", "ETFs & Funds", "Cash"], id: \.self) { label in
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkMeta)
                        Circle()
                            .fill(AppColors.inkMeta)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.footnoteSemibold)
                                .foregroundStyle(AppColors.inkSoft)
                            Text("—% · $—")
                                .font(.cardRowMeta)
                                .foregroundColor(AppColors.inkMeta)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.cardPadding)
    }

    /// Same compact formatter as `AssetAllocationDetailView`, so the L1 card
    /// and the L2 detail show the same headline amount (e.g. `$70.50K`).
    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.2fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "$%.2fK", value / 1_000) }
        return "$\(Int(value))"
    }
}

private struct AllocationRow: View {
    let title: String
    let percent: Int
    let amount: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("\(percent)% · \(formatCurrency(amount))")
                    .font(.cardRowMeta)
                    .foregroundColor(AppColors.inkMeta)
            }
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$0.00"
    }
}

/// Donut with visible gaps and rounded caps between segments,
/// matching the style used by the Cashflow Budget ring.
private struct DonutChart: View {
    let segments: [ChartSegment]
    var lineWidth: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(positionedSegments(diameter: diameter)) { seg in
                    DonutArcShape(
                        startDegrees: seg.start,
                        endDegrees: seg.end,
                        lineWidth: lineWidth
                    )
                    .stroke(seg.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
        }
    }

    private struct PositionedSegment: Identifiable {
        let id = UUID()
        let start: Double
        let end: Double
        let color: Color
    }

    private func positionedSegments(diameter: CGFloat) -> [PositionedSegment] {
        let visible = segments.filter { $0.percent > 0 }
        guard !visible.isEmpty else { return [] }
        let total = visible.map(\.percent).reduce(0, +)
        guard total > 0 else { return [] }

        let radius = max((diameter - lineWidth) / 2, 1)
        let capExtension = Double((lineWidth / 2) / radius) * 180 / .pi
        let visibleGap = 3.5
        let gap = visible.count > 1 ? visibleGap + capExtension * 2 : 0
        let available = max(360.0 - gap * Double(visible.count), 0)

        var cursor = -90.0
        return visible.compactMap { seg in
            let sweep = Double(seg.percent) / Double(total) * available
            guard sweep > 0.5 else { return nil }
            let start = cursor
            let end = cursor + sweep
            cursor = end + gap
            return PositionedSegment(start: start, end: end, color: seg.color)
        }
    }
}

private struct DonutArcShape: Shape {
    let startDegrees: Double
    let endDegrees: Double
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = max((min(rect.width, rect.height) - lineWidth) / 2, 0)
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        return p
    }
}

private struct ChartSegment { let percent: Int; let color: Color }

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        AssetAllocationCard(allocation: MockData.investmentData.allocation).padding()
    }
}
