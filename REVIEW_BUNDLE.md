# REVIEW BUNDLE

> 生成时间：2026-04-01
> 包含 9 个文件，按阶段分组。

---

## View/Cashflow/BudgetCard.swift

```swift
//
//  BudgetCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetCard: View {
    let spending: Spending
    /// 与父视图已加载的 `APIMonthlyBudget` 一致（阶段 0 / 路线图 0.1），避免 Needs/Wants 上限锁死在 MockData。
    let apiBudget: APIMonthlyBudget
    var isConnected: Bool = true
    var hasBudget: Bool = true
    var onSetupBudget: (() -> Void)? = nil
    let onCardTapped: (() -> Void)?
    let onNeedsTapped: (() -> Void)?
    let onWantsTapped: (() -> Void)?

    private var needsColor: Color { AppColors.chartBlue }
    private var wantsColor: Color { AppColors.chartAmber }

    init(
        spending: Spending,
        apiBudget: APIMonthlyBudget,
        isConnected: Bool = true,
        hasBudget: Bool = true,
        onSetupBudget: (() -> Void)? = nil,
        onCardTapped: (() -> Void)? = nil,
        onNeedsTapped: (() -> Void)? = nil,
        onWantsTapped: (() -> Void)? = nil
    ) {
        self.spending = spending
        self.apiBudget = apiBudget
        self.isConnected = isConnected
        self.hasBudget = hasBudget
        self.onSetupBudget = onSetupBudget
        self.onCardTapped = onCardTapped
        self.onNeedsTapped = onNeedsTapped
        self.onWantsTapped = onWantsTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TOTAL SPEND")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(AppTypography.Tracking.cardHeader)
                Spacer()
                HStack(spacing: AppSpacing.xs) {
                    Text(currentMonthLabel)
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    if isConnected && hasBudget {
                        Image(systemName: "chevron.right")
                            .font(.miniLabel)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.cardPadding)
            .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
            .contentShape(Rectangle())
            .onTapGesture {
                if isConnected && hasBudget { onCardTapped?() }
            }

            Rectangle()
                .fill(AppColors.surfaceBorder)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if !isConnected {
                lockedEmptyState
            } else if hasBudget {
                VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Text(formatCurrency(spending.total))
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("/ \(formatCurrency(spending.budgetLimit))")
                            .font(.inlineLabel)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    segmentedBar
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.md)
                .contentShape(Rectangle())
                .onTapGesture { onCardTapped?() }

                VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                    BudgetRowItem(
                        title: "Needs",
                        current: formatCurrency(spending.needs),
                        total: formatCurrency(apiBudget.needsBudget),
                        color: needsColor,
                        onTap: onNeedsTapped
                    )
                    BudgetRowItem(
                        title: "Wants",
                        current: formatCurrency(spending.wants),
                        total: formatCurrency(apiBudget.wantsBudget),
                        color: wantsColor,
                        onTap: onWantsTapped
                    )
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.cardPadding)
            } else {
                setupEmptyState
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var lockedEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("$—")
                    .font(.cardFigurePrimary)
                    .foregroundStyle(AppColors.textTertiary)
                Text("/ $—")
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textTertiary)
            }
            Text("Connect accounts to set up a budget")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textTertiary)
            Capsule()
                .fill(AppColors.progressTrack)
                .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
    }

    private var setupEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Build Your Plan")
                    .font(.h3)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Let AI analyze your spending and create a personalized budget.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
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

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private var segmentedBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeW = w.isFinite && w >= 0 ? w : 0
            let limit = max(spending.budgetLimit, 1)
            let nRatio = min(max(spending.needs / limit, 0), 1)
            let wRatio = min(max(spending.wants / limit, 0), 1)
            let nWidth = max(0, safeW * CGFloat(nRatio))
            let wWidth = max(0, safeW * CGFloat(wRatio))

            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.progressTrack).frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
                HStack(spacing: 0) {
                    Rectangle().fill(needsColor).frame(width: nWidth)
                    Rectangle().fill(wantsColor).frame(width: wWidth)
                }
                .clipShape(Capsule())
                .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
            }
        }
        .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

private struct BudgetRowItem: View {
    let title: String
    let current: String
    let total: String
    let color: Color
    let onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap { Button(action: onTap) { rowContent }.buttonStyle(.plain) }
            else { rowContent }
        }
    }

    private var rowContent: some View {
        HStack {
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                Text(title)
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(current)
                    .font(.cardFigureSecondary)
                    .foregroundStyle(AppColors.textPrimary)
                Text("/ \(total)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        BudgetCard(spending: MockData.cashflowData.spending, apiBudget: MockData.apiMonthlyBudget).padding()
    }
}
```

---

## View/Cashflow/SavingsTargetDetailView2.swift

