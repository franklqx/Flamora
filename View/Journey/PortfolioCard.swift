//
//  PortfolioCard.swift
//  Flamora app
//
//  Robinhood-style investment portfolio card:
//  • Edge-to-edge chart with smooth bezier line + area fill
//  • Long-press 0.3s → haptic → drag to scrub → header updates live
//  • GlassPillSelector to switch time ranges (1W / 1M / 3M / YTD / ALL)
//  • Chart locked until 7 days after account link date
//  • Shared between JourneyView and InvestmentView
//  • isConnected=false → ghost UI + Connect Accounts CTA
//

import SwiftUI
import UIKit

// MARK: - Data Model

struct PortfolioDataPoint {
    let date: Date
    let value: Double
}

// MARK: - Time Range

enum PortfolioTimeRange: CaseIterable, Hashable {
    case oneWeek, oneMonth, threeMonths, ytd, all

    var label: String {
        switch self {
        case .oneWeek:      return "1W"
        case .oneMonth:     return "1M"
        case .threeMonths:  return "3M"
        case .ytd:          return "YTD"
        case .all:          return "ALL"
        }
    }
}

// MARK: - Card

struct PortfolioCard: View {

    // Inputs
    let portfolioBalance: Double
    let gainAmount: Double
    let gainPercentage: Double
    /// First account link date. Defaults to 30 days ago so mock data shows the chart immediately.
    var accountLinkedDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var isConnected: Bool = true
    var onConnectTapped: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    // State
    @State private var selectedRange: PortfolioTimeRange = .oneWeek
    @State private var hoveredIndex: Int? = nil
    @State private var hapticFired   = false

    // MARK: Derived

    private var hasEnoughData: Bool {
        let days = Calendar.current.dateComponents([.day], from: accountLinkedDate, to: Date()).day ?? 0
        return days >= 7
    }

    private var currentData: [PortfolioDataPoint] { mockData(for: selectedRange) }

    private var displayedValue: Double {
        guard let idx = hoveredIndex, idx < currentData.count else { return portfolioBalance }
        return currentData[idx].value
    }

    private var displayedGain: (amount: Double, pct: Double) {
        guard !currentData.isEmpty else { return (gainAmount, gainPercentage) }
        let start = currentData.first!.value
        let end   = hoveredIndex.flatMap { currentData.indices.contains($0) ? currentData[$0].value : nil }
                    ?? currentData.last!.value
        let diff  = end - start
        let pct   = start > 0 ? diff / start * 100 : 0
        return (diff, pct)
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            headerSection
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm + AppSpacing.xs)

