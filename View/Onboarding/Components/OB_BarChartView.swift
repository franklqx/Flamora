//
//  OB_BarChartView.swift
//  Meridian
//
//  Onboarding - Bar chart with stagger animation, scrubber, dual mode
//  V3 — matches HTML prototype (roadmap-v3-prototype.html)
//

import SwiftUI
import UIKit

struct OB_BarChartView: View {
    let startAge: Int
    let currentEndAge: Int
    let optimizedEndAge: Int
    let startingNetWorth: Double
    let monthlySavings: Double
    let optimizedMonthlySavings: Double
    let currencySymbol: String
    let annualReturn: Double = 0.09

    // Animation triggers (parent sets these)
    var showCurrentBars: Bool = false
    var showOptimizedBars: Bool = false

    // Per-bar animation progress (0 → 1)
    @State private var currentBarProgress: [CGFloat] = []
    @State private var optimizedBarProgress: [CGFloat] = []
    @State private var isDualLayout = false
    @State private var useOptimizedRange = false

    // Scrubber
    @State private var selectedBarIndex: Int? = nil
    @State private var isDragging = false

    private let barCornerRadius: CGFloat = 8
    private let groupSpacing: CGFloat = 2
    private let innerBarSpacing: CGFloat = 1.5

    // MARK: - Derived

    private var chartEndAge: Int {
        useOptimizedRange ? optimizedEndAge : currentEndAge
    }

    private var totalYears: Int {
        max(1, chartEndAge - startAge)
    }

    private var skipEveryOther: Bool {
        totalYears > 30
    }

    private var displayedYears: [Int] {
        if skipEveryOther {
            return (0..<totalYears).filter { $0 % 2 == 0 }
        }
        return Array(0..<totalYears)
    }

    private var currentYears: Int {
        max(0, currentEndAge - startAge)
    }

    private var optimizedYears: Int {
        max(0, optimizedEndAge - startAge)
    }

    // Stagger total duration (used by parent for reveal timing)
    var totalStaggerDuration: Double {
        Double(displayedYears.count) * 0.045
    }

    // MARK: - Value calculations

    private func accumulatedValue(atYear n: Int, monthly: Double) -> Double {
        var accumulated = startingNetWorth
        for _ in 0..<n {
            accumulated = accumulated * (1 + annualReturn) + monthly * 12
        }
        return accumulated
    }

    private var currentValues: [Double] {
        displayedYears.map { accumulatedValue(atYear: $0 + 1, monthly: monthlySavings) }
    }

    private var optimizedValues: [Double] {
        displayedYears.map { year in
            let age = startAge + year + 1
            if age <= optimizedEndAge {
                return accumulatedValue(atYear: year + 1, monthly: optimizedMonthlySavings)
            }
            return 0
        }
    }

    private var maxValue: Double {
        let currentMax = currentValues.max() ?? 0
        let optimizedMax = optimizedValues.max() ?? 0
        return max(currentMax, optimizedMax)
    }

    var currentEndValue: Double {
        accumulatedValue(atYear: currentYears, monthly: monthlySavings)
    }

    var optimizedEndValue: Double {
        accumulatedValue(atYear: optimizedYears, monthly: optimizedMonthlySavings)
    }

    // MARK: - Active bar index (defaults to last bar)

