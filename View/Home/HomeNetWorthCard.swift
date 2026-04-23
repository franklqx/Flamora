//
//  HomeNetWorthCard.swift
//  Flamora app
//
//  Home Tab — 净资产卡片。
//  已连接态：当前金额 + 趋势图（1W / 1M / 3M / 1Y / ALL）。
//  未连接态：模糊金额 + "Connect to unlock" overlay。
//
//  数据：`APINetWorthSummary`（已有 snapshot）+ 趋势图 mock 数据（待后端 `getNetWorthHistory` endpoint 接入）。
//

import SwiftUI
import Charts

// MARK: - Range

enum NetWorthRange: String, CaseIterable, Identifiable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "ALL"

    var id: String { rawValue }
    var label: String { rawValue }

    /// 本期 sample 点数（mock 数据用，后端接入后按实际返回）。
    var sampleCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 12   // 按周
        case .year: return 12          // 按月
        case .all: return 24           // 按月（2 年）
        }
    }
}

// MARK: - Data

struct NetWorthPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Card

struct HomeNetWorthCard: View {
    let summary: APINetWorthSummary?
    let history: [NetWorthRange: [NetWorthPoint]]
    var isConnected: Bool = true
    var onCardTap: (() -> Void)? = nil

    @State private var selectedRange: NetWorthRange = .month
    private var totalValue: Double { summary?.totalNetWorth ?? 0 }
    private var growthAmount: Double? { summary?.growthAmount }
    private var growthPercent: Double? { summary?.growthPercentage }

    private var currentPoints: [NetWorthPoint] {
        history[selectedRange] ?? []
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if isConnected {
                connectedState
            } else {
                lockedState
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isConnected { onCardTap?() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("NET WORTH")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            Spacer()

            if isConnected {
                Image(systemName: "chevron.right")
                    .font(.miniLabel)
                    .foregroundColor(AppColors.inkFaint)
                    .padding(.leading, AppSpacing.xs)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
    }

    // MARK: - Connected state

    private var connectedState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            amountBlock
            chartBlock
            rangeSelector
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.lg)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(formatCurrency(totalValue))
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()

            if let amt = growthAmount, let pct = growthPercent {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: amt >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.miniLabel)
                        .foregroundColor(amt >= 0 ? AppColors.success : AppColors.error)

                    Text("\(formatCurrency(abs(amt))) (\(formatPercent(pct)))")
                        .font(.footnoteRegular)
                        .foregroundColor(amt >= 0 ? AppColors.success : AppColors.error)
                        .monospacedDigit()

                    Text("this month")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.inkFaint)
                }
            } else {
                Text("No prior data to compare yet")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.inkFaint)
            }
        }
    }

    // MARK: - Chart

    private var chartBlock: some View {
        Group {
            if currentPoints.count >= 2 {
                Chart {
                    ForEach(currentPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(AppColors.inkPrimary)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AppColors.inkPrimary.opacity(0.16),
                                    AppColors.inkPrimary.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 128)
            } else {
                // 数据不足时占位
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(AppColors.inkTrack.opacity(0.5))
                    .frame(height: 128)
                    .overlay(
                        Text("Not enough history yet")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.inkFaint)
                    )
            }
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(NetWorthRange.allCases) { range in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.label)
                        .font(.segmentLabel(selected: selectedRange == range))
                        .foregroundColor(selectedRange == range ? AppColors.inkPrimary : AppColors.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedRange == range ? AppColors.ctaWhite.opacity(0.85) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppColors.inkTrack.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Locked state

    private var lockedState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(formatCurrency(123_456))      // placeholder
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkFaint)
                .redacted(reason: .placeholder)

            Text("Connect accounts to see your real net worth and trend.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(AppColors.inkTrack)
                .frame(height: 84)
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.inkFaint)
                )
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.lg)
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        let sign = value < 0 ? "-" : ""
        let formatted = f.string(from: NSNumber(value: abs(value))) ?? "$0"
        return sign + formatted
    }

    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()

        HomeNetWorthCard(
            summary: APINetWorthSummary(
                totalNetWorth: 248_360,
                previousNetWorth: 241_000,
                growthAmount: 7_360,
                growthPercentage: 3.05,
                asOfDate: "2026-04-20",
                breakdown: APINetWorthSummary.NetWorthBreakdown(
                    investmentTotal: 182_000,
                    depositoryTotal: 78_500,
                    creditTotal: 2_400,
                    loanTotal: 9_740
                ),
                accounts: [],
                lastSyncedAt: "2026-04-20T08:30:00Z"
            ),
            history: HomeNetWorthCard.mockHistory(),
            isConnected: true
        )
        .padding()
    }
}

// MARK: - Mock (开发期占位，接 API 后可删)

extension HomeNetWorthCard {
    static func mockHistory() -> [NetWorthRange: [NetWorthPoint]] {
        let now = Date()
        let cal = Calendar.current

        func series(count: Int, step: Calendar.Component, stepValue: Int, base: Double, delta: Double) -> [NetWorthPoint] {
            (0..<count).compactMap { i in
                guard let d = cal.date(byAdding: step, value: -stepValue * (count - 1 - i), to: now) else { return nil }
                let noise = Double.random(in: -0.01...0.01)
                let progress = Double(i) / Double(max(count - 1, 1))
                return NetWorthPoint(date: d, value: base + delta * progress * (1 + noise))
            }
        }

        return [
            .week: series(count: 7, step: .day, stepValue: 1, base: 240_000, delta: 8_000),
            .month: series(count: 30, step: .day, stepValue: 1, base: 232_000, delta: 16_000),
            .threeMonths: series(count: 12, step: .weekOfYear, stepValue: 1, base: 215_000, delta: 33_000),
            .year: series(count: 12, step: .month, stepValue: 1, base: 180_000, delta: 68_000),
            .all: series(count: 24, step: .month, stepValue: 1, base: 120_000, delta: 128_000)
        ]
    }
}