            if isConnected {
                if hasEnoughData {
                    chartView
                } else {
                    noDataPlaceholder
                        .frame(height: 120)
                        .padding(.horizontal, AppSpacing.cardPadding)
                }

                GlassPillSelector(
                    items: PortfolioTimeRange.allCases,
                    selected: $selectedRange,
                    label: { $0.label }
                )
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm + AppSpacing.xs + AppSpacing.xs)

            } else {
                ghostChartView

                connectButton
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.cardPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.cardTopHighlight, Color.clear],
                        startPoint: .top, endPoint: .center
                    ),
                    lineWidth: 0.5
                )
                .allowsHitTesting(false)
        )
        .shadow(color: AppColors.cardShadow, radius: AppSpacing.md, x: 0, y: AppSpacing.sm)
        .padding(.horizontal, AppSpacing.screenPadding)
        .onChange(of: selectedRange) { _ in
            hoveredIndex = nil
            hapticFired  = false
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Text("PORTFOLIO")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                if onTap != nil && isConnected {
                    Image(systemName: "chevron.right")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if isConnected { onTap?() } }

            if isConnected {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(formatCurrencyWhole(displayedValue))
                        .font(.portfolioHero)
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                    Text(formatCurrencyCents(displayedValue))
                        .font(.h4)
                        .foregroundColor(AppColors.textTertiary)
                }
                gainBadge
            } else {
                Text("$—")
                    .font(.portfolioHero)
                    .foregroundStyle(AppColors.textTertiary)
                Text("Connect accounts to see your net worth")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: hoveredIndex)
    }

    // MARK: Ghost chart（未连接时，低透明度占位）

    private var ghostChartView: some View {
        GeometryReader { geo in
            chartCanvas(w: geo.size.width, h: geo.size.height)
        }
        .frame(height: 120)
        .clipped()
        .opacity(0.1)
        .allowsHitTesting(false)
    }

    // MARK: Connect button

    private var connectButton: some View {
        Button(action: { onConnectTapped?() }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "link")
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.textInverse)
                Text("Connect Accounts")
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textInverse)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: AppColors.gradientFlamePill,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private var gainBadge: some View {
        let (diff, pct) = displayedGain
        let up = diff >= 0
        return HStack(spacing: AppSpacing.xs) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.cardHeader)
            Text("\(up ? "+" : "")\(formatCurrencyCompact(diff))  (\(String(format: "%.2f", pct))%)")
                .font(.footnoteRegular)
        }
        .foregroundColor(up ? AppColors.successAlt : AppColors.error)
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
        .padding(.vertical, AppSpacing.sm)
        .background((up ? AppColors.successAlt : AppColors.error).opacity(0.14))
        .clipShape(Capsule())
    }

    private var chartView: some View {
        GeometryReader { geo in
            chartCanvas(w: geo.size.width, h: geo.size.height)
        }
        .frame(height: 120)
        .contentShape(Rectangle())
        .clipped()
    }

    @ViewBuilder
    private func chartCanvas(w: CGFloat, h: CGFloat) -> some View {
        let data    = currentData
        let vals    = data.map { $0.value }
        let n       = data.count
        let minV    = (vals.min() ?? 0)
        let maxV    = (vals.max() ?? 1)
        let vRange  = max(maxV - minV, 1.0)
        let steps   = max(n - 1, 1)
        let topPad: CGFloat = 22
        let botPad: CGFloat = AppSpacing.xs
        let useH    = h - topPad - botPad

        let pts: [CGPoint] = vals.enumerated().map { i, v in
            CGPoint(
                x: w * CGFloat(i) / CGFloat(steps),
                y: topPad + useH * (1.0 - CGFloat((v - minV) / vRange))
            )
        }

        ZStack(alignment: .topLeading) {

            if w > 0, h > 0, !pts.isEmpty {
                areaPath(pts, bottomY: h)
                    .fill(LinearGradient(
                        colors: [AppColors.overlayWhiteHigh, AppColors.overlayWhiteWash, Color.clear],
                        startPoint: .top, endPoint: .bottom
                    ))
                linePath(pts)
                    .stroke(AppColors.textPrimary, lineWidth: 1.5)
            }

            if let idx = hoveredIndex, pts.indices.contains(idx) {
                let sx = pts[idx].x
                let sy = pts[idx].y
                let dateLabel = formatDate(data[idx].date)

                Text(dateLabel)
                    .font(.label)
                    .foregroundColor(AppColors.overlayWhiteOnGlass)
                    .fixedSize()
                    .padding(.horizontal, AppSpacing.sm - AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xs / 2)
                    .background(AppColors.overlayWhiteMid)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .position(x: min(max(sx, AppSpacing.xl + AppSpacing.xs), w - AppSpacing.xl - AppSpacing.xs), y: topPad / 2 + AppSpacing.xs)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.1), value: hoveredIndex)

                Path { p in
                    p.move(to: CGPoint(x: sx, y: topPad))
                    p.addLine(to: CGPoint(x: sx, y: h))
                }
                .stroke(AppColors.overlayWhiteEmphasisStroke,
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                Circle()
                    .fill(AppColors.overlayWhiteHigh)
                    .frame(width: 22, height: 22)
                    .position(x: sx, y: sy)

                Circle()
                    .fill(AppColors.textPrimary)
                    .frame(width: 9, height: 9)
                    .position(x: sx, y: sy)
            }

            if isConnected {
                ChartInteractionLayer(
                    onDrag: { x, chartWidth in
                        guard chartWidth > 0, n > 1 else { return }
                        if !hapticFired {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            hapticFired = true
                        }
                        let fraction = max(0, min(x / chartWidth, 1.0))
                        hoveredIndex = min(
                            Int((fraction * CGFloat(n - 1)).rounded()),
                            n - 1
                        )
                    },
                    onRelease: {
                        withAnimation(.easeOut(duration: 0.25)) { hoveredIndex = nil }
                        hapticFired = false
                    }
                )
                .frame(width: w, height: h)
            }
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        guard pts.count > 1 else { return Path() }
        var path = Path()
        path.move(to: pts[0])

        for i in 1..<pts.count {
            let prev = i > 1 ? pts[i - 2] : pts[i - 1]
            let curr = pts[i - 1]
            let next = pts[i]
            let next2 = i < pts.count - 1 ? pts[i + 1] : pts[i]

            let cp1 = CGPoint(
                x: curr.x + (next.x - prev.x) / 6,
                y: curr.y + (next.y - prev.y) / 6
            )
            let cp2 = CGPoint(
                x: next.x - (next2.x - curr.x) / 6,
                y: next.y - (next2.y - curr.y) / 6
            )
            path.addCurve(to: next, control1: cp1, control2: cp2)
        }
        return path
    }

    private func areaPath(_ pts: [CGPoint], bottomY: CGFloat) -> Path {
        var path = linePath(pts)
        path.addLine(to: CGPoint(x: pts.last!.x, y: bottomY))
        path.addLine(to: CGPoint(x: pts.first!.x, y: bottomY))
        path.closeSubpath()
        return path
    }

    private var noDataPlaceholder: some View {
        VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.navChevron)
                .foregroundColor(AppColors.textTertiary.opacity(0.5))
            Text("Chart available after 7 days")
                .font(.footnoteRegular)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Mock data (investment portfolio values)

    private func mockData(for range: PortfolioTimeRange) -> [PortfolioDataPoint] {
        let cal = Calendar.current
        let now = Date()

        switch range {

        case .oneWeek:
            let vals = [82400.0, 83100.0, 84200.0, 83800.0, 84900.0, 85100.0, 85240.0]
            return vals.enumerated().map { i, v in
                .init(date: cal.date(byAdding: .day, value: -(6 - i), to: now) ?? now, value: v)
            }

        case .oneMonth:
            let vals: [Double] = [
                76000, 77200, 75800, 78000, 79500, 80800, 80200,
                81400, 82100, 81500, 82800, 83600, 82900, 83800,
                84200, 83700, 84500, 84800, 84300, 85000,
                84900, 85100, 85200, 84800, 85000, 85100,
                84900, 85100, 85200, 85240
            ]
            return vals.enumerated().map { i, v in
                .init(date: cal.date(byAdding: .day, value: -(29 - i), to: now) ?? now, value: v)
            }

        case .threeMonths:
            let vals = [72000.0, 74500.0, 71000.0, 76000.0, 78000.0, 79500.0, 78200.0,
                        80500.0, 79000.0, 82000.0, 83200.0, 84100.0, 83500.0, 84800.0, 85240.0]
            return vals.enumerated().map { i, v in
                let back = vals.count - 1 - i
                return .init(date: cal.date(byAdding: .weekOfYear, value: -back, to: now) ?? now, value: v)
            }

        case .ytd:
            let year = cal.component(.year, from: now)
            var dc = DateComponents(); dc.year = year; dc.month = 1; dc.day = 1
            let jan1  = cal.date(from: dc) ?? now
            let months = max((cal.dateComponents([.month], from: jan1, to: now).month ?? 0) + 1, 2)
            let allVals = [64000.0, 67000.0, 70000.0, 74000.0, 77000.0, 79000.0,
                           80500.0, 81800.0, 82900.0, 83800.0, 84600.0, 85240.0]
            return Array(allVals.prefix(months)).enumerated().map { i, v in
                .init(date: cal.date(byAdding: .month, value: i, to: jan1) ?? now, value: v)
            }

        case .all:
            let vals = [10000.0, 18000.0, 28000.0, 38000.0, 48000.0, 56000.0,
                        63000.0, 70000.0, 75000.0, 79000.0, 82500.0, 85240.0]
            return vals.enumerated().map { i, v in
                let back = vals.count - 1 - i
                return .init(date: cal.date(byAdding: .month, value: -back, to: now) ?? now, value: v)
            }
        }
    }

    // MARK: Formatters

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        switch selectedRange {
        case .oneWeek, .oneMonth, .threeMonths:
            f.dateFormat = "MMM d, yyyy"
        case .ytd, .all:
            f.dateFormat = "MMM yyyy"
        }
        return f.string(from: date)
    }

    private func formatCurrencyWhole(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle   = .currency
        f.currencyCode  = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }

    private func formatCurrencyCents(_ v: Double) -> String {
        let cents = Int(abs(v.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: ".%02d", cents)
    }

    private func formatCurrencyCompact(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle   = .currency
        f.currencyCode  = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: abs(v))) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        ScrollView {
            VStack(spacing: AppSpacing.cardPadding) {
                PortfolioCard(
                    portfolioBalance: 85240.0,
                    gainAmount: 3240.0,
                    gainPercentage: 3.95,
                    isConnected: true
                )
                PortfolioCard(
                    portfolioBalance: 0,
                    gainAmount: 0,
                    gainPercentage: 0,
                    isConnected: false,
                    onConnectTapped: {}
                )
            }
            .padding(.top, AppSpacing.lg)
        }
    }
}