    private var activeIndex: Int {
        if let idx = selectedBarIndex {
            return idx
        }
        return max(0, displayedYears.count - 1)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Chart area with bars + thumb + tooltip
            GeometryReader { geo in
                let barCount = displayedYears.count
                let totalGaps = groupSpacing * CGFloat(max(1, barCount) - 1)
                let colW = barCount > 0 ? max(4, (geo.size.width - totalGaps) / CGFloat(barCount)) : CGFloat(4)
                let chartHeight = geo.size.height

                ZStack(alignment: .bottom) {
                    // Bars
                    HStack(alignment: .bottom, spacing: groupSpacing) {
                        ForEach(Array(displayedYears.enumerated()), id: \.offset) { index, year in
                            barColumn(
                                index: index,
                                year: year,
                                columnWidth: colW,
                                chartHeight: chartHeight
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    // Thumb (always visible, at bottom of bars)
                    thumbView
                        .position(
                            x: thumbXPosition(index: activeIndex, colW: colW, totalWidth: geo.size.width),
                            y: chartHeight - 12
                        )
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: activeIndex)

                    // Tooltip (always visible, above thumb)
                    tooltipView(
                        index: activeIndex,
                        colW: colW,
                        containerWidth: geo.size.width,
                        chartHeight: chartHeight
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let step = colW + groupSpacing
                            let idx = Int(value.location.x / step)
                            selectedBarIndex = max(0, min(idx, displayedYears.count - 1))
                        }
                        .onEnded { _ in
                            isDragging = false
                            // Keep selectedBarIndex (don't reset — thumb stays)
                        }
                )
            }

            // X-axis row
            xAxisRow
        }
        .onAppear { initProgress() }
        .onChange(of: showCurrentBars) { _, new in
            if new { triggerCurrentBars() }
        }
        .onChange(of: showOptimizedBars) { _, new in
            if new {
                triggerOptimizedBars()
            } else {
                reverseOptimizedBars()
            }
        }
    }

    // MARK: - Thumb position

    private func thumbXPosition(index: Int, colW: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let step = colW + groupSpacing
        return CGFloat(index) * step + colW / 2
    }

    // MARK: - Animation triggers

    private func initProgress() {
        let count = displayedYears.count
        if currentBarProgress.count != count {
            currentBarProgress = Array(repeating: 0, count: count)
            optimizedBarProgress = Array(repeating: 0, count: count)
        }
        // Default thumb to last bar
        selectedBarIndex = nil
        if showCurrentBars { triggerCurrentBars() }
        if showOptimizedBars { triggerOptimizedBars() }
    }

    private func triggerCurrentBars() {
        let count = displayedYears.count
        if currentBarProgress.count != count {
            currentBarProgress = Array(repeating: 0, count: count)
        }
        // 16ms stagger, cubic-bezier overshoot via spring
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.016) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    if i < currentBarProgress.count {
                        currentBarProgress[i] = 1.0
                    }
                }
            }
        }
    }

    private func triggerOptimizedBars() {
        // Shrink chart to optimized range
        useOptimizedRange = true

        // Re-init arrays for new (shorter) range
        let count = displayedYears.count
        currentBarProgress = Array(repeating: 1.0, count: count)
        optimizedBarProgress = Array(repeating: 0, count: count)

        // Compress gray bars to half width
        withAnimation(.easeOut(duration: 0.3)) {
            isDualLayout = true
        }
        // 45ms stagger, spring with overshoot
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.045) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    if i < optimizedBarProgress.count {
                        optimizedBarProgress[i] = 1.0
                    }
                }
            }
        }
    }

    private func reverseOptimizedBars() {
        let count = displayedYears.count
        // Right-to-left stagger: last bar first, 45ms interval
        for i in 0..<count {
            let reverseIndex = count - 1 - i
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.045) {
                withAnimation(.easeIn(duration: 0.3)) {
                    if reverseIndex < optimizedBarProgress.count {
                        optimizedBarProgress[reverseIndex] = 0
                    }
                }
            }
        }
        // After all bars collapse, restore full-width gray bars
        let staggerEnd = Double(count) * 0.045 + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + staggerEnd) {
            withAnimation(.easeOut(duration: 0.3)) {
                isDualLayout = false
            }
        }
        // Expand chart range back to full (currentEndAge)
        DispatchQueue.main.asyncAfter(deadline: .now() + staggerEnd + 0.3) {
            let expandedTotalYears = max(1, currentEndAge - startAge)
            let expandedCount: Int
            if expandedTotalYears > 30 {
                expandedCount = (0..<expandedTotalYears).filter { $0 % 2 == 0 }.count
            } else {
                expandedCount = expandedTotalYears
            }
            currentBarProgress = Array(repeating: 1.0, count: expandedCount)
            optimizedBarProgress = Array(repeating: 0, count: expandedCount)
            useOptimizedRange = false
        }
    }

    // MARK: - Bar Column

    @ViewBuilder
    private func barColumn(index: Int, year: Int, columnWidth: CGFloat, chartHeight: CGFloat) -> some View {
        let maxH = maxValue > 0 ? chartHeight * 0.85 : 0
        let currentVal = index < currentValues.count ? currentValues[index] : 0.0
        let currentH = maxValue > 0 ? (currentVal / maxValue) * maxH : 0
        // Gray bars: only up to currentEndAge (year 0..<currentYears)
        let isInCurrentRange = year >= 0 && year < currentYears

        let optVal = index < optimizedValues.count ? optimizedValues[index] : 0.0
        let optH = maxValue > 0 ? (optVal / maxValue) * maxH : 0
        // Gradient bars: draw to optimized end age
        let barAge = startAge + year + 1
        let isInOptRange = barAge <= optimizedEndAge
        let isFireBar = barAge == optimizedEndAge

        let curProgress: CGFloat = index < currentBarProgress.count ? currentBarProgress[index] : 0
        let optProgress: CGFloat = index < optimizedBarProgress.count ? optimizedBarProgress[index] : 0

        // Dynamic gray opacity: 0.1 + (normalizedH) * 0.55
        let normalizedH = maxH > 0 ? currentH / maxH : 0
        let grayOpacity: Double = 0.1 + normalizedH * 0.55

        let dualBarWidth = max(2, columnWidth * 0.45)
        let grayWidth = isDualLayout ? dualBarWidth : columnWidth

        HStack(alignment: .bottom, spacing: isDualLayout ? innerBarSpacing : 0) {
            // Gray bar (current path)
            if isInCurrentRange {
                UnevenRoundedRectangle(
                    topLeadingRadius: barCornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: barCornerRadius
                )
                .fill(AppColors.textPrimary.opacity(grayOpacity))
                .frame(width: grayWidth, height: max(2, currentH * curProgress))
            } else {
                Color.clear.frame(width: grayWidth, height: 2)
            }

            // Gradient bar (optimized path)
            if isDualLayout {
                if isInOptRange {
                    UnevenRoundedRectangle(
                        topLeadingRadius: barCornerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: barCornerRadius
                    )
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: "FCD34D"), location: 0.0),
                                .init(color: Color(hex: "FCA5A5"), location: 0.45),
                                .init(color: Color(hex: "A78BFA"), location: 1.0)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: dualBarWidth, height: max(2, optH * optProgress))
                    .shadow(
                        color: isFireBar ? Color(hex: "FCA5A5").opacity(0.5) : .clear,
                        radius: isFireBar ? 6 : 0
                    )
                } else {
                    Color.clear.frame(width: dualBarWidth, height: 2)
                }
            }
        }
        .frame(width: columnWidth)
    }

    // MARK: - Thumb

    private var thumbView: some View {
        ZStack {
            Circle()
                .fill(AppColors.overlayWhiteMid)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(.ultraThinMaterial)
                )
                .clipShape(Circle())
            Circle()
                .stroke(AppColors.overlayWhiteHigh, lineWidth: 1.5)
                .frame(width: 24, height: 24)
            RoundedRectangle(cornerRadius: 3)
                .fill(AppColors.overlayWhiteOnPhoto)
                .frame(width: 5, height: 12)
        }
    }

    // MARK: - Tooltip

    /// Compute the rendered bar height at a given index (tallest of gray/gradient)
    private func barHeightAtIndex(_ index: Int, chartHeight: CGFloat) -> CGFloat {
        let maxH = maxValue > 0 ? chartHeight * 0.85 : 0
        guard index < currentValues.count else { return 0 }

        let currentVal = currentValues[index]
        let currentH = maxValue > 0 ? (currentVal / maxValue) * maxH : 0
        let curProgress: CGFloat = index < currentBarProgress.count ? currentBarProgress[index] : 0
        let grayH = max(2, currentH * curProgress)

        var gradH: CGFloat = 0
        if isDualLayout, index < optimizedValues.count {
            let optVal = optimizedValues[index]
            let optH = maxValue > 0 ? (optVal / maxValue) * maxH : 0
            let optProgress: CGFloat = index < optimizedBarProgress.count ? optimizedBarProgress[index] : 0
            gradH = max(2, optH * optProgress)
        }

        return max(grayH, gradH)
    }

    @ViewBuilder
    private func tooltipView(
        index: Int,
        colW: CGFloat,
        containerWidth: CGFloat,
        chartHeight: CGFloat
    ) -> some View {
        if index < displayedYears.count {
            let year = displayedYears[index]
            let age = startAge + year + 1
            let currentVal = index < currentValues.count ? currentValues[index] : 0.0
            let optVal = index < optimizedValues.count ? optimizedValues[index] : 0.0
            let barAge = startAge + year + 1
            let showOpt = showOptimizedBars && barAge <= optimizedEndAge

            let xPos = thumbXPosition(index: index, colW: colW, totalWidth: containerWidth)
            let tooltipW: CGFloat = showOpt ? 140 : 100
            let clampedX = max(tooltipW / 2 + 4, min(xPos, containerWidth - tooltipW / 2 - 4))

            // Position tooltip 18pt above the tallest bar at this index
            let barH = barHeightAtIndex(index, chartHeight: chartHeight)
            let tooltipY = max(30, chartHeight - barH - 18)

            VStack(alignment: .leading, spacing: 3) {
                Text("Age \(age)")
                    .font(.label)
                    .foregroundColor(AppColors.overlayWhiteForegroundSoft)

                if showOpt {
                    Text("Meridian: \(formatCompactValue(optVal))")
                        .font(.footnoteSemibold)
                        .foregroundColor(Color(hex: "FCA5A5"))

                    Text("Current: \(formatCompactValue(currentVal))")
                        .font(.caption)
                        .foregroundColor(AppColors.overlayWhiteForegroundSoft)
                } else {
                    Text(formatCompactValue(currentVal))
                        .font(.footnoteSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 13/255, green: 13/255, blue: 20/255).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.overlayWhiteMid, lineWidth: 1)
            )
            .position(x: clampedX, y: tooltipY)
            .animation(.easeOut(duration: 0.1), value: activeIndex)
        }
    }

    // MARK: - Year calculations for X axis

    private var currentCalendarYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var currentFireYear: Int {
        currentCalendarYear + (currentEndAge - startAge)
    }

    private var optimizedFireYear: Int {
        currentCalendarYear + (optimizedEndAge - startAge)
    }

    // MARK: - X Axis Row

    private var xAxisRow: some View {
        HStack {
            Text("Today")
                .font(.caption)
                .fontWeight(.light)
                .foregroundColor(AppColors.overlayWhiteAt60)

            Spacer()

            if showOptimizedBars {
                Text("\(optimizedFireYear)")
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color(hex: "FCA5A5"))
                    .transition(.opacity)
            } else {
                Text("\(currentFireYear)")
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(AppColors.overlayWhiteAt60)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm + AppSpacing.xs)
        .frame(height: 36)
        .animation(.easeOut(duration: 0.5), value: showOptimizedBars)
    }

    // MARK: - Helpers

    private func formatCompactValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "\(currencySymbol)\(String(format: "%.1f", value / 1_000_000))M"
        } else if value >= 1_000 {
            return "\(currencySymbol)\(Int(value / 1_000))K"
        } else if value > 0 {
            return "\(currencySymbol)\(Int(value))"
        }
        return "\(currencySymbol)0"
    }
}