```swift
//
//  SavingsTargetDetailView2.swift
//  Flamora app
//
//  Savings target detail view - complete rewrite
//

import SwiftUI

struct SavingsTargetDetailView2: View {
    /// API 储蓄比例（百分比，如 25 表示 25%）。
    private let savingsRatioPercent: Double
    private let targetRate: Double
    private let targetAmount: Double

    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int
    @State private var monthlyAmountsByYear: [Int: [Double?]]
    @State private var editingMonthIndex: Int? = nil
    @State private var editingAmount: Double = 0
    @State private var isShowingEditSheet: Bool = false
    @State private var chartHoverIndex: Int? = nil
    @State private var dragOffset: CGFloat = 0

    private let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private let monthsShort = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    /// 阶段 0 / 路线图 0.2：目标与序列由调用方传入；年度月度序列在阶段 2 可换为 API。
    init(
        savingsRatioPercent: Double,
        savingsBudgetTarget: Double,
        monthlyAmountsByYear: [Int: [Double?]]
    ) {
        self.savingsRatioPercent = savingsRatioPercent
        self.targetRate = savingsRatioPercent / 100.0
        self.targetAmount = savingsBudgetTarget
        let byYear = monthlyAmountsByYear
        let latest = byYear.keys.sorted().last ?? Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: latest)
        _monthlyAmountsByYear = State(initialValue: byYear)
    }

    private var availableYears: [Int] { monthlyAmountsByYear.keys.sorted() }
    private var canGoPrev: Bool { (availableYears.first ?? Int.max) < selectedYear }
    private var canGoNext: Bool { (availableYears.last  ?? Int.min) > selectedYear }

    private var currentMonthlyAmounts: [Double?] {
        monthlyAmountsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
    }

    private var annualSaved: Double {
        currentMonthlyAmounts.compactMap { $0 }.reduce(0, +)
    }

    private func navigateYear(_ delta: Int) {
        guard let idx = availableYears.firstIndex(of: selectedYear) else { return }
        let newIdx = idx + delta
        guard newIdx >= 0 && newIdx < availableYears.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedYear = availableYears[newIdx]
            chartHoverIndex = nil
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Header
                    HStack(alignment: .firstTextBaseline) {
                        Text("Saving overview")
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.bodySmallSemibold)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, -4)

                    // Total saved
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(formatMoney(annualSaved))
                            .font(.display)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Total saved this year")
                            .font(.supportingText)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    // Chart section with year picker
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Text("ANNUAL TREND")
                                .font(.cardHeader)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(1.5)

                            Spacer()

                            yearPicker
                        }

                        chartView
                            .frame(height: 220)
                            .padding(.top, AppSpacing.xs)
                    }
                    .padding(.top, AppSpacing.sm)

                    // Target info
                    HStack(spacing: AppSpacing.xl) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
                            Text("TARGET SAVING RATE")
                                .font(.cardHeader)
                                .foregroundColor(AppColors.textTertiary)

                            Text("\(Int(savingsRatioPercent))%")
                                .font(.detailTitle)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        Divider()
                            .frame(height: 50)
                            .background(AppColors.surfaceBorder)

                        VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
                            Text("TARGET SAVING")
                                .font(.cardHeader)
                                .foregroundColor(AppColors.textTertiary)

                            Text(formatMoney(targetAmount))
                                .font(.detailTitle)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.sm)

                    // Monthly milestones
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("MONTHLY MILESTONES")
                            .font(.smallLabel)
                            .foregroundColor(AppColors.textTertiary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm + AppSpacing.xs) {
                            ForEach(0..<12) { index in
                                monthCard(index: index)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.tabBarReserve + AppSpacing.md)
            }
        }
        .preferredColorScheme(.dark)
        .offset(y: dragOffset)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(isPresented: $isShowingEditSheet, onDismiss: {
            applyEditedAmount()
        }) {
            SavingsInputSheet(amount: $editingAmount)
                .ignoresSafeArea(.container, edges: .bottom)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(AppRadius.button)
                .presentationBackground(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            Button { navigateYear(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.footnoteRegular)
                    .foregroundColor(canGoPrev ? AppColors.textSecondary : AppColors.textTertiary)
            }
            .disabled(!canGoPrev)
            .buttonStyle(.plain)

            Text(String(selectedYear))
                .font(.footnoteRegular)
                .foregroundColor(AppColors.textSecondary)
                .frame(minWidth: 36)

            Button { navigateYear(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.footnoteRegular)
                    .foregroundColor(canGoNext ? AppColors.textSecondary : AppColors.textTertiary)
            }
            .disabled(!canGoNext)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Chart View

    private let maxChartAmount: Double = 3500

    private var chartView: some View {
        GeometryReader { geometry in
            let barAreaHeight = geometry.size.height - 30 // 30 for month labels
            let targetRatio = CGFloat(targetAmount / maxChartAmount)
            let targetY = geometry.size.height - 30 - barAreaHeight * targetRatio

            ZStack(alignment: .bottomLeading) {
                // Target line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: targetY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: targetY))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundColor(AppColors.textTertiary)

                HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                    ForEach(0..<12) { index in
                        barView(index: index, maxHeight: barAreaHeight)
                    }
                }

                chartHoverOverlay(geometry: geometry)

                // Target label
                Text("TARGET")
                    .font(.label)
                    .foregroundColor(AppColors.textTertiary)
                    .position(x: geometry.size.width - 30, y: targetY - 10)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    navigateYear(value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private func barView(index: Int, maxHeight: CGFloat) -> some View {
        let amount = index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil
        let height = calculateHeight(amount: amount, maxHeight: maxHeight)
        let isTarget = (amount ?? 0) >= targetAmount

        return VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(barColor(amount: amount, isTarget: isTarget))
                .frame(height: height)

            Text(monthsShort[index])
                .font(.cardHeader)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chartHoverOverlay(geometry: GeometryProxy) -> some View {
        let step = geometry.size.width / 12
        let maxHeight = geometry.size.height - 30

        return ZStack {
            if let index = chartHoverIndex {
                let amount = index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil
                let barHeight = calculateHeight(amount: amount, maxHeight: maxHeight)
                let xPosition = step * (CGFloat(index) + 0.5)
                let yPosition = max(18, geometry.size.height - barHeight - 40)

                VStack(spacing: AppSpacing.sm) {
                    Text(months[index])
                        .font(.label)
                        .foregroundColor(AppColors.textSecondary)

                    Text(amount == nil ? "--" : formatMoney(amount ?? 0))
                        .font(.smallLabel)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.vertical, AppSpacing.sm)
                .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.surfaceBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .position(x: xPosition, y: yPosition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let clampedX = min(max(value.location.x, 0), geometry.size.width - 1)
                    let index = Int(clampedX / step)
                    chartHoverIndex = min(max(index, 0), 11)
                }
                .onEnded { _ in
                    chartHoverIndex = nil
                }
        )
        .onTapGesture {
            chartHoverIndex = nil
        }
    }

    private func calculateHeight(amount: Double?, maxHeight: CGFloat) -> CGFloat {
        guard let amount = amount, amount > 0 else { return 20 }
        let ratio = min(amount / maxChartAmount, 1.0)
        return max(20, maxHeight * CGFloat(ratio))
    }

    private func barColor(amount: Double?, isTarget: Bool) -> AnyShapeStyle {
        if amount == nil {
            return AnyShapeStyle(AppColors.surfaceBorder)
        }
        if isTarget {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "#A78BFA"), Color(hex: "#F9A8D4"), Color(hex: "#FCD34D")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(AppColors.surfaceElevated)
    }

    // MARK: - Month Card

    private func monthCard(index: Int) -> some View {
        let amount = index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil
        let isTarget = (amount ?? 0) >= targetAmount
        let hasData = amount != nil

        return VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
            HStack {
                Text(months[index])
                    .font(.smallLabel)
                    .foregroundColor(hasData ? AppColors.textSecondary : AppColors.textTertiary)

                Spacer()

                if isTarget {
                    flameBadge
                }
            }

            if let amount = amount {
                Text("\(formatMoney(amount)) / \(formatMoney(targetAmount))")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textPrimary)
            } else {
                Text("-- / \(formatMoney(targetAmount))")
                    .font(.bodySmallSemibold)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(hasData ? AppColors.surfaceBorder : AppColors.surfaceBorder.opacity(0.5), lineWidth: 1)
        )
        .opacity(hasData ? 1.0 : 0.7)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .onTapGesture {
            beginEditMonth(index: index)
        }
    }

    private var flameBadge: some View {
        LinearGradient(
            colors: [Color(hex: "#A78BFA"), Color(hex: "#F9A8D4"), Color(hex: "#FCD34D")],
            startPoint: .top,
            endPoint: .bottom
        )
        .mask(
            FlameIcon(size: 16, color: AppColors.textPrimary)
        )
        .frame(width: 16, height: 16)
    }

    private func beginEditMonth(index: Int) {
        editingMonthIndex = index
        editingAmount = (index < currentMonthlyAmounts.count ? currentMonthlyAmounts[index] : nil) ?? 0
        isShowingEditSheet = true
    }

    private func applyEditedAmount() {
        guard let index = editingMonthIndex else { return }
        var amounts = monthlyAmountsByYear[selectedYear] ?? Array(repeating: nil, count: 12)
        if editingAmount > 0 {
            amounts[index] = editingAmount
        } else {
            amounts[index] = nil
        }
        monthlyAmountsByYear[selectedYear] = amounts
    }

    // MARK: - Helper

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    SavingsTargetDetailView2(
        savingsRatioPercent: MockData.apiMonthlyBudget.savingsRatio,
        savingsBudgetTarget: MockData.apiMonthlyBudget.savingsBudget,
        monthlyAmountsByYear: MockData.savingsByYear
    )
}

/// Home → Plan → 储蓄全屏：无父级传入 `apiBudget` 时在内部拉取当月预算（与 `CashflowView` 显式传入二选一）。
struct SavingsTargetDetailView2Container: View {
    @Environment(PlaidManager.self) private var plaidManager
    @State private var apiBudget = APIMonthlyBudget.empty
    @State private var monthlyAmountsByYear: [Int: [Double?]] = CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()

    var body: some View {
        SavingsTargetDetailView2(
            savingsRatioPercent: apiBudget.savingsRatio,
            savingsBudgetTarget: apiBudget.savingsBudget,
            monthlyAmountsByYear: monthlyAmountsByYear
        )
        .task {
            await loadBudgetAndSavingsSeries()
        }
    }

    private func loadBudgetAndSavingsSeries() async {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let month = f.string(from: Date())
        async let budgetResult = try? await APIService.shared.getMonthlyBudget(month: month)
        async let savingsSeries = loadSavingsByYearFromAPI()
        let (b, series) = await (budgetResult, savingsSeries)
        if let b { apiBudget = b }
        if let series {
            monthlyAmountsByYear = series
        } else {
            monthlyAmountsByYear = CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()
        }
    }

    /// 已连接银行时用多月份 `get-spending-summary` 推导每月储蓄；否则为当年全 nil 序列（非 Mock）。
    private func loadSavingsByYearFromAPI() async -> [Int: [Double?]]? {
        guard plaidManager.hasLinkedBank else { return nil }
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
        guard !summaries.isEmpty else { return nil }
        return CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
    }
}
```

---

## View/Investment/InvestmentView.swift

