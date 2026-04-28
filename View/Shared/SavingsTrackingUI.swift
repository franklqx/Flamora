//
//  SavingsTrackingUI.swift
//  Flamora app
//
//  Shared month-state model + UI for Home / Cashflow savings tracking.
//

import SwiftUI

enum SavingsMonthVisualState {
    case future
    case pending
    case missed
    case belowTarget
    case onTarget
}

struct SavingsMonthNode: Identifiable, Equatable {
    let id: String
    let year: Int
    let monthIndex: Int
    let label: String
    let shortLabel: String
    let amount: Double?
    let state: SavingsMonthVisualState
    let isCurrentMonth: Bool
    let isEditable: Bool
}

struct SavingsTrackingSnapshot {
    let year: Int
    let targetRatePercent: Double
    let targetAmount: Double
    let currentWindowTitle: String
    let fullYearNodes: [SavingsMonthNode]
    let currentWindowNodes: [SavingsMonthNode]
    let monthsOnTarget: Int
    let completedMonths: Int
    let ytdAverageRatePercent: Double?

    var ytdAverageText: String {
        guard let ytdAverageRatePercent else { return "—" }
        return "\(Int(ytdAverageRatePercent.rounded()))%"
    }

    var completionText: String {
        guard completedMonths > 0 else { return "No check-ins yet" }
        return "\(monthsOnTarget) of \(completedMonths) on target"
    }

    var helperText: String {
        if completedMonths == 0 {
            return "Tap a month to record your savings check-in."
        }
        if monthsOnTarget == completedMonths {
            return "You're holding your target across every completed month."
        }
        if monthsOnTarget == 0 {
            return "You've started tracking. Keep going and the trend will sharpen."
        }
        return "Your average can still win even if one month comes in light."
    }

    var compactHomeText: String {
        if completedMonths == 0 {
            return "Tap a month to check in."
        }
        if monthsOnTarget == completedMonths {
            return "Every completed month is on target."
        }
        return completionText
    }
}

enum SavingsTrackingBuilder {
    static let monthLabels = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    /// Cumulative rolling 4-month window. The window stays anchored at the
    /// user's journey start until the current month would slide past the
    /// rightmost slot, after which it shifts forward by 1 each month so
    /// `current` always sits within bounds. Passing `journeyStartMonth = 0`
    /// (no constraint) reproduces the pre-cumulative behaviour for callers
    /// without plan creation context.
    static func currentWindowRange(for date: Date, journeyStartMonth: Int = 0) -> ClosedRange<Int> {
        let monthIndex = Calendar.current.component(.month, from: date) - 1
        let clampedStart = max(0, min(journeyStartMonth, 8))
        let lowerBound = max(clampedStart, monthIndex - 3)
        let start = min(max(lowerBound, 0), 8)
        return start...(start + 3)
    }

    static func snapshot(
        year: Int,
        monthlyAmounts: [Double?],
        targetAmount: Double,
        targetRatePercent: Double,
        journeyStartDate: Date? = nil,
        referenceDate: Date = Date()
    ) -> SavingsTrackingSnapshot {
        let currentYear = Calendar.current.component(.year, from: referenceDate)
        let currentMonthIndex = Calendar.current.component(.month, from: referenceDate) - 1
        let journeyStartMonth = resolveJourneyStartMonth(
            startDate: journeyStartDate,
            year: year,
            monthlyAmounts: monthlyAmounts,
            referenceDate: referenceDate
        )
        let windowRange = currentWindowRange(
            for: referenceDate,
            journeyStartMonth: year == currentYear ? journeyStartMonth : 0
        )
        let inferredMonthlyIncome = inferredIncome(targetAmount: targetAmount, targetRatePercent: targetRatePercent)

        let amounts = (0..<12).map { idx in
            idx < monthlyAmounts.count ? monthlyAmounts[idx] : nil
        }

        let nodes = (0..<12).map { idx -> SavingsMonthNode in
            let amount = amounts[idx]
            let isCurrent = year == currentYear && idx == currentMonthIndex
            let state = stateForMonth(
                year: year,
                monthIndex: idx,
                amount: amount,
                targetAmount: targetAmount,
                currentYear: currentYear,
                currentMonthIndex: currentMonthIndex,
                journeyStartMonth: year == currentYear ? journeyStartMonth : 0
            )

            return SavingsMonthNode(
                id: "\(year)-\(idx)",
                year: year,
                monthIndex: idx,
                label: monthLabels[idx],
                shortLabel: String(monthLabels[idx].prefix(3)),
                amount: amount,
                state: state,
                isCurrentMonth: isCurrent,
                isEditable: state != .future
            )
        }

        let visibleNodes = nodes.filter { windowRange.contains($0.monthIndex) }
        let consideredNodes = nodes.filter {
            if year < currentYear { return true }
            if year > currentYear { return false }
            return $0.monthIndex <= currentMonthIndex
        }
        let completedAmounts = consideredNodes.compactMap(\.amount)
        let monthsOnTarget = completedAmounts.filter { targetAmount > 0 ? $0 >= targetAmount : $0 > 0 }.count
        let ytdAverageRate: Double?
        if let inferredMonthlyIncome, inferredMonthlyIncome > 0, !completedAmounts.isEmpty {
            let avgAmount = completedAmounts.reduce(0, +) / Double(completedAmounts.count)
            ytdAverageRate = (avgAmount / inferredMonthlyIncome) * 100
        } else {
            ytdAverageRate = nil
        }

        return SavingsTrackingSnapshot(
            year: year,
            targetRatePercent: targetRatePercent,
            targetAmount: targetAmount,
            currentWindowTitle: "\(monthLabels[windowRange.lowerBound])-\(monthLabels[windowRange.upperBound])",
            fullYearNodes: nodes,
            currentWindowNodes: visibleNodes,
            monthsOnTarget: monthsOnTarget,
            completedMonths: completedAmounts.count,
            ytdAverageRatePercent: ytdAverageRate
        )
    }

