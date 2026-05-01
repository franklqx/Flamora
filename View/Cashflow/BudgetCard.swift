//
//  BudgetCard.swift
//  Flamora app
//
//  L1 budget summary on the Cash Flow main page.
//  - Ring shows total budget usage, split only by Needs vs Wants.
//  - Sections below explain top categories without turning the card into L2.
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending
    let apiBudget: APIMonthlyBudget
    var needsDetailData: SpendingDetailData? = nil
    var wantsDetailData: SpendingDetailData? = nil
    var isConnected: Bool = true
    var hasBudget: Bool = true
    var onSetupBudget: (() -> Void)? = nil
    let onCardTapped: (() -> Void)?
    let onNeedsTapped: (() -> Void)?
    let onWantsTapped: (() -> Void)?
    var onAdjustOverallPlan: (() -> Void)? = nil
    var onEditCategoryBudgets: (() -> Void)? = nil
    var displayMonth: Date = Date()
    var onMonthLabelTapped: (() -> Void)? = nil

    @State private var showEditChooser = false

    private var needsColor: Color { AppColors.budgetNeedsBlue }
    private var wantsColor: Color { AppColors.budgetWantsPurple }
    private var overBudgetColor: Color { AppColors.warning }
    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// `apiBudget.needsBudget` / `wantsBudget` are derived sums of the user's
    /// subcategory budgets — Needs and Wants themselves have no user-facing
    /// budget, they're just classification labels.
    private var totalBudget: Double { max(apiBudget.needsBudget + apiBudget.wantsBudget, 0) }
    private var totalSpent: Double { max(spending.needs + spending.wants, 0) }
    private var isOverBudget: Bool { totalBudget > 0 && totalSpent > totalBudget }
    private var overByAmount: Double { max(totalSpent - totalBudget, 0) }
    private var usedPercent: Int {
        guard totalBudget > 0 else { return 0 }
        return Int((totalSpent / totalBudget * 100).rounded())
    }
    private var needsShare: Double {
        totalSpent > 0 ? max(spending.needs, 0) / totalSpent : 0
    }
    private var wantsShare: Double {
        totalSpent > 0 ? max(spending.wants, 0) / totalSpent : 0
    }
    private var isShowingCurrentMonth: Bool {
        Calendar.current.isDate(displayMonth, equalTo: Date(), toGranularity: .month)
    }
    private var displayMonthYear: Int {
        Calendar.current.component(.year, from: displayMonth)
    }
    private var displayMonthIndex: Int {
        Calendar.current.component(.month, from: displayMonth) - 1
    }

    init(
        spending: Spending,
        apiBudget: APIMonthlyBudget,
        needsDetailData: SpendingDetailData? = nil,
        wantsDetailData: SpendingDetailData? = nil,
        isConnected: Bool = true,
        hasBudget: Bool = true,
        onSetupBudget: (() -> Void)? = nil,
        onCardTapped: (() -> Void)? = nil,
        onNeedsTapped: (() -> Void)? = nil,
        onWantsTapped: (() -> Void)? = nil,
        onAdjustOverallPlan: (() -> Void)? = nil,
        onEditCategoryBudgets: (() -> Void)? = nil,
        displayMonth: Date = Date(),
        onMonthLabelTapped: (() -> Void)? = nil
    ) {
        self.spending = spending
        self.apiBudget = apiBudget
        self.needsDetailData = needsDetailData
        self.wantsDetailData = wantsDetailData
        self.isConnected = isConnected
        self.hasBudget = hasBudget
        self.onSetupBudget = onSetupBudget
        self.onCardTapped = onCardTapped
        self.onNeedsTapped = onNeedsTapped
        self.onWantsTapped = onWantsTapped
        self.onAdjustOverallPlan = onAdjustOverallPlan
        self.onEditCategoryBudgets = onEditCategoryBudgets
        self.displayMonth = displayMonth
        self.onMonthLabelTapped = onMonthLabelTapped
    }

    private struct BudgetCategorySummary: Identifiable {
        let id: String
        let name: String
        let icon: String
        let parent: String
        let spent: Double
        let budget: Double
        let color: Color

        var hasBudget: Bool { budget > 0 }
        var isOver: Bool { hasBudget && spent > budget }
        var limitStatus: String? {
            guard hasBudget else { return nil }
            if spent > budget { return "Over" }
            if spent / max(budget, 0.0001) >= 0.8 { return "Near" }
            return nil
        }
    }

    private struct RingSegment: Identifiable {
        let id: String
        let amount: Double
        let color: Color
    }

    private struct RingArcShape: Shape {
        let startDegrees: Double
        let endDegrees: Double
        let lineWidth: CGFloat

        func path(in rect: CGRect) -> Path {
            let radius = max((min(rect.width, rect.height) - lineWidth) / 2, 0)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startDegrees),
                endAngle: .degrees(endDegrees),
                clockwise: false
            )
            return path
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if hasBudget {
                budgetDisplaySection
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
            } else {
                setupEmptyState
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showEditChooser) {
            BudgetEditChooserSheet(
                onAdjustOverallPlan: { onAdjustOverallPlan?() },
                onEditCategoryBudgets: { onEditCategoryBudgets?() }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("BUDGET")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isConnected && hasBudget { onCardTapped?() }
                }

            Spacer()

            Button {
                if isConnected && hasBudget { onMonthLabelTapped?() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(monthLabel)
                        .font(.cardHeader)
                        .foregroundColor(AppColors.inkPrimary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    if isConnected && hasBudget {
                        Image(systemName: "chevron.right")
                            .font(.miniLabel)
                            .foregroundColor(AppColors.inkFaint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!(isConnected && hasBudget))
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
    }

    private var budgetDisplaySection: some View {
        let needsCategories = categorySummaries(parent: "needs", detailData: needsDetailData)
        let wantsCategories = categorySummaries(parent: "wants", detailData: wantsDetailData)

        return VStack(spacing: AppSpacing.lg) {
            ringSection
            VStack(spacing: AppSpacing.md) {
                bucketRow(
                    title: "Needs",
                    spent: spending.needs,
                    share: needsShare,
                    color: needsColor,
                    categories: Array(needsCategories.prefix(3)),
                    onTap: onNeedsTapped
                )
                bucketRow(
                    title: "Wants",
                    spent: spending.wants,
                    share: wantsShare,
                    color: wantsColor,
                    categories: Array(wantsCategories.prefix(3)),
                    onTap: onWantsTapped
                )
            }
        }
    }

    private var ringSection: some View {
        let safeNeedsBudget = max(apiBudget.needsBudget, 0)
        let safeWantsBudget = max(apiBudget.wantsBudget, 0)
        let safeTotalBudget = max(safeNeedsBudget + safeWantsBudget, 0)
        let denominator = max(safeTotalBudget, totalSpent, 1)
        let segments = ringSegments(denominator: denominator)
        let ringDiameter: CGFloat = 208
        let ringLineWidth: CGFloat = 15

        return ZStack {
            ForEach(positionedSegments(segments, diameter: ringDiameter, lineWidth: ringLineWidth)) { segment in
                RingArcShape(
                    startDegrees: segment.startDegrees,
                    endDegrees: segment.endDegrees,
                    lineWidth: ringLineWidth
                )
                .stroke(segment.color, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
            }

            VStack(spacing: AppSpacing.xs) {
                Text("\(max(usedPercent, 0))%")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.inkSoft)
                Text("\(formatCurrency(max(totalSpent, 0))) spent")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(formatCurrency(safeTotalBudget)) budget")
                    .font(.caption)
                    .foregroundColor(AppColors.inkFaint)
                if isOverBudget {
                    Text("Over")
                        .font(.miniLabel)
                        .foregroundColor(overBudgetColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(overBudgetColor.opacity(0.10))
                        .clipShape(Capsule())
                        .padding(.top, 1)
                }
                if isConnected && hasBudget && isShowingCurrentMonth {
                    Button {
                        showEditChooser = true
                    } label: {
                        Text("Edit budget")
                            .font(.caption)
                            .foregroundColor(AppColors.inkPrimary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.sm)
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if isConnected && hasBudget { onCardTapped?() }
        }
    }

    private func bucketRow(
        title: String,
        spent: Double,
        share: Double,
        color: Color,
        categories: [BudgetCategorySummary],
        onTap: (() -> Void)?
    ) -> some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.bodySemibold)
                        .foregroundColor(AppColors.inkPrimary)
                    Spacer()
                    Text(formatCurrency(max(spent, 0)))
                        .font(.bodySemibold)
                        .foregroundColor(AppColors.inkPrimary)
                        .monospacedDigit()
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.inkSoft)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                GeometryReader { geo in
                    let width = max(geo.size.width, 0)
                    let clamped = min(max(share, 0), 1)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.inkTrack)
                            .frame(height: 5)
                        Capsule()
                            .fill(color)
                            .frame(width: width * clamped, height: 5)
                    }
                }
                .frame(height: 5)

                if !categories.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        ForEach(categories) { category in
                            categorySummaryLine(category)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    private func categorySummaryLine(_ category: BudgetCategorySummary) -> some View {
        HStack(spacing: AppSpacing.sm) {
            categoryIcon(category.icon, color: category.color)
            Text(category.name)
                .font(.caption)
                .foregroundColor(AppColors.inkPrimary)
                .lineLimit(1)
            Spacer(minLength: AppSpacing.xs)
            if let status = category.limitStatus {
                Text(status)
                    .font(.miniLabel)
                    .foregroundStyle(status == "Over" ? AppColors.warning : AppColors.inkSoft)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((status == "Over" ? AppColors.warning : AppColors.inkSoft).opacity(0.10))
                    .clipShape(Capsule())
            }
            Text(formatCurrencyCompact(category.spent))
                .font(.caption)
                .foregroundColor(AppColors.inkPrimary)
                .monospacedDigit()
        }
    }

    private func categoryIcon(_ icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(0.11))
                .frame(width: 24, height: 24)
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
        }
    }

    private var setupEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Build Your Plan")
                    .font(.h3)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("Let AI analyze your spending and create a personalized budget.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { onSetupBudget?() }) {
                Text("Start Setup")
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textInverse)
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
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: displayMonth).uppercased()
    }

    private func categorySummaries(parent: String, detailData: SpendingDetailData?) -> [BudgetCategorySummary] {
        let categories = detailData?.monthlyDataByYear[displayMonthYear]?[displayMonthIndex]?.categories ?? []
        let budgetMap = apiBudget.categoryBudgets ?? [:]
        let catalog = TransactionCategoryCatalog.all.filter { $0.parent == parent }
        let color = parent == "wants" ? wantsColor : needsColor

        struct Accumulator {
            var name: String
            var icon: String
            var spent: Double
            var budget: Double
            var order: Int
        }

        var rows: [String: Accumulator] = [:]
        for (index, category) in categories.enumerated() {
            let canonical = TransactionCategoryCatalog.canonicalSubcategory(fromStored: category.name)
                ?? TransactionCategoryCatalog.id(forDisplayedSubcategory: category.name)
            let key = canonical ?? category.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let catalogCategory = canonical.flatMap { id in catalog.first { $0.id == id } }
            let name = catalogCategory?.name ?? TransactionCategoryCatalog.displayName(for: category.name)
            let icon = catalogCategory?.icon ?? category.icon
            let budget = canonical.flatMap { budgetMap[$0] } ?? budgetMap[key] ?? 0
            var existing = rows[key] ?? Accumulator(name: name, icon: icon, spent: 0, budget: budget, order: index)
            existing.spent += max(category.amount, 0)
            existing.budget = max(existing.budget, budget)
            rows[key] = existing
        }

        return rows
            .filter { $0.value.spent > 0.005 }
            .sorted {
                if abs($0.value.spent - $1.value.spent) > 0.005 {
                    return $0.value.spent > $1.value.spent
                }
                return $0.value.order < $1.value.order
            }
            .map { item in
                BudgetCategorySummary(
                    id: "\(parent)-\(item.key)",
                    name: item.value.name,
                    icon: item.value.icon,
                    parent: parent,
                    spent: item.value.spent,
                    budget: item.value.budget,
                    color: color
                )
            }
    }

    private func ringSegments(denominator: Double) -> [RingSegment] {
        let colored = [
            RingSegment(id: "needs", amount: max(spending.needs, 0), color: needsColor),
            RingSegment(id: "wants", amount: max(spending.wants, 0), color: wantsColor)
        ].filter { $0.amount > 0.005 }

        let remaining = max(denominator - totalSpent, 0)
        if remaining > 0.005 {
            return colored + [
                RingSegment(id: "remaining", amount: remaining, color: AppColors.inkTrack)
            ]
        }

        if colored.isEmpty {
            return [RingSegment(id: "empty-track", amount: denominator, color: AppColors.inkTrack)]
        }

        return colored
    }

    private struct PositionedRingSegment: Identifiable {
        let id: String
        let startDegrees: Double
        let endDegrees: Double
        let color: Color
    }

    private func positionedSegments(
        _ segments: [RingSegment],
        diameter: CGFloat,
        lineWidth: CGFloat
    ) -> [PositionedRingSegment] {
        let visibleSegments = segments.filter { $0.amount > 0.005 }
        guard !visibleSegments.isEmpty else { return [] }

        let totalAmount = visibleSegments.reduce(0) { $0 + max($1.amount, 0) }
        guard totalAmount > 0 else { return [] }

        let radius = max((diameter - lineWidth) / 2, 1)
        let capExtensionDegrees = Double((lineWidth / 2) / radius) * 180 / .pi
        let visibleGapDegrees = 3.5
        let gapDegrees = visibleSegments.count > 1 ? visibleGapDegrees + capExtensionDegrees * 2 : 0.0
        let availableDegrees = max(360.0 - gapDegrees * Double(visibleSegments.count), 0)
        let minimumSegmentDegrees = visibleSegments.count > 1 ? 14.0 : 0.0
        var sweeps = visibleSegments.map { max($0.amount, 0) / totalAmount * availableDegrees }

        let smallIndices = Set(
            sweeps.indices.filter { sweeps[$0] > 0 && sweeps[$0] < minimumSegmentDegrees }
        )
        var borrowedDegrees = 0.0
        for index in smallIndices {
            borrowedDegrees += minimumSegmentDegrees - sweeps[index]
            sweeps[index] = minimumSegmentDegrees
        }

        if borrowedDegrees > 0 {
            let reducibleIndices = sweeps.indices.filter {
                !smallIndices.contains($0) && sweeps[$0] > minimumSegmentDegrees
            }
            let reducibleDegrees = reducibleIndices.reduce(0) {
                $0 + max(sweeps[$1] - minimumSegmentDegrees, 0)
            }

            if reducibleDegrees > 0 {
                for index in reducibleIndices {
                    let capacity = max(sweeps[index] - minimumSegmentDegrees, 0)
                    let reduction = borrowedDegrees * capacity / reducibleDegrees
                    sweeps[index] = max(sweeps[index] - reduction, minimumSegmentDegrees)
                }
            }
        }

        let totalSweep = sweeps.reduce(0, +)
        if totalSweep > availableDegrees && totalSweep > 0 {
            let scale = availableDegrees / totalSweep
            sweeps = sweeps.map { $0 * scale }
        }

        var cursor = -90.0
        return zip(visibleSegments, sweeps).compactMap { segment, sweep in
            guard sweep > 0.5 else { return nil }
            let start = cursor
            let end = cursor + sweep
            cursor = end + gapDegrees
            return PositionedRingSegment(
                id: segment.id,
                startDegrees: start,
                endDegrees: end,
                color: segment.color
            )
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func formatCurrencyCompact(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = value >= 100 ? 0 : 2
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        BudgetCard(
            spending: MockData.cashflowData.spending,
            apiBudget: MockData.apiMonthlyBudget
        )
        .padding()
    }
}