```swift
//
//  InvestmentView.swift
//  Flamora app
//
//  Investment overview page
//

import SwiftUI

struct InvestmentView: View {
    @Environment(PlaidManager.self) private var plaidManager

    @State private var apiNetWorth: APINetWorthSummary? = nil
    /// 来自 `get-investment-holdings`；断连或未拉取成功时为 nil。
    @State private var apiHoldingsPayload: APIInvestmentHoldingsPayload?

    var body: some View {
        connectedView
    }

    var connectedView: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        PortfolioCard(
                            portfolioBalance: portfolioBalanceDisplay,
                            gainAmount: apiNetWorth?.growthAmount ?? 0,
                            gainPercentage: apiNetWorth?.growthPercentage ?? 0,
                            isConnected: plaidManager.hasLinkedBank,
                            onConnectTapped: {
                                Task { await plaidManager.startLinkFlow() }
                            }
                        )

                        AssetAllocationCard(
                            allocation: displayAllocation,
                            isConnected: plaidManager.hasLinkedBank,
                            holdingsPayload: apiHoldingsPayload,
                            cashBankAccounts: cashBankAccounts
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        AccountsCard(
                            accounts: computedAccounts,
                            isConnected: plaidManager.hasLinkedBank,
                            onAddAccount: { Task { await plaidManager.startLinkFlow() } }
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .onAppear {
            if apiNetWorth == nil {
                apiNetWorth = TabContentCache.shared.investmentNetWorth
            }
        }
        .task {
            await loadInvestmentData()
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadInvestmentData() }
        }
    }
}

// MARK: - Data Loading & Computed Data
private extension InvestmentView {
    /// Investment Tab 主数字优先用净资产里的「投资账户」合计，与持仓 API 一致。
    var portfolioBalanceDisplay: Double {
        guard let nw = apiNetWorth else { return 0 }
        if let inv = nw.breakdown.investmentTotal, inv > 0 {
            return inv
        }
        return nw.totalNetWorth
    }

    /// 未连接：零占位；已连接：用 `get-investment-holdings` 聚合；拉取失败：零占位。
    var displayAllocation: Allocation {
        guard plaidManager.hasLinkedBank else {
            return InvestmentAllocationBuilder.zeroAllocation
        }
        guard let p = apiHoldingsPayload else {
            return InvestmentAllocationBuilder.zeroAllocation
        }
        return InvestmentAllocationBuilder.allocation(from: p)
    }

    var cashBankAccounts: [Account] {
        computedAccounts.filter { $0.accountType == .bank }
    }

    func loadInvestmentData() async {
        guard plaidManager.hasLinkedBank else {
            apiNetWorth = nil
            apiHoldingsPayload = nil
            TabContentCache.shared.setInvestmentNetWorth(nil)
            return
        }
        let nw = await fetchNetWorth()
        apiNetWorth = nw
        TabContentCache.shared.setInvestmentNetWorth(nw)
        apiHoldingsPayload = await fetchHoldingsPayload()
    }

    private func fetchHoldingsPayload() async -> APIInvestmentHoldingsPayload? {
        try? await APIService.shared.getInvestmentHoldings()
    }

    // async let + try? 组合会触发 Swift runtime crash (swift_task_dealloc)
    // 将 try? 包裹在独立函数中避免此问题
    private func fetchNetWorth() async -> APINetWorthSummary? {
        do {
            return try await APIService.shared.getNetWorthSummary()
        } catch {
            print("❌ [InvestmentView] getNetWorthSummary decode/network: \(error)")
            return nil
        }
    }

    var computedAccounts: [Account] {
        guard let nw = apiNetWorth, !nw.accounts.isEmpty else { return [] }
        return nw.accounts.map { Account.fromNetWorthAccount($0) }
    }
}

#Preview {
    InvestmentView()
        .environment(PlaidManager.shared)
}
```

---

## View/Journey/JourneyView.swift

```swift
//
//  JourneyView.swift
//  Flamora app
//
//  Journey 主页面 - 参考图风格重排
//

import SwiftUI

// MARK: - Daily Quote Data

private let dailyQuotes: [String] = [
    "It's not about being rich\nIt's about being free.",
    "Financial freedom is available to those who learn about it and work for it.",
    "Do not save what is left after spending,\nbut spend what is left after saving."
]

struct JourneyView: View {
    @State private var netWorthSummary = APINetWorthSummary.empty
    @State private var apiBudget = APIMonthlyBudget.empty
    @State private var fireGoal: APIFireGoal? = nil
    /// 已连接银行时由 `get-spending-summary` 推导的当年各月储蓄，供 `SavingsRateCard` 迷你图；nil 时迷你图为空柱。
    @State private var savingsByYearForChart: [Int: [Double?]]?
    @State private var quoteIndex: Int = 0
    @State private var quoteVisible: Bool = true
    var onFireTapped: (() -> Void)? = nil
    var onInvestmentTapped: (() -> Void)? = nil
    var onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    let bottomPadding: CGFloat

    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @AppStorage(FlamoraStorageKey.budgetSetupCompleted) private var budgetSetupCompleted: Bool = false

    init(
        bottomPadding: CGFloat = 0,
        onFireTapped: (() -> Void)? = nil,
        onInvestmentTapped: (() -> Void)? = nil,
        onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    ) {
        self.bottomPadding = bottomPadding
        self.onFireTapped = onFireTapped
        self.onInvestmentTapped = onInvestmentTapped
        self.onOpenCashflowDestination = onOpenCashflowDestination
    }

    var body: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        PortfolioCard(
                            portfolioBalance: netWorthSummary.totalNetWorth,
                            gainAmount: netWorthSummary.growthAmount ?? 0,
                            gainPercentage: netWorthSummary.growthPercentage ?? 0,
                            isConnected: plaidManager.hasLinkedBank,
                            onConnectTapped: {
                                guard subscriptionManager.isPremium else {
                                    subscriptionManager.showPaywall = true
                                    return
                                }
                                Task { await plaidManager.startLinkFlow() }
                            }
                        )

                        if quoteVisible {
                            dailyQuoteCard
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Plan")
                                .font(.h4)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.screenPadding)

                            VStack(spacing: AppSpacing.cardGap) {
                                BudgetPlanCard(
                                    apiBudget: apiBudget,
                                    daysLeft: daysLeftInCurrentMonth,
                                    onSetupBudget: { plaidManager.showBudgetSetup = true },
                                    action: { onOpenCashflowDestination?(.totalSpending) }
                                )
                                if hasBudgetData {
                                    SavingsRateCard(
                                        apiBudget: apiBudget,
                                        savingsByYearLookup: savingsByYearForChart,
                                        isConnected: true
                                    ) {
                                        onOpenCashflowDestination?(.savingsOverview)
                                    }
                                }
                            }
                        }
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.bottom, max(bottomPadding, AppSpacing.lg))
                    .padding(.top, AppSpacing.md)
                }
            }
        }
        .animation(nil, value: bottomPadding)
        .task { await loadData() }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            print("📍 [Flow] lastConnectionTime changed")
            Task { await loadData() }
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            print("📍 [Flow] hasLinkedBank changed → \(plaidManager.hasLinkedBank)")
            Task { await loadData() }
        }
    }
}

// MARK: - Calendar helpers

private extension JourneyView {
    /// 当月剩余天数（含今日），替代 MockData 固定值（阶段 0 / 路线图 0.4）。
    var daysLeftInCurrentMonth: Int {
        let cal = Calendar.current
        let now = Date()
        guard let range = cal.range(of: .day, in: .month, for: now) else { return 0 }
        let day = cal.component(.day, from: now)
        return range.count - day + 1
    }
}

// MARK: - Daily Quote

private extension JourneyView {
    var dailyQuoteCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("DAILY QUOTE")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(AppTypography.Tracking.cardHeader)

                Text(dailyQuotes[quoteIndex])
                    .font(.quoteBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(0..<dailyQuotes.count, id: \.self) { i in
                            Capsule()
                                .fill(i == quoteIndex ? AppColors.textPrimary : AppColors.overlayWhiteForegroundSoft)
                                .frame(width: i == quoteIndex ? 20 : 6, height: 3)
                                .animation(.easeInOut(duration: 0.2), value: quoteIndex)
                        }
                    }
                    Text("\(quoteIndex + 1)/\(dailyQuotes.count)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.cardPadding)
            .background(
                GeometryReader { geo in
                    ZStack {
                        Image("AppBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height * 4.0)
                            .offset(y: -geo.size.height * 3.0)
                        LinearGradient(
                            colors: [AppColors.overlayBlackSoft, AppColors.overlayBlackMid],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.dailyQuoteAccent.opacity(0.20), lineWidth: 0.75)
                    .allowsHitTesting(false)
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    quoteIndex = (quoteIndex + 1) % dailyQuotes.count
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.smallLabel)
                    .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.sm + 2)
            .padding(.trailing, AppSpacing.sm + 2)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Data Loading

private extension JourneyView {
    var hasBudgetData: Bool {
        budgetSetupCompleted
        && plaidManager.hasLinkedBank
        && (apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget) > 0
        && apiBudget.selectedPlan != nil
    }

    func loadData() async {
        print("📍 [Flow] loadData started — hasLinkedBank=\(plaidManager.hasLinkedBank)")
        let monthStr = currentMonthString
        async let nwTask = fetchNetWorth()
        async let fireTask = fetchFireGoal()

        guard plaidManager.hasLinkedBank else {
            let (nw, fire) = await (nwTask, fireTask)
            if let nw {
                netWorthSummary = nw
                print("📍 [Flow] net worth loaded (no bank) — accounts: \(nw.accounts.count)")
            } else {
                print("📍 [Flow] ❌ net worth fetch returned nil (no bank)")
            }
            apiBudget = .empty
            fireGoal = fire
            savingsByYearForChart = nil
            print("📍 [Flow] loadData skipped budget fetch — hasLinkedBank=false")
            return
        }

        async let budgetTask = fetchBudget(month: monthStr)
        async let savingsChartTask = fetchSavingsByYearForMiniChart()
        let (nw, budget, fire, savingsLookup) = await (nwTask, budgetTask, fireTask, savingsChartTask)
        if let nw {
            netWorthSummary = nw
            let hasInv = nw.accounts.contains { $0.type == "investment" }
            print("📍 [Flow] net worth loaded — accounts: \(nw.accounts.count), total: \(nw.totalNetWorth), hasInvestment: \(hasInv)")
        } else {
            print("📍 [Flow] ❌ net worth fetch returned nil")
        }
        if let budget {
            apiBudget = budget
            FlamoraStorageKey.migrateBudgetSetupIfNeeded(budget: budget, hasLinkedBank: true)
            print("📍 [Flow] budget loaded — selectedPlan=\(budget.selectedPlan ?? "nil"), needs=\(budget.needsBudget), wants=\(budget.wantsBudget), savings=\(budget.savingsBudget)")
        } else {
            print("📍 [Flow] budget fetch returned nil (no budget in DB for \(monthStr))")
        }
        fireGoal = fire
        savingsByYearForChart = savingsLookup
        print("📍 [Flow] hasBudgetData=\(hasBudgetData), hasLinkedBank=\(plaidManager.hasLinkedBank)")
    }

    /// 与 Cash Flow 同源：多月份 `get-spending-summary` → 每月 max(0, income − spending)。
    private func fetchSavingsByYearForMiniChart() async -> [Int: [Double?]]? {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)
        guard !summaries.isEmpty else { return nil }
        return CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
    }

    private func fetchNetWorth() async -> APINetWorthSummary? {
        do {
            return try await APIService.shared.getNetWorthSummary()
        } catch {
            print("📍 [Flow] ❌ fetchNetWorth error: \(error)")
            return nil
        }
    }
    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }
    private func fetchFireGoal() async -> APIFireGoal? {
        try? await APIService.shared.getActiveFireGoal()
    }

    var currentMonthString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }
}

#Preview {
    JourneyView(onFireTapped: {})
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
```

