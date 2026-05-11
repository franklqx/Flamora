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

    /// 与 `get-net-worth-history` Edge Function 接受的 `range` 查询参数对齐。
    var apiQueryValue: String {
        switch self {
        case .week:        return "1w"
        case .month:       return "1m"
        case .threeMonths: return "3m"
        case .year:        return "1y"
        case .all:         return "all"
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Net worth")
        .accessibilityValue(netWorthAccessibilityValue)
    }

    private var netWorthAccessibilityValue: String {
        let amount = formatCurrency(totalValue)
        guard let amt = growthAmount, let pct = growthPercent else {
            return "\(amount). No prior data to compare yet."
        }
        let direction = amt >= 0 ? "up" : "down"
        return "\(amount), \(direction) \(formatCurrency(abs(amt))) or \(formatPercent(pct)) this month"
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
                        .foregroundStyle(
                            LinearGradient(
                                colors: AppColors.gradientShellAccent,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#60A5FA").opacity(0.30),
                                    Color(hex: "#818CF8").opacity(0.08),
                                    Color(hex: "#818CF8").opacity(0.0)
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
                NetWorthEmptyHistoryView(chartHeight: 128)
            }
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: AppSpacing.xs) {
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
                                .fill(selectedRange == range ? AppColors.inkTrack : .clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(range.label)
                .accessibilityValue(selectedRange == range ? "Selected" : "")
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
                .accessibilityHint("Show net worth over \(range.label)")
            }
        }
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
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        let sign = value < 0 ? "-" : ""
        let formatted = f.string(from: NSNumber(value: abs(value))) ?? "$0.00"
        return sign + formatted
    }

    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value))%"
    }
}

// MARK: - Empty history state (shared by Home card + Detail view)

/// 没有历史数据时的占位图：一条**水平的蓝色实线**（"今天的状态"基线），
/// 下方带渐变阴影。线本身平直，表示"还没有变化记录"；待有数据后才会起伏。
struct NetWorthEmptyHistoryView: View {
    let chartHeight: CGFloat
    var caption: String = "Tracking starts today"

    /// 基线在卡片中部偏下（y=0.5）。两端不留 padding，撑满 chart 宽度。
    private static let baselineY: CGFloat = 0.5

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            GeometryReader { geo in
                let lineY = (1 - Self.baselineY) * geo.size.height
                let leftEdge = CGPoint(x: 0, y: lineY)
                let rightEdge = CGPoint(x: geo.size.width, y: lineY)

                ZStack {
                    // 基线下方的填充阴影（蓝紫 → 透明），表达"目前的水位"。
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        path.addLine(to: leftEdge)
                        path.addLine(to: rightEdge)
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#60A5FA").opacity(0.32),
                                Color(hex: "#818CF8").opacity(0.10),
                                Color(hex: "#818CF8").opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // 主线：水平实线，蓝色渐变 + 下方柔光阴影。
                    Path { path in
                        path.move(to: leftEdge)
                        path.addLine(to: rightEdge)
                    }
                    .stroke(
                        LinearGradient(
                            colors: AppColors.gradientShellAccent,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .shadow(color: Color(hex: "#60A5FA").opacity(0.45), radius: 6, x: 0, y: 4)
                }
            }
            .frame(height: chartHeight)

            Text(caption)
                .font(.footnoteRegular)
                .foregroundColor(AppColors.inkFaint)
        }
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
                startingPortfolioBalance: 182_000,
                startingPortfolioSource: "plaid_investment",
                lastSyncedAt: "2026-04-20T08:30:00Z"
            ),
            history: [:],
            isConnected: true
        )
        .padding()
    }
}
