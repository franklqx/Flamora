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
        allocation.stocks.amount + allocation.bonds.amount + allocation.cash.amount + (allocation.other?.amount ?? 0)
    }

    private struct AllocRow {
        let id: String
        let title: String
        let percent: Int
        let amount: Double
        let color: Color
    }

    private var sortedRows: [AllocRow] {
        var rows = [
            AllocRow(id: "stocks", title: "U.S. Stocks", percent: allocation.stocks.percent, amount: allocation.stocks.amount, color: AppColors.chartSteelBlue),
            AllocRow(id: "crypto", title: "Crypto", percent: allocation.bonds.percent, amount: allocation.bonds.amount, color: AppColors.chartYellow),
            AllocRow(id: "cash", title: "Cash", percent: allocation.cash.percent, amount: allocation.cash.amount, color: AppColors.chartSageGreen)
        ]
        if let other = allocation.other, other.percent > 0 {
            rows.append(AllocRow(id: "other", title: "Other", percent: other.percent, amount: other.amount, color: AppColors.chartCoral))
        }
        let filtered = rows.filter { row in
            row.amount > 0 || row.percent > 0
        }
        return (filtered.isEmpty ? rows : filtered).sorted { $0.amount > $1.amount }
    }

    private var allocationSegments: [ChartSegment] {
        sortedRows.map { ChartSegment(percent: $0.percent, color: $0.color) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ASSET ALLOCATION")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.inkFaint)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
                if isConnected {
                    Image(systemName: "chevron.right")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.inkFaint)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isConnected {
                HStack(alignment: .top, spacing: 20) {
                    ZStack {
                        DonutChart(segments: allocationSegments)
                            .frame(width: 110, height: 110)
                            .contentShape(Circle())
                            .onTapGesture {
                                guard isConnected else { return }
                                showDetail = true
                            }

                        VStack(spacing: 1) {
                            Text("TOTAL")
                                .font(.miniLabel)
                                .foregroundColor(AppColors.inkMeta)
                                .tracking(AppTypography.Tracking.miniUppercase)
                            Text(formatCompact(totalAmount))
                                .font(.inlineFigureBold)
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
        .fullScreenCover(isPresented: $showDetail) {
            AssetAllocationDetailView(
                allocation: allocation,
                holdingsPayload: holdingsPayload,
                cashBankAccounts: cashBankAccounts
            )
        }
    }

    private var disconnectedContent: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(AppColors.inkTrack, lineWidth: 14)
                    .frame(width: 110, height: 110)
                    .opacity(0.35)

                VStack(spacing: 1) {
                    Text("TOTAL")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.inkMeta)
                        .tracking(AppTypography.Tracking.miniUppercase)
                    Text("$—")
                        .font(.inlineFigureBold)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(["U.S. Stocks", "Crypto", "Cash"], id: \.self) { label in
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint.opacity(0.7))
                        Circle()
                            .fill(AppColors.inkFaint.opacity(0.25))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.footnoteSemibold)
                                .foregroundStyle(AppColors.inkPrimary)
                            Text("—% · $—")
                                .font(.cardRowMeta)
                                .foregroundColor(AppColors.inkSoft)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.cardPadding)
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.0fk", value / 1_000)
        }
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
                    .foregroundColor(AppColors.inkSoft)
            }
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }
}

private struct DonutChart: View {
    let segments: [ChartSegment]
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.inkTrack, lineWidth: 14)

            ForEach(segments.indices, id: \.self) { i in
                if segments[i].percent > 0 {
                    DonutSegmentShape(startAngle: startAngle(for: i), endAngle: endAngle(for: i))
                        .stroke(segments[i].color, lineWidth: 14)
                }
            }
        }
    }
    private func startAngle(for i: Int) -> Angle {
        .degrees(Double(segments.prefix(i).map(\.percent).reduce(0, +)) / 100 * 360 - 90)
    }
    private func endAngle(for i: Int) -> Angle {
        .degrees(Double(segments.prefix(i + 1).map(\.percent).reduce(0, +)) / 100 * 360 - 90)
    }
}

private struct DonutSegmentShape: Shape {
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

private struct ChartSegment { let percent: Int; let color: Color }

#Preview {
    ZStack {
        LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        AssetAllocationCard(allocation: MockData.investmentData.allocation).padding()
    }
}