---

## View/BudgetSetup/BS_ConfirmView.swift

```swift
//
//  BS_ConfirmView.swift
//  Flamora app
//
//  Budget Setup — Step 6: Confirm & Save
//  V2: Budget ring + extra savings compound growth + plan details
//

import SwiftUI

struct BS_ConfirmView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    var onComplete: () -> Void

    private let gradientColors = [Color(hex: "F5C842"), Color(hex: "E88BC4"), Color(hex: "B4A0E5")]
    private let purpleColor = Color(hex: "C084FC")
    private let tealColor = Color(hex: "34D399")
    private let goldColor = Color(hex: "FBBF24")

    @State private var showContent = false
    @State private var ringProgress: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundSecondary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if let plan = viewModel.spendingPlan, let selected = viewModel.selectedPlan {
                        budgetSummaryRing(plan: plan, selectedPlan: selected)
                            .padding(.horizontal, AppSpacing.lg)

                        planDetailsCard(plan: plan, selectedPlan: selected)
                            .padding(.horizontal, AppSpacing.lg)

                        tipCard
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { showContent = true }
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) { ringProgress = 1.0 }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button { viewModel.goBack() } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.sm)

            Text("Your Plan")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Budget Summary Ring

    private func budgetSummaryRing(plan: SpendingPlanResponse, selectedPlan: PlanDetail) -> some View {
        // `fixedBudget` / `flexibleBudget` 为 API 字段名；UI 展示为 Needs / Wants。
        let budgetTotal = plan.fixedBudget.total + plan.flexibleBudget.total
        let needsShare = budgetTotal > 0 ? plan.fixedBudget.total / budgetTotal : 0.5

        return VStack(spacing: AppSpacing.lg) {
            ZStack {
                // Background track
                Circle()
                    .stroke(AppColors.overlayWhiteWash, lineWidth: 20)
                    .frame(width: 200, height: 200)

                // Needs arc (purple) with round caps
                Circle()
                    .trim(from: 0, to: needsShare * ringProgress)
                    .stroke(purpleColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Wants arc (teal) with round caps
                Circle()
                    .trim(from: needsShare * ringProgress, to: ringProgress)
                    .stroke(tealColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: AppSpacing.xs) {
                    Text("MONTHLY BUDGET")
                        .font(.cardHeader)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    Text("$\(formattedInt(selectedPlan.monthlySpend))")
                        .font(.h1)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
            }

            // Legend — side by side
            HStack(spacing: AppSpacing.xl) {
                legendItem(color: purpleColor, label: "Needs", amount: plan.fixedBudget.total)
                legendItem(color: tealColor, label: "Wants", amount: plan.flexibleBudget.total)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String, amount: Double) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(color).frame(width: AppSpacing.sm, height: AppSpacing.sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textSecondary)
                Text("$\(formattedInt(amount))")
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Plan Details Card

    private func planDetailsCard(plan: SpendingPlanResponse, selectedPlan: PlanDetail) -> some View {
        let income = viewModel.spendingStats?.avgMonthlyIncome ?? viewModel.monthlyIncome
        let rows: [(label: String, value: String, isRate: Bool)] = [
            ("Plan", viewModel.selectedPlanName, false),
            ("Monthly income", "$\(formattedInt(income))", false),
            ("Monthly budget", "$\(formattedInt(selectedPlan.monthlySpend))", false),
            ("Monthly savings", "$\(formattedInt(selectedPlan.monthlySave))", false),
            ("Savings rate", formattedPct(selectedPlan.savingsRate), true)
        ]

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(AppColors.overlayWhiteWash)
                        .frame(height: 1)
                }
                HStack {
                    Text(row.label)
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    Spacer()
                    Text(row.value)
                        .font(.bodySmallSemibold)
                        .foregroundStyle(row.isRate ? goldColor : AppColors.textPrimary)
                        .monospacedDigit()
                }
                .padding(.vertical, AppSpacing.sm + AppSpacing.xs)
                .padding(.horizontal, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm + AppSpacing.xs) {
            Text("\u{1F4A1}")
                .font(.bodyRegular)
            Text("You can adjust your budget anytime in Settings.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                .lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [AppColors.backgroundSecondary.opacity(0), AppColors.backgroundSecondary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            VStack(spacing: 0) {
                Button {
                    print("📍 [Flow] Start My Journey tapped")
                    Task {
                        let success = await viewModel.saveFinalBudget()
                        if success {
                            UserDefaults.standard.set(true, forKey: FlamoraStorageKey.budgetSetupCompleted)
                            print("📍 [Flow] saveFinalBudget done, will dismiss")
                            onComplete()
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if viewModel.isSaving {
                            ProgressView().tint(AppColors.textPrimary)
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Start My Journey")
                            .font(.figureSecondarySemibold)
                    }
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .shadow(color: Color(hex: "E88BC4").opacity(0.25), radius: AppSpacing.md, y: AppSpacing.sm)
                }
                .disabled(viewModel.isSaving)

                if let error = viewModel.saveError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                        .padding(.top, AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundSecondary)
        }
    }

    // MARK: - Helpers

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formattedPct(_ value: Double) -> String {
        if value == value.rounded() { return "\(Int(value))%" }
        return String(format: "%.1f%%", value)
    }

    private func formattedCompact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return "\(Int(value / 1_000))K" }
        return formattedInt(value)
    }
}

#Preview {
    BS_ConfirmView(viewModel: BudgetSetupViewModel(), onComplete: {})
}
```