    private static func stateForMonth(
        year: Int,
        monthIndex: Int,
        amount: Double?,
        targetAmount: Double,
        currentYear: Int,
        currentMonthIndex: Int,
        journeyStartMonth: Int
    ) -> SavingsMonthVisualState {
        // Future months (haven't arrived yet) are locked.
        if year > currentYear { return .future }
        if year == currentYear, monthIndex > currentMonthIndex {
            return .future
        }
        // Past or current month — including pre-plan months, which the user
        // can backfill by tapping the "+" orb.
        guard let amount else {
            if year == currentYear, monthIndex == currentMonthIndex {
                return .pending
            }
            return .missed
        }
        if targetAmount > 0, amount >= targetAmount {
            return .onTarget
        }
        return .belowTarget
    }

    private static func resolveJourneyStartMonth(
        startDate: Date?,
        year: Int,
        monthlyAmounts: [Double?],
        referenceDate: Date
    ) -> Int {
        let cal = Calendar.current
        if let startDate {
            let startYear = cal.component(.year, from: startDate)
            if startYear < year { return 0 }
            if startYear > year { return 11 }
            return cal.component(.month, from: startDate) - 1
        }
        // No stored startDate: treat as "registered this month". Falling back
        // to current month avoids using auto-imported Plaid history (which
        // would pull the journey start before the user actually committed
        // a plan).
        let referenceYear = cal.component(.year, from: referenceDate)
        if year < referenceYear { return 0 }
        if year > referenceYear { return 11 }
        return cal.component(.month, from: referenceDate) - 1
    }

    private static func inferredIncome(targetAmount: Double, targetRatePercent: Double) -> Double? {
        guard targetAmount > 0, targetRatePercent > 0 else { return nil }
        return targetAmount / (targetRatePercent / 100.0)
    }
}

struct SavingsMonthOrb: View {
    let node: SavingsMonthNode
    var isSelected: Bool = false
    var diameter: CGFloat = 48

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                circleBackground
                    .frame(width: diameter, height: diameter)
                    .overlay(circleOverlay)
                    .overlay(selectionRing)

                centerSymbol
            }

            Text(node.shortLabel)
                .font(.miniLabel)
                .foregroundStyle(node.isCurrentMonth ? AppColors.inkPrimary : AppColors.inkFaint)
                .tracking(0.6)
        }
        .frame(width: diameter + 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(node.label)
        .accessibilityValue(accessibilityValueText)
    }

    private var accessibilityValueText: String {
        switch node.state {
        case .future:    return "Upcoming"
        case .pending:   return node.isEditable ? "No check-in yet, tap to log" : "No check-in yet"
        case .missed:    return node.isEditable ? "Missed, tap to log" : "Missed"
        case .belowTarget:
            if let amt = node.amount { return "Below target, saved \(formattedAmount(amt))" }
            return "Below target"
        case .onTarget:
            if let amt = node.amount { return "On target, saved \(formattedAmount(amt))" }
            return "On target"
        }
    }

    private func formattedAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    @ViewBuilder
    private var circleBackground: some View {
        switch node.state {
        case .future:
            Circle().fill(AppColors.ctaWhite.opacity(0.55))
        case .pending:
            Circle().fill(AppColors.glassBlockBg)
        case .missed:
            Circle().fill(AppColors.inkTrack)
        case .belowTarget:
            Circle().fill(AppColors.ctaWhite.opacity(0.92))
        case .onTarget:
            Circle()
                .fill(
                    LinearGradient(
                        colors: AppColors.gradientShellAccent,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    @ViewBuilder
    private var circleOverlay: some View {
        switch node.state {
        case .future:
            Circle().stroke(AppColors.inkBorder, style: StrokeStyle(lineWidth: 1))
        case .pending:
            Circle().stroke(AppColors.inkBorder, style: StrokeStyle(lineWidth: 1.25))
        case .missed:
            Circle().stroke(AppColors.inkBorder.opacity(0.45), style: StrokeStyle(lineWidth: 1))
        case .belowTarget:
            Circle().stroke(AppColors.inkBorder, style: StrokeStyle(lineWidth: 1))
        case .onTarget:
            Circle().stroke(AppColors.glassCardBorder, style: StrokeStyle(lineWidth: 1))
        }
    }

    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            Circle()
                .inset(by: -2)
                .stroke(AppColors.inkPrimary, style: StrokeStyle(lineWidth: 1.25))
        }
    }

    @ViewBuilder
    private var centerSymbol: some View {
        switch node.state {
        case .future:
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(AppColors.inkFaint)
        case .pending:
            Image(systemName: "plus")
                .font(.footnoteSemibold)
                .foregroundStyle(AppColors.inkSoft)
        case .missed:
            if node.isEditable {
                Image(systemName: "plus")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkSoft)
            }
        case .belowTarget:
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.inkSoft)
        case .onTarget:
            FlameIcon(size: 18, color: AppColors.ctaWhite)
                .shadow(color: AppColors.accentAmber.opacity(0.22), radius: 8, y: 4)
        }
    }
}