---

## View/BudgetSetup/BS_SpendingBreakdownView.swift

```swift
//
//  BS_SpendingBreakdownView.swift
//  Flamora app
//
//  Budget Setup — Step 3: Where Your Money Goes
//  V2: Donut chart (Needs vs Wants), category detail cards, tip banner
//

import SwiftUI

struct BS_SpendingBreakdownView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var selectedSegment: Segment? = nil
    @State private var showAllNeeds = false
    @State private var showAllWants = false

    private let gradientColors = [Color(hex: "F5C842"), Color(hex: "E88BC4")]
    private let purpleColor = Color(hex: "C084FC")
    private let tealColor = Color(hex: "34D399")

    /// 甜甜圈选中扇区（与 API 字段 `avg_monthly_fixed` / `avg_monthly_flexible` 对应为 Needs / Wants）。
    private enum Segment {
        case needs, wants
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundSecondary.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    donutChartCard
                        .padding(.horizontal, AppSpacing.lg)

                    needsExpensesCard
                        .padding(.horizontal, AppSpacing.lg)

                    wantsSpendingCard
                        .padding(.horizontal, AppSpacing.lg)

                    tipBanner
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button { viewModel.goBack() } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.sm)

            Text("Your Spending Breakdown")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text("We categorized your spending into needs and wants.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Donut Chart Card

    private var donutChartCard: some View {
        let stats = viewModel.spendingStats
        let needsMonthly = stats?.avgMonthlyFixed ?? 0
        let wantsMonthly = stats?.avgMonthlyFlexible ?? 0
        let total = needsMonthly + wantsMonthly
        let needsFrac = total > 0 ? needsMonthly / total : 0.5

        // Full 360° ring with lineCap: .round — rounded caps on each segment's
        // endpoints naturally create a visual gap at the junctions (Apple Fitness style).
        let needsFracCaptured = needsFrac

        let centerLabel: String = {
            switch selectedSegment {
            case .needs: return "NEEDS"
            case .wants: return "WANTS"
            case nil:    return "MONTHLY AVG"
            }
        }()
        let centerAmount: Double = {
            switch selectedSegment {
            case .needs: return needsMonthly
            case .wants: return wantsMonthly
            case nil:    return total
            }
        }()

        return VStack(spacing: AppSpacing.lg) {
            ZStack {
                // Background track (full ring, very subtle)
                Circle()
                    .stroke(AppColors.overlayWhiteWash, lineWidth: 20)
                    .frame(width: 170, height: 170)

                // Needs arc (purple) — rounded caps
                Circle()
                    .trim(from: 0, to: needsFracCaptured)
                    .stroke(
                        purpleColor.opacity(selectedSegment == .wants ? 0.2 : 1),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))

                // Wants arc (teal) — rounded caps
                Circle()
                    .trim(from: needsFracCaptured, to: 1.0)
                    .stroke(
                        tealColor.opacity(selectedSegment == .needs ? 0.2 : 1),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))

                // Center text: label above, amount below
                VStack(spacing: AppSpacing.xs) {
                    Text(centerLabel)
                        .font(.label)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    Text("$\(formattedInt(centerAmount))")
                        .font(.h2)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
                .animation(.easeOut(duration: 0.2), value: selectedSegment)

                // Invisible center hit area — tap to deselect
                Circle()
                    .fill(Color.clear)
                    .frame(width: 122, height: 122)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) { selectedSegment = nil }
                    }
            }
            .animation(.easeOut(duration: 0.2), value: selectedSegment)

            // Clickable legend (also tap the arc colors to select)
            HStack(spacing: AppSpacing.lg) {
                legendButton(color: purpleColor, label: "Needs", amount: needsMonthly, segment: .needs)
                legendButton(color: tealColor, label: "Wants", amount: wantsMonthly, segment: .wants)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func legendButton(color: Color, label: String, amount: Double, segment: Segment) -> some View {
        let isSelected = selectedSegment == segment
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedSegment = isSelected ? nil : segment
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Circle().fill(color).frame(width: AppSpacing.sm, height: AppSpacing.sm)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("$\(formattedInt(amount))")
                        .font(.statRowSemibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? color.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Needs（数据来自 API `fixed_expenses` / avg_monthly_fixed）

    private var needsExpensesCard: some View {
        let allItems = (viewModel.spendingStats?.fixedExpenses ?? [])
            .sorted { $0.avgMonthlyAmount > $1.avgMonthlyAmount }
        let total = viewModel.spendingStats?.avgMonthlyFixed ?? 0
        let maxAmount = allItems.map(\.avgMonthlyAmount).max() ?? 1
        let visibleItems = showAllNeeds ? allItems : Array(allItems.prefix(4))
        let hasMore = allItems.count > 4

        return VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
            HStack {
                HStack(spacing: AppSpacing.sm) {
                    Circle().fill(purpleColor).frame(width: AppSpacing.sm, height: AppSpacing.sm)
                    Text("Needs")
                        .font(.figureSecondarySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                Text("$\(formattedInt(total))")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }

            ForEach(visibleItems) { item in
                categoryRow(
                    emoji: CategoryDisplay.emoji(item.name),
                    name: CategoryDisplay.displayName(item.name),
                    amount: item.avgMonthlyAmount,
                    maxAmount: maxAmount,
                    barColor: purpleColor
                )
            }

            if hasMore {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { showAllNeeds.toggle() }
                } label: {
                    Text(showAllNeeds ? "See less ∧" : "See more ∨")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Wants（数据来自 API `flexible_breakdown` / avg_monthly_flexible）

    private var wantsSpendingCard: some View {
        let allItems = (viewModel.spendingStats?.flexibleBreakdown ?? [])
            .sorted { $0.avgMonthlyAmount > $1.avgMonthlyAmount }
        let total = viewModel.spendingStats?.avgMonthlyFlexible ?? 0
        let maxAmount = allItems.map(\.avgMonthlyAmount).max() ?? 1
        let visibleItems = showAllWants ? allItems : Array(allItems.prefix(5))
        let hasMore = allItems.count > 5

        return VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
            HStack {
                HStack(spacing: AppSpacing.sm) {
                    Circle().fill(tealColor).frame(width: AppSpacing.sm, height: AppSpacing.sm)
                    Text("Wants")
                        .font(.figureSecondarySemibold)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                Text("$\(formattedInt(total))")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
            }

            ForEach(visibleItems) { item in
                categoryRow(
                    emoji: CategoryDisplay.emoji(item.subcategory),
                    name: CategoryDisplay.displayName(item.subcategory),
                    amount: item.avgMonthlyAmount,
                    maxAmount: maxAmount,
                    barColor: tealColor
                )
            }

            if hasMore {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { showAllWants.toggle() }
                } label: {
                    Text(showAllWants ? "See less ∧" : "See more ∨")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func categoryRow(emoji: String, name: String, amount: Double, maxAmount: Double, barColor: Color) -> some View {
        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
            Text(emoji)
                .font(.bodyRegular)
                .frame(width: AppRadius.button)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(name)
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                // Proportional bar below name (use overlay trick to avoid GeometryReader width issues)
                let ratio = maxAmount > 0 ? CGFloat(amount / maxAmount) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.sm / 4)
                        .fill(barColor.opacity(0.08))
                        .frame(maxWidth: .infinity)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: AppRadius.sm / 4)
                            .fill(barColor.opacity(0.35))
                            .frame(width: max(AppSpacing.xs, geo.size.width * ratio))
                    }
                }
                .frame(height: AppSpacing.xs)
            }
            .frame(maxWidth: .infinity)

            Text("$\(formattedInt(amount))")
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Tip Banner

    private var tipBanner: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm + AppSpacing.xs) {
            Text("\u{1F4A1}")
                .font(.bodyRegular)
            Text("Wants spending is where your savings live. In the next steps, we'll show how small reductions here can significantly grow your investments over time.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [AppColors.backgroundSecondary.opacity(0), AppColors.backgroundSecondary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                Task { await viewModel.loadPlans() }
                viewModel.goToStep(.choosePath)
            } label: {
                Text("Continue")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundSecondary)
        }
    }

    // MARK: - Helpers

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

}

#Preview {
    BS_SpendingBreakdownView(viewModel: BudgetSetupViewModel())
}
```

---

## View/Cashflow/CashflowView.swift

```swift
//
//  CashflowView.swift
//  Flamora app
//
//  Saving / Cash Flow summary page
//

import SwiftUI

/// Journey 等入口打开与 Cash Flow 相同的二级全屏页时使用（由 MainTabView 直接 present，不切 Tab）
enum CashflowJourneyDestination: Equatable, Identifiable {
    case totalSpending
    case savingsOverview

    var id: String {
        switch self {
        case .totalSpending: return "totalSpending"
        case .savingsOverview: return "savingsOverview"
        }
    }
}

struct CashflowView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager
    @AppStorage(FlamoraStorageKey.budgetSetupCompleted) private var budgetSetupCompleted: Bool = false

    @State private var apiBudget = APIMonthlyBudget.empty
    /// 当月收入（来自 `get-spending-summary.total_income`；active/passive 尚无拆分时与 total 对齐）。
    @State private var incomeMonthDisplay = Income(total: 0, active: 0, passive: 0, sources: [])
    /// 本年累计收入（多个月 `get-spending-summary` 汇总）；无银行连接时为 nil。
    @State private var incomeYearDisplay: Income?
    @State private var currentSavings: Double = 0
    @State private var needsTotal: Double = 0
    @State private var wantsTotal: Double = 0
    @State private var totalSpend: Double = 0
    @State private var allTransactions: [Transaction] = []
    /// 与 `transaction.accountId` 匹配，供交易详情 Sheet 展示账户行。
    @State private var linkedAccounts: [Account] = []
    @State private var selectedTransaction: Transaction? = nil
    @State private var showAllTransactions = false
    @State private var showSavingsInput = false
    @State private var showSavingsSummary = false
    @State private var showTotalIncomeDetail = false
    @State private var showActiveIncomeDetail = false
    @State private var showPassiveIncomeDetail = false
    @State private var showTotalSpendingDetail = false
    @State private var showNeedsSpendingDetail = false
    @State private var showWantsSpendingDetail = false

    /// 已连接银行时由多月份 `get-spending-summary` 构建；未连接或拉取失败时为 nil，详情页使用空数据（非 Mock）。
    @State private var cashflowSpendingTotalDetail: TotalSpendingDetailData?
    @State private var cashflowNeedsDetail: SpendingDetailData?
    @State private var cashflowWantsDetail: SpendingDetailData?
    @State private var cashflowTotalIncomeDetail: TotalIncomeDetailData?
    @State private var cashflowActiveIncomeDetail: IncomeDetailData?
    @State private var cashflowPassiveIncomeDetail: IncomeDetailData?
    /// 已连接且拉到 summary 时为当年各月储蓄序列；否则 nil → 储蓄全屏用当年全 nil 序列。
    @State private var cashflowSavingsByYear: [Int: [Double?]]?

    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date()) - 1
    }

    private var spendingForDisplay: Spending {
        Spending(
            total: totalSpend,
            needs: needsTotal,
            wants: wantsTotal,
            budgetLimit: apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
        )
    }

    private var hasBudget: Bool {
        budgetSetupCompleted
        && (apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget) > 0
    }

    var body: some View {
        connectedView
    }

    var connectedView: some View {
        ZStack {
            Color.clear

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        IncomeCard(
                            income:          incomeMonthDisplay,
                            yearlyIncome:    incomeYearDisplay,
                            onCardTapped:    { showTotalIncomeDetail = true },
                            onActiveTapped:  { showActiveIncomeDetail = true },
                            onPassiveTapped: { showPassiveIncomeDetail = true },
                            isConnected:     plaidManager.hasLinkedBank
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        SavingsTargetCard(
                            currentAmount: $currentSavings,
                            targetAmount: apiBudget.savingsBudget,
                            isConnected: plaidManager.hasLinkedBank,
                            onAdd: { showSavingsInput = true },
                            onCardTap: { showSavingsSummary = true }
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        BudgetCard(
                            spending: spendingForDisplay,
                            apiBudget: apiBudget,
                            isConnected: plaidManager.hasLinkedBank,
                            hasBudget: hasBudget,
                            onSetupBudget: { plaidManager.showBudgetSetup = true },
                            onCardTapped: { showTotalSpendingDetail = true },
                            onNeedsTapped: { showNeedsSpendingDetail = true },
                            onWantsTapped: { showWantsSpendingDetail = true }
                        )
                        .padding(.horizontal, AppSpacing.screenPadding)

                        transactionsSection
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .task {
            await loadCashflowData()
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await loadCashflowData() }
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadCashflowData() }
        }
        .fullScreenCover(isPresented: $showSavingsSummary) {
            SavingsTargetDetailView2(
                savingsRatioPercent: apiBudget.savingsRatio,
                savingsBudgetTarget: apiBudget.savingsBudget,
                monthlyAmountsByYear: cashflowSavingsByYear ?? CashflowDetailEmptyStates.savingsMonthlyAmountsEmptyCurrentYear()
            )
        }
        .fullScreenCover(isPresented: $showTotalIncomeDetail) {
            TotalIncomeDetailView(
                data: cashflowTotalIncomeDetail ?? .empty,
                initialSelectedMonth: currentMonthIndex
            )
        }
        .fullScreenCover(isPresented: $showActiveIncomeDetail) {
            IncomeDetailView(
                data: cashflowActiveIncomeDetail ?? .emptyActiveIncome,
                initialSelectedMonth: currentMonthIndex
            )
        }
        .fullScreenCover(isPresented: $showPassiveIncomeDetail) {
            IncomeDetailView(
                data: cashflowPassiveIncomeDetail ?? .emptyPassiveIncome,
                initialSelectedMonth: currentMonthIndex
            )
        }
        .fullScreenCover(isPresented: $showTotalSpendingDetail) {
            TotalSpendingAnalysisDetailView(
                data: cashflowSpendingTotalDetail ?? .empty,
                needsDetailData: cashflowNeedsDetail ?? .emptyNeeds,
                wantsDetailData: cashflowWantsDetail ?? .emptyWants
            )
        }
        .fullScreenCover(isPresented: $showNeedsSpendingDetail) {
            SpendingAnalysisDetailView(data: cashflowNeedsDetail ?? .emptyNeeds)
        }
        .fullScreenCover(isPresented: $showWantsSpendingDetail) {
            SpendingAnalysisDetailView(data: cashflowWantsDetail ?? .emptyWants)
        }
        .sheet(isPresented: $showSavingsInput) {
            SavingsInputSheet(amount: $currentSavings)
                .ignoresSafeArea(.container, edges: .bottom)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(AppColors.backgroundPrimary)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction, linkedAccounts: linkedAccounts) { updated in
                updateTransaction(updated)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .presentationDragIndicator(.visible)
            .presentationDetents([.fraction(0.75)])
            .presentationCornerRadius(28)
            .presentationBackground(AppColors.backgroundPrimary)
        }
        .fullScreenCover(isPresented: $showAllTransactions) {
            AllTransactionsView(transactions: $allTransactions, linkedAccounts: linkedAccounts, onUpdate: updateTransaction)
        }
    }
}

// MARK: - Data Loading

private extension CashflowView {
    func loadCashflowData() async {
        let monthStr = apiMonthString(from: Date())

        if !plaidManager.hasLinkedBank {
            apiBudget = .empty
            currentSavings = 0
            needsTotal = 0
            wantsTotal = 0
            totalSpend = 0
            incomeMonthDisplay = Income(total: 0, active: 0, passive: 0, sources: [])
            incomeYearDisplay = nil
            cashflowSpendingTotalDetail = nil
            cashflowNeedsDetail = nil
            cashflowWantsDetail = nil
            cashflowTotalIncomeDetail = nil
            cashflowActiveIncomeDetail = nil
            cashflowPassiveIncomeDetail = nil
            cashflowSavingsByYear = nil
            allTransactions = []
            linkedAccounts = []
            return
        }

        if let b = await fetchBudget(month: monthStr) {
            apiBudget = b
            FlamoraStorageKey.migrateBudgetSetupIfNeeded(budget: b, hasLinkedBank: true)
            currentSavings = b.savingsActual ?? 0
            needsTotal = b.needsSpent ?? 0
            wantsTotal = b.wantsSpent ?? 0
            totalSpend = (b.needsSpent ?? 0) + (b.wantsSpent ?? 0)
        }

        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let through = cal.component(.month, from: Date())
        let summaries = await CashflowAPICharts.fetchMonthlySummaries(year: year, throughMonth: through)

        if let cur = summaries[through - 1] {
            needsTotal = cur.needs.total
            wantsTotal = cur.wants.total
            totalSpend = cur.totalSpending
            let inc = cur.totalIncome
            incomeMonthDisplay = Income(total: inc, active: inc, passive: 0, sources: [])
            let ytd = summaries.values.reduce(0) { $0 + $1.totalIncome }
            incomeYearDisplay = Income(total: ytd, active: ytd, passive: 0, sources: [])
        } else {
            incomeMonthDisplay = Income(total: 0, active: 0, passive: 0, sources: [])
            incomeYearDisplay = nil
        }

        if !summaries.isEmpty {
            cashflowSpendingTotalDetail = CashflowAPICharts.totalSpendingDetail(summaries: summaries, year: year)
            cashflowNeedsDetail = CashflowAPICharts.needsSpendingDetail(summaries: summaries, year: year)
            cashflowWantsDetail = CashflowAPICharts.wantsSpendingDetail(summaries: summaries, year: year)
            cashflowTotalIncomeDetail = CashflowAPICharts.totalIncomeDetail(summaries: summaries, year: year)
            cashflowActiveIncomeDetail = CashflowAPICharts.activeIncomeDetail(summaries: summaries, year: year)
            cashflowPassiveIncomeDetail = CashflowAPICharts.passiveIncomeDetail(summaries: summaries, year: year)
            cashflowSavingsByYear = CashflowAPICharts.savingsMonthlyAmountsByYear(summaries: summaries, year: year)
        } else {
            cashflowSpendingTotalDetail = nil
            cashflowNeedsDetail = nil
            cashflowWantsDetail = nil
            cashflowTotalIncomeDetail = nil
            cashflowActiveIncomeDetail = nil
            cashflowPassiveIncomeDetail = nil
            cashflowSavingsByYear = nil
        }

        if let tx = try? await APIService.shared.getTransactions(page: 1, limit: 20) {
            allTransactions = tx.transactions.map { Transaction(from: $0) }
        }

        if let nw = try? await APIService.shared.getNetWorthSummary() {
            linkedAccounts = nw.accounts.map { Account.fromNetWorthAccount($0) }
        } else {
            linkedAccounts = []
        }
    }

    private func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }

    func apiMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}

// MARK: - Transactions

private extension CashflowView {
    var transactionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
            HStack {
                Text("TRANSACTIONS")
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.textPrimary)
                    .tracking(0.6)

                Spacer()

                if plaidManager.hasLinkedBank {
                    Button(action: { showAllTransactions = true }) {
                        Text("SEE ALL")
                            .font(.smallLabel)
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(0.4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            if plaidManager.hasLinkedBank {
                ForEach(allTransactions.sorted {
                    if $0.date != $1.date { return $0.date > $1.date }
                    return ($0.time ?? "") > ($1.time ?? "")
                }.prefix(5)) { transaction in
                    TransactionRow(transaction: transaction) {
                        selectedTransaction = transaction
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
            } else {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary.opacity(0.45))
                    Text("Connect accounts to see your transactions")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.vertical, AppSpacing.md)
            }
        }
        .padding(.top, 4)
    }

    func updateTransaction(_ updated: Transaction) {
        guard let index = allTransactions.firstIndex(where: { $0.id == updated.id }) else { return }
        let old = allTransactions[index]

        // Adjust running totals when category changes (category is derived from subcategory)
        if old.category != updated.category {
            if old.category == "needs"      { needsTotal -= old.amount }
            else if old.category == "wants" { wantsTotal -= old.amount }
            else                            { totalSpend += updated.amount }

            if updated.category == "needs"      { needsTotal += updated.amount }
            else if updated.category == "wants" { wantsTotal += updated.amount }
            else                                { totalSpend -= updated.amount }
        }

        allTransactions[index] = updated
    }
}

// TransactionRow is defined in TransactionRow.swift

#Preview {
    CashflowView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
```

---

## View/Cashflow/IncomeCard.swift

```swift
//
//  IncomeCard.swift
//  Flamora app
//
//  Donut-style Total Income card
//  Active Income  →  AppColors.accentGreenDeep  (large arc)
//  Passive Income →  AppColors.accentPurpleMid (small arc)
//
//  Monthly / YTD values come from `CashflowView` → `get-spending-summary` (total_income).
//  Active vs passive split pending dedicated income API (roadmap 2A).
//

import SwiftUI

struct IncomeCard: View {

    /// Current month income (from spending summary `total_income`).
    let income: Income
    /// YTD income (sum of monthly summaries); nil falls back to `income` in UI.
    var yearlyIncome: Income? = nil

    var onCardTapped:    (() -> Void)? = nil
    var onActiveTapped:  (() -> Void)? = nil
    var onPassiveTapped: (() -> Void)? = nil
    /// Called when the period toggle changes — lets parent reload data
    var onPeriodChanged: ((Bool) -> Void)? = nil   // true = year, false = month
    var isConnected: Bool = true

    // MARK: – Internal state

    @State private var period: Period = .month

    private enum Period { case month, year }

    // MARK: – Design tokens

    private let activeColor  = AppColors.accentGreenDeep
    private let passiveColor = AppColors.accentPurpleMid
    private let ringWidth: CGFloat = 14

    // MARK: – Derived values

    /// The Income object currently displayed (switches on toggle)
    private var displayed: Income {
        (period == .year ? yearlyIncome : nil) ?? income
    }

    private var activeFraction: Double {
        displayed.total > 0 ? max(0.01, displayed.active  / displayed.total) : 0.85
    }
    private var passiveFraction: Double {
        displayed.total > 0 ? max(0.01, displayed.passive / displayed.total) : 0.12
    }

    // Label shown inside the donut center
    private var centerSubLabel: String {
        period == .year ? "YTD \(currentYear)" : shortMonthLabel
    }

    // Label shown below the period toggle
    private var periodRangeLabel: String {
        period == .year ? yearRangeLabel : fullMonthLabel
    }

    private var shortMonthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return f.string(from: Date())
    }
    private var fullMonthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }
    private var yearRangeLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "Jan 1 – \(f.string(from: Date())), \(currentYear)"
    }
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    // MARK: – Body

    var body: some View {
        VStack(spacing: 0) {
            if isConnected {
                donutSection
                    .padding(.top, AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.xs)

                divider

                VStack(spacing: AppSpacing.xs) {
                    periodToggle
                    periodLabel
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.cardPadding)
            } else {
                disconnectedIncomePlaceholder
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    private var disconnectedIncomePlaceholder: some View {
        VStack(spacing: 0) {
            HStack { Spacer() }
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.cardPadding)

            ZStack {
                Circle()
                    .stroke(AppColors.progressTrack, lineWidth: ringWidth)
                    .opacity(0.35)
                    .frame(width: 200, height: 200)
                VStack(spacing: AppSpacing.xs) {
                    Text("Total Income")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.textTertiary)
                    Text("$—")
                        .font(.cardFigurePrimary)
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Connect accounts to see income")
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 200, height: 200)

            HStack { Spacer() }
                .frame(height: 44)
                .padding(.horizontal, AppSpacing.cardPadding)

            divider

            VStack(spacing: AppSpacing.xs) {
                periodToggle
                    .opacity(0.35)
                    .allowsHitTesting(false)
                periodLabel
                    .opacity(0.35)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.cardPadding)
        }
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: – Donut section

    private var donutSection: some View {
        VStack(spacing: 0) {

            // ── Passive label (top-trailing) ──────────────────────────────
            HStack {
                Spacer()
                Button { onPassiveTapped?() } label: {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(formatAmount(displayed.passive))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(passiveColor)
                                .frame(width: 6, height: 6)
                            Text("Passive")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 44)
            .padding(.horizontal, AppSpacing.cardPadding)

            // ── Donut ring + tappable center ──────────────────────────────
            ZStack {
                donutRings

                Button { onCardTapped?() } label: {
                    VStack(spacing: 4) {
                        Text("Total Income")
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.textTertiary)
                        Text(formatAmount(displayed.total))
                            .font(.cardFigurePrimary)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(centerSubLabel)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 200, height: 200)

            // ── Active label (bottom-left) ────────────────────────────────
            HStack {
                Button { onActiveTapped?() } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formatAmount(displayed.active))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)
                        HStack(spacing: 5) {
                            Circle()
                                .fill(activeColor)
                                .frame(width: 6, height: 6)
                            Text("Active")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, AppSpacing.cardPadding)
        }
    }

    // MARK: – Donut rings

    private var donutRings: some View {
        // halfGap applied symmetrically on both sides of every endpoint
        // → both gaps (active↔passive and passive↔active) become exactly 2×halfGap
        let halfGap = 0.015   // 2×halfGap ≈ 10.8° per gap, both gaps equal
        let pf = passiveFraction

        return ZStack {
            // Background track
            Circle()
                .stroke(AppColors.surfaceInput, lineWidth: ringWidth)
                .opacity(0.4)

            // Active arc (large – clockwise after passive segment)
            Circle()
                .trim(
                    from: pf + halfGap,
                    to:   max(pf + halfGap + 0.01, 1.0 - halfGap)
                )
                .stroke(
                    LinearGradient(
                        colors: [activeColor.opacity(0.75), activeColor],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Passive arc (small – at 12 o'clock)
            Circle()
                .trim(
                    from: halfGap,
                    to:   max(halfGap + 0.01, pf - halfGap)
                )
                .stroke(passiveColor,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 200, height: 200)
        .padding(ringWidth * 0.5)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    // Center of the 214×214 view (200 + 2×7 padding)
                    let center = CGPoint(x: 107, y: 107)
                    let dx = Double(value.location.x - center.x)
                    let dy = Double(value.location.y - center.y)
                    let distance = sqrt(dx * dx + dy * dy)
                    // Only respond to taps in the ring band (skip center button area)
                    guard distance > 60 && distance < 115 else { return }
                    // Convert to clockwise angle from 12 o'clock, normalized [0, 1)
                    var deg = atan2(dy, dx) * 180 / .pi
                    deg = (deg + 90 + 360).truncatingRemainder(dividingBy: 360)
                    let normalized = deg / 360.0
                    if normalized < pf {
                        onPassiveTapped?()
                    } else {
                        onActiveTapped?()
                    }
                }
        )
    }

    // MARK: – Divider

    private var divider: some View {
        Rectangle()
            .fill(AppColors.surfaceBorder)
            .frame(height: 0.5)
            .padding(.horizontal, AppSpacing.cardPadding)
    }

    // MARK: – Period toggle

    private var periodToggle: some View {
        HStack(spacing: 2) {
            togglePill("This Month", selected: period == .month) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    period = .month
                    onPeriodChanged?(false)
                }
            }
            togglePill("This Year", selected: period == .year) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    period = .year
                    onPeriodChanged?(true)
                }
            }
        }
        .padding(3)
        .background(AppColors.surfaceInput)
        .clipShape(Capsule())
    }

    private func togglePill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.inlineLabel)
                .foregroundColor(selected ? AppColors.textInverse : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xs + 2)
                .background(
                    Capsule().fill(selected ? AppColors.textPrimary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: – Period label (below toggle)

    private var periodLabel: some View {
        Text(periodRangeLabel)
            .font(.footnoteRegular)
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: – Formatter

    private func formatAmount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle           = .currency
        f.currencyCode          = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        IncomeCard(
            income:       MockData.cashflowData.income,
            yearlyIncome: MockData.yearlyIncome,
            onCardTapped:    {},
            onActiveTapped:  {},
            onPassiveTapped: {}
        )
        .padding(AppSpacing.md)
    }
}
```

---

## View/Journey/SavingsRateCard.swift

```swift
//
//  SavingsRateCard.swift
//  Flamora app
//

import SwiftUI

struct SavingsRateCard: View {
    let apiBudget: APIMonthlyBudget
    /// 若提供（例如 Home 已拉取当年 summary），迷你图按年+月查储蓄；否则六根柱均为空（无假数据）。
    var savingsByYearLookup: [Int: [Double?]]? = nil
    var isConnected: Bool = true
    var action: (() -> Void)? = nil

    private var totalBudget: Double {
        apiBudget.needsBudget + apiBudget.wantsBudget + apiBudget.savingsBudget
    }
    private var actualRate: Double {
        totalBudget > 0 ? (apiBudget.savingsActual ?? 0) / totalBudget : 0
    }
    private var actualPct: Int { Int((actualRate * 100).rounded()) }
    private var savedAmount: Double { apiBudget.savingsActual ?? 0 }
    private var targetAmount: Double { apiBudget.savingsBudget }

    var body: some View {
        Button(action: { if isConnected { action?() } }) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SAVINGS RATE")
                        .font(.cardHeader)
                        .foregroundColor(AppColors.textTertiary)
                        .tracking(AppTypography.Tracking.cardHeader)
                    Spacer()
                    HStack(spacing: 3) {
                        Text(currentMonthLabel)
                            .font(.cardHeader)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(AppTypography.Tracking.cardHeader)
                        if isConnected {
                            Image(systemName: "chevron.right")
                                .font(.miniLabel)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.top, AppSpacing.cardPadding)
                .padding(.bottom, 12)

                Rectangle()
                    .fill(AppColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, AppSpacing.cardPadding)

                // Content
                if isConnected {
                    HStack(alignment: .bottom, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(actualPct)%")
                                .font(.cardFigurePrimary)
                                .foregroundStyle(AppColors.textPrimary)
                            Text("Saved \(formatCurrency(savedAmount)) this month")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        GeometryReader { geo in
                            miniChart(height: geo.size.height)
                        }
                        .frame(width: 110)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.cardPadding)
                } else {
                    HStack(alignment: .bottom, spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("—%")
                                .font(.cardFigurePrimary)
                                .foregroundStyle(AppColors.textTertiary)
                            Text("Connect accounts to track savings rate")
                                .font(.footnoteRegular)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                            ForEach(0..<6, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColors.surfaceBorder)
                                    .frame(width: 6, height: CGFloat.random(in: 8...32))
                            }
                        }
                        .frame(width: 110)
                        .opacity(0.35)
                    }
                    .padding(.horizontal, AppSpacing.cardPadding)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.cardPadding)
                }
            }
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    // MARK: - Mini Chart

    private func miniChart(height: CGFloat) -> some View {
        let entries = last6MonthsSavings()
        // Scale so the tallest bar among the six uses full `height` (not targetAmount / first column).
        let dataMax = entries.compactMap { $0.0 }.max() ?? 0
        let scaleMax = max(dataMax, 1)

        return HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            ForEach(0..<6, id: \.self) { i in
                let (amount, metTarget) = entries[i]
                let barHeight: CGFloat = amount == nil
                    ? 4
                    : max(4, height * CGFloat((amount ?? 0) / scaleMax))

                RoundedRectangle(cornerRadius: 3)
                    .fill(barFill(amount: amount, metTarget: metTarget))
                    .frame(width: 6, height: barHeight)
            }
        }
        .frame(width: 110, height: height, alignment: .trailing)
    }

    // MARK: - Helpers

    private func last6MonthsSavings() -> [(Double?, Bool)] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now) - 1

        let lookup = savingsByYearLookup ?? [:]
        return (0..<6).map { offset in
            var month = currentMonth - (5 - offset)
            var year = currentYear
            if month < 0 { month += 12; year -= 1 }
            let amount = lookup[year]?[month]
            return (amount, (amount ?? 0) >= targetAmount)
        }
    }

    private func barFill(amount: Double?, metTarget: Bool) -> AnyShapeStyle {
        guard amount != nil else {
            return AnyShapeStyle(AppColors.surfaceBorder)
        }
        if metTarget {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "#A78BFA"), Color(hex: "#F9A8D4"), Color(hex: "#FCD34D")],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        return AnyShapeStyle(AppColors.surfaceElevated)
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    ZStack {
        AppColors.backgroundPrimary.ignoresSafeArea()
        SavingsRateCard(apiBudget: .empty, savingsByYearLookup: nil)
    }
}
```
