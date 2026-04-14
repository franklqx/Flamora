//
//  BudgetCard.swift
//  Flamora app
//

import SwiftUI

struct BudgetEditPayload {
    let needsBudget: Double
    let wantsBudget: Double
    let needsRatio: Double
    let wantsRatio: Double
    let categoryBudgets: [String: Double]
}

struct BudgetCategoryBudget: Identifiable, Hashable {
    let id: String
    let name: String
    let parent: BudgetScope
    var amount: Double
    var spent: Double

    init(name: String, parent: BudgetScope, amount: Double, spent: Double = 0) {
        self.id = "\(parent.rawValue)-\(name)"
        self.name = name
        self.parent = parent
        self.amount = amount
        self.spent = spent
    }
}

enum BudgetScope: String, CaseIterable, Identifiable {
    case all = "All"
    case needs = "Needs"
    case wants = "Wants"

    var id: String { rawValue }
}

struct BudgetCard: View {
    let spending: Spending
    let apiBudget: APIMonthlyBudget
    var isConnected: Bool = true
    var hasBudget: Bool = true
    var onSetupBudget: (() -> Void)? = nil
    let onCardTapped: (() -> Void)?
    let onNeedsTapped: (() -> Void)?
    let onWantsTapped: (() -> Void)?
    var needsCategories: [BudgetCategoryBudget] = []
    var wantsCategories: [BudgetCategoryBudget] = []
    var onSaveBudget: ((BudgetEditPayload) async -> Bool)? = nil

    @State private var selectedScope: BudgetScope = .all
    @State private var isEditingBudget = false
    @State private var isSaving = false

    @State private var draftNeedsBudget: Double = 0
    @State private var draftWantsBudget: Double = 0
    @State private var draftNeedsCategories: [BudgetCategoryBudget] = []
    @State private var draftWantsCategories: [BudgetCategoryBudget] = []

    private let tolerance: Double = 0.01
    private let needsWantsDisplayHeight: CGFloat = 456
    private let allDisplayHeightDelta: CGFloat = 68
    private let ringSectionHeight: CGFloat = 178
    private let needsWantsScopeSectionHeight: CGFloat = 176
    private let allScopeSectionHeightDelta: CGFloat = 64

    private var needsColor: Color { AppColors.budgetNeedsBlue }
    private var wantsColor: Color { AppColors.budgetWantsPurple }
    private var overBudgetColor: Color { AppColors.error }
    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var totalBudget: Double { max(apiBudget.needsBudget + apiBudget.wantsBudget, 0) }
    private var totalSpent: Double { max(spending.needs + spending.wants, 0) }
    private var isOverBudget: Bool { totalBudget > 0 && (totalSpent / totalBudget) > 1.0 }
    private var normalizedNeedsCategories: [BudgetCategoryBudget] {
        normalizedCategories(
            source: needsCategories,
            parent: .needs,
            defaults: TransactionCategoryCatalog.needsCategories.map(\.name) + ["Other Needs"],
            desiredCount: 6
        )
    }
    private var normalizedWantsCategories: [BudgetCategoryBudget] {
        normalizedCategories(
            source: wantsCategories,
            parent: .wants,
            defaults: TransactionCategoryCatalog.wantsCategories.map(\.name) + ["Other Wants"],
            desiredCount: 6
        )
    }

    private var draftTotalBudget: Double {
        max(draftNeedsBudget + draftWantsBudget, 0)
    }

    private func displayHeight(for scope: BudgetScope) -> CGFloat {
        switch scope {
        case .all:
            return max(needsWantsDisplayHeight - allDisplayHeightDelta, 0)
        case .needs, .wants:
            return needsWantsDisplayHeight
        }
    }

    private func scopeSectionHeight(for scope: BudgetScope) -> CGFloat {
        switch scope {
        case .all:
            return max(needsWantsScopeSectionHeight - allScopeSectionHeightDelta, 0)
        case .needs, .wants:
            return needsWantsScopeSectionHeight
        }
    }

    private var needsCategorySum: Double {
        draftNeedsCategories.reduce(0) { $0 + max($1.amount, 0) }
    }

    private var wantsCategorySum: Double {
        draftWantsCategories.reduce(0) { $0 + max($1.amount, 0) }
    }

    private var draftIsValid: Bool {
        draftNeedsBudget >= 0
        && draftWantsBudget >= 0
        && abs(needsCategorySum - draftNeedsBudget) <= tolerance
        && abs(wantsCategorySum - draftWantsBudget) <= tolerance
        && abs((draftNeedsBudget + draftWantsBudget) - draftTotalBudget) <= tolerance
    }

    private var validationMessage: String? {
        if abs(needsCategorySum - draftNeedsBudget) > tolerance {
            let delta = needsCategorySum - draftNeedsBudget
            return "Needs categories differ by \(formatSignedCurrency(delta))."
        }
        if abs(wantsCategorySum - draftWantsBudget) > tolerance {
            let delta = wantsCategorySum - draftWantsBudget
            return "Wants categories differ by \(formatSignedCurrency(delta))."
        }
        return nil
    }

    init(
        spending: Spending,
        apiBudget: APIMonthlyBudget,
        isConnected: Bool = true,
        hasBudget: Bool = true,
        onSetupBudget: (() -> Void)? = nil,
        onCardTapped: (() -> Void)? = nil,
        onNeedsTapped: (() -> Void)? = nil,
        onWantsTapped: (() -> Void)? = nil,
        needsCategories: [BudgetCategoryBudget] = [],
        wantsCategories: [BudgetCategoryBudget] = [],
        onSaveBudget: ((BudgetEditPayload) async -> Bool)? = nil
    ) {
        self.spending = spending
        self.apiBudget = apiBudget
        self.isConnected = isConnected
        self.hasBudget = hasBudget
        self.onSetupBudget = onSetupBudget
        self.onCardTapped = onCardTapped
        self.onNeedsTapped = onNeedsTapped
        self.onWantsTapped = onWantsTapped
        self.needsCategories = needsCategories
        self.wantsCategories = wantsCategories
        self.onSaveBudget = onSaveBudget
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(AppColors.inkDivider)
                .frame(height: 0.5)
                .padding(.horizontal, AppSpacing.cardPadding)

            if !isConnected {
                lockedEmptyState
            } else if hasBudget {
                if isEditingBudget {
                    budgetContentArea
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                } else {
                    budgetContentArea
                        .frame(height: displayHeight(for: selectedScope), alignment: .top)
                        .padding(.horizontal, AppSpacing.cardPadding)
                        .padding(.vertical, AppSpacing.md)
                        .animation(.easeOut(duration: 0.2), value: selectedScope)
                }
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
        .onAppear {
            resetDraftFromCurrent()
        }
        .onChange(of: apiBudget.budgetId) { _, _ in
            if !isEditingBudget { resetDraftFromCurrent() }
        }
    }

    private var header: some View {
        HStack {
            Text("BUDGET")
                .font(.cardHeader)
                .foregroundColor(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)

            Spacer()

            HStack(spacing: AppSpacing.xs) {
                Text(currentMonthLabel)
                    .font(.cardHeader)
                    .foregroundColor(AppColors.inkFaint)
                    .tracking(AppTypography.Tracking.cardHeader)
                if isConnected && hasBudget && !isEditingBudget {
                    Image(systemName: "chevron.right")
                        .font(.miniLabel)
                        .foregroundColor(AppColors.inkFaint)
                }
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.cardPadding)
        .padding(.bottom, AppSpacing.sm + AppSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            if isConnected && hasBudget && !isEditingBudget { onCardTapped?() }
        }
    }

    @ViewBuilder
    private var budgetContentArea: some View {
        if isEditingBudget {
            budgetEditSection
        } else {
            budgetDisplaySection
        }
    }

    private var budgetDisplaySection: some View {
        VStack(spacing: AppSpacing.md) {
            scopePill
            ringSection
                .frame(height: ringSectionHeight, alignment: .top)
            scopeSection
        }
    }

    private var scopeSection: some View {
        ZStack(alignment: .topLeading) {
            allScopeSection
                .opacity(selectedScope == .all ? 1 : 0)
                .allowsHitTesting(selectedScope == .all)

            needsScopeSection
                .opacity(selectedScope == .needs ? 1 : 0)
                .allowsHitTesting(selectedScope == .needs)

            wantsScopeSection
                .opacity(selectedScope == .wants ? 1 : 0)
                .allowsHitTesting(selectedScope == .wants)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: scopeSectionHeight(for: selectedScope), alignment: .top)
    }

    private var allScopeSection: some View {
        VStack(spacing: AppSpacing.md) {
            BudgetRowItem(
                title: "Needs",
                spent: spending.needs,
                budget: apiBudget.needsBudget,
                color: needsColor,
                onTap: onNeedsTapped
            )
            BudgetRowItem(
                title: "Wants",
                spent: spending.wants,
                budget: apiBudget.wantsBudget,
                color: wantsColor,
                onTap: onWantsTapped
            )
        }
        .padding(.top, AppSpacing.xs)
    }

    private var needsScopeSection: some View {
        categoryBreakdownList(
            title: "Needs categories",
            categories: normalizedNeedsCategories,
            tint: AppColors.budgetNeedsBlueTint,
            accent: needsColor
        )
    }

    private var wantsScopeSection: some View {
        categoryBreakdownList(
            title: "Wants categories",
            categories: normalizedWantsCategories,
            tint: AppColors.budgetWantsPurpleTint,
            accent: wantsColor
        )
    }

    private var budgetEditSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm + AppSpacing.xs) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("TOTAL BUDGET")
                    .font(.cardHeader)
                    .foregroundColor(AppColors.inkFaint)
                BudgetAmountField(value: Binding(
                    get: { draftTotalBudget },
                    set: { applyTotalBudgetChange(max($0, 0)) }
                ))
            }

            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("NEEDS")
                        .font(.cardHeader)
                        .foregroundColor(AppColors.budgetNeedsBlue)
                    BudgetAmountField(value: Binding(
                        get: { draftNeedsBudget },
                        set: { applyBucketBudgetChange(.needs, newBudget: max($0, 0)) }
                    ))
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("WANTS")
                        .font(.cardHeader)
                        .foregroundColor(AppColors.budgetWantsPurple)
                    BudgetAmountField(value: Binding(
                        get: { draftWantsBudget },
                        set: { applyBucketBudgetChange(.wants, newBudget: max($0, 0)) }
                    ))
                }
            }

            categoryEditorSection(title: "Needs categories", scope: .needs, categories: $draftNeedsCategories)
            categoryEditorSection(title: "Wants categories", scope: .wants, categories: $draftWantsCategories)

            if let message = validationMessage {
                Text(message)
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.error)
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    isEditingBudget = false
                    resetDraftFromCurrent()
                } label: {
                    Text("Cancel")
                        .font(.inlineLabel)
                        .foregroundColor(AppColors.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppColors.inkTrack)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)

                Button {
                    guard draftIsValid, !isSaving else { return }
                    saveEditedBudget()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        if isSaving {
                            ProgressView()
                                .tint(AppColors.ctaWhite)
                                .scaleEffect(0.8)
                        }
                        Text(isSaving ? "Saving..." : "Save")
                            .font(.inlineLabel)
                            .foregroundColor(AppColors.ctaWhite)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(draftIsValid ? AppColors.ctaBlack : AppColors.inkTrack)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
                .disabled(!draftIsValid || isSaving)
            }
            .padding(.top, AppSpacing.xs)
        }
        .padding(.bottom, AppSpacing.xs)
    }

    private func categoryEditorSection(
        title: String,
        scope: BudgetScope,
        categories: Binding<[BudgetCategoryBudget]>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.cardHeader)
                .foregroundColor(AppColors.inkFaint)

            if categories.wrappedValue.isEmpty {
                Text("No categories yet")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.inkSoft)
            } else {
                ForEach(categories) { category in
                    HStack(spacing: AppSpacing.sm) {
                        Text(category.wrappedValue.name)
                            .font(.footnoteRegular)
                            .foregroundColor(AppColors.inkSoft)
                            .lineLimit(1)
                        Spacer(minLength: AppSpacing.sm)
                        BudgetAmountField(value: Binding(
                            get: { category.wrappedValue.amount },
                            set: { newAmount in
                                category.wrappedValue.amount = max(newAmount, 0)
                                recalcBudgetsFromCategories(scope: scope)
                            }
                        ))
                        .frame(width: 110)
                    }
                }
            }
        }
    }

    private var ringSection: some View {
        let safeNeedsBudget = max(apiBudget.needsBudget, 0)
        let safeWantsBudget = max(apiBudget.wantsBudget, 0)
        let safeTotalBudget = max(safeNeedsBudget + safeWantsBudget, 1)

        let allNeedsProgress = min(max(spending.needs, 0), safeNeedsBudget) / safeTotalBudget
        let allWantsProgress = min(max(spending.wants, 0), safeWantsBudget) / safeTotalBudget

        let needsProgress = safeNeedsBudget > 0 ? min(max(spending.needs / safeNeedsBudget, 0), 1) : 0
        let wantsProgress = safeWantsBudget > 0 ? min(max(spending.wants / safeWantsBudget, 0), 1) : 0

        let selectionBudget: Double
        let selectionSpent: Double

        switch selectedScope {
        case .all:
            selectionBudget = safeNeedsBudget + safeWantsBudget
            selectionSpent = spending.needs + spending.wants
        case .needs:
            selectionBudget = safeNeedsBudget
            selectionSpent = spending.needs
        case .wants:
            selectionBudget = safeWantsBudget
            selectionSpent = spending.wants
        }

        let usedPercent = selectionBudget > 0
            ? Int((selectionSpent / selectionBudget * 100).rounded())
            : 0

        return VStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle()
                    .stroke(AppColors.inkTrack, lineWidth: 16)

                switch selectedScope {
                case .all:
                    if allNeedsProgress > 0 {
                        ringArc(start: 0, fraction: allNeedsProgress)
                            .stroke(needsColor, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }
                    if allWantsProgress > 0 {
                        ringArc(start: allNeedsProgress, fraction: allWantsProgress)
                            .stroke(wantsColor, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                    }
                case .needs:
                    if needsProgress > 0 {
                        ringArc(start: 0, fraction: needsProgress)
                            .stroke(needsColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                case .wants:
                    if wantsProgress > 0 {
                        ringArc(start: 0, fraction: wantsProgress)
                            .stroke(wantsColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                }

                if isOverBudget && selectedScope == .all {
                    Circle()
                        .stroke(overBudgetColor.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .padding(4)
                }

                VStack(spacing: AppSpacing.xs) {
                    Text("\(max(usedPercent, 0))% used")
                        .font(.footnoteRegular)
                        .foregroundColor(AppColors.inkSoft)
                    Text(formatCurrency(max(selectionSpent, 0)))
                        .font(.h3)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("of \(formatCurrency(max(selectionBudget, 0))) budget")
                        .font(.caption)
                        .foregroundColor(AppColors.inkFaint)

                    if isConnected && hasBudget {
                        Button {
                            isEditingBudget = true
                            resetDraftFromCurrent()
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
            }
            .frame(width: 178, height: 178)

            if isOverBudget && selectedScope == .all {
                Text("Over budget by \(formatCurrency(max(selectionSpent - selectionBudget, 0)))")
                    .font(.footnoteSemibold)
                    .foregroundColor(overBudgetColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var scopePill: some View {
        HStack(spacing: 0) {
            ForEach(BudgetScope.allCases) { scope in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedScope = scope
                    }
                } label: {
                    Text(scope.rawValue)
                        .font(.segmentLabel(selected: selectedScope == scope))
                        .foregroundColor(selectedScope == scope ? AppColors.inkPrimary : AppColors.inkSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    selectedScope == scope
                                    ? (scope == .needs ? AppColors.budgetNeedsBlueTint : (scope == .wants ? AppColors.budgetWantsPurpleTint : AppColors.inkTrack))
                                    : .clear
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppColors.inkTrack.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var lockedEmptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("$—")
                    .font(.cardFigurePrimary)
                    .foregroundStyle(AppColors.inkFaint)
                Text("/ $—")
                    .font(.inlineLabel)
                    .foregroundColor(AppColors.inkFaint)
            }
            Text("Connect accounts to set up a budget")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
            Capsule()
                .fill(AppColors.inkTrack)
                .frame(height: (AppSpacing.sm + AppSpacing.xs) / 2)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.cardPadding)
    }

    private func categoryBreakdownList(
        title: String,
        categories: [BudgetCategoryBudget],
        tint: Color,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.cardHeader)
                .foregroundColor(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)

            if categories.isEmpty {
                Text("No categories yet")
                    .font(.footnoteRegular)
                    .foregroundColor(AppColors.inkSoft)
                    .padding(.vertical, AppSpacing.xs)
            } else {
                ForEach(categories) { category in
                    CategoryBudgetRow(
                        category: category,
                        accent: accent,
                        tint: tint
                    )
                }
            }
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

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: Date()).uppercased()
    }

    private func ringArc(start: Double, fraction: Double) -> some Shape {
        Circle()
            .trim(from: max(0, min(start, 1)), to: max(0, min(start + fraction, 1)))
    }

    private func resetDraftFromCurrent() {
        draftNeedsBudget = max(apiBudget.needsBudget, 0)
        draftWantsBudget = max(apiBudget.wantsBudget, 0)
        draftNeedsCategories = seededCategories(for: .needs)
        draftWantsCategories = seededCategories(for: .wants)
    }

    private func seededCategories(for scope: BudgetScope) -> [BudgetCategoryBudget] {
        let source = scope == .needs ? normalizedNeedsCategories : normalizedWantsCategories
        let budget = scope == .needs ? max(apiBudget.needsBudget, 0) : max(apiBudget.wantsBudget, 0)

        if source.isEmpty {
            let fallback = BudgetCategoryBudget(name: scope == .needs ? "Needs" : "Wants", parent: scope, amount: budget)
            return [fallback]
        }

        let providedSum = source.reduce(0) { $0 + max($1.amount, 0) }
        guard providedSum > 0 else {
            let equalShare = budget / Double(max(source.count, 1))
            return source.map { BudgetCategoryBudget(name: $0.name, parent: scope, amount: equalShare) }
        }

        return source.map {
            let ratio = max($0.amount, 0) / providedSum
            return BudgetCategoryBudget(name: $0.name, parent: scope, amount: ratio * budget)
        }
    }

    private func normalizedCategories(
        source: [BudgetCategoryBudget],
        parent: BudgetScope,
        defaults: [String],
        desiredCount: Int
    ) -> [BudgetCategoryBudget] {
        var ordered: [BudgetCategoryBudget] = []
        for item in source where !ordered.contains(where: { $0.name == item.name }) {
            ordered.append(BudgetCategoryBudget(name: item.name, parent: parent, amount: max(item.amount, 0)))
        }

        for name in defaults where !ordered.contains(where: { $0.name == name }) {
            ordered.append(BudgetCategoryBudget(name: name, parent: parent, amount: 0))
        }

        while ordered.count < desiredCount {
            let fallback = parent == .needs
                ? "Other Needs \(ordered.count + 1)"
                : "Other Wants \(ordered.count + 1)"
            if !ordered.contains(where: { $0.name == fallback }) {
                ordered.append(BudgetCategoryBudget(name: fallback, parent: parent, amount: 0))
            }
        }

        return Array(ordered.prefix(desiredCount))
    }

    private func applyTotalBudgetChange(_ newTotal: Double) {
        let previousTotal = max(draftNeedsBudget + draftWantsBudget, 0)
        guard previousTotal > 0 else {
            draftNeedsBudget = newTotal * 0.5
            draftWantsBudget = newTotal * 0.5
            rescaleCategories(in: .needs, newBudget: draftNeedsBudget)
            rescaleCategories(in: .wants, newBudget: draftWantsBudget)
            return
        }

        let needsRatio = draftNeedsBudget / previousTotal
        draftNeedsBudget = newTotal * needsRatio
        draftWantsBudget = max(newTotal - draftNeedsBudget, 0)
        rescaleCategories(in: .needs, newBudget: draftNeedsBudget)
        rescaleCategories(in: .wants, newBudget: draftWantsBudget)
    }

    private func applyBucketBudgetChange(_ scope: BudgetScope, newBudget: Double) {
        switch scope {
        case .all:
            return
        case .needs:
            draftNeedsBudget = newBudget
            rescaleCategories(in: .needs, newBudget: newBudget)
        case .wants:
            draftWantsBudget = newBudget
            rescaleCategories(in: .wants, newBudget: newBudget)
        }
    }

    private func rescaleCategories(in scope: BudgetScope, newBudget: Double) {
        switch scope {
        case .all:
            return
        case .needs:
            let sum = draftNeedsCategories.reduce(0) { $0 + max($1.amount, 0) }
            if sum <= 0 {
                let equal = newBudget / Double(max(draftNeedsCategories.count, 1))
                draftNeedsCategories = draftNeedsCategories.map {
                    BudgetCategoryBudget(name: $0.name, parent: .needs, amount: equal)
                }
            } else {
                draftNeedsCategories = draftNeedsCategories.map {
                    let ratio = max($0.amount, 0) / sum
                    return BudgetCategoryBudget(name: $0.name, parent: .needs, amount: ratio * newBudget)
                }
            }
        case .wants:
            let sum = draftWantsCategories.reduce(0) { $0 + max($1.amount, 0) }
            if sum <= 0 {
                let equal = newBudget / Double(max(draftWantsCategories.count, 1))
                draftWantsCategories = draftWantsCategories.map {
                    BudgetCategoryBudget(name: $0.name, parent: .wants, amount: equal)
                }
            } else {
                draftWantsCategories = draftWantsCategories.map {
                    let ratio = max($0.amount, 0) / sum
                    return BudgetCategoryBudget(name: $0.name, parent: .wants, amount: ratio * newBudget)
                }
            }
        }
    }

    private func recalcBudgetsFromCategories(scope: BudgetScope) {
        switch scope {
        case .all:
            return
        case .needs:
            draftNeedsBudget = needsCategorySum
        case .wants:
            draftWantsBudget = wantsCategorySum
        }
    }

    private func saveEditedBudget() {
        guard let onSaveBudget else {
            isEditingBudget = false
            return
        }

        isSaving = true

        let total = max(draftTotalBudget, 1)
        let categoryMap = (draftNeedsCategories + draftWantsCategories)
            .reduce(into: [String: Double]()) { partialResult, item in
                let key = TransactionCategoryCatalog.id(forDisplayedSubcategory: item.name) ?? item.name
                partialResult[key] = max(item.amount, 0)
            }

        let payload = BudgetEditPayload(
            needsBudget: max(draftNeedsBudget, 0),
            wantsBudget: max(draftWantsBudget, 0),
            needsRatio: max(draftNeedsBudget, 0) / total * 100,
            wantsRatio: max(draftWantsBudget, 0) / total * 100,
            categoryBudgets: categoryMap
        )

        Task {
            let success = await onSaveBudget(payload)
            await MainActor.run {
                isSaving = false
                if success { isEditingBudget = false }
            }
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

    private func formatSignedCurrency(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : "-"
        return "\(prefix)\(formatCurrency(abs(value)))"
    }
}

private struct BudgetAmountField: View {
    @Binding var value: Double

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    var body: some View {
        HStack(spacing: 4) {
            Text("$")
                .font(.footnoteRegular)
                .foregroundColor(AppColors.inkFaint)
            TextField("0", value: $value, formatter: Self.formatter)
                .keyboardType(.decimalPad)
                .font(.inlineLabel)
                .foregroundColor(AppColors.inkPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(AppColors.ctaWhite.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }
}

private struct BudgetRowItem: View {
    let title: String
    let spent: Double
    let budget: Double
    let color: Color
    let onTap: (() -> Void)?

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack {
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                    Text(title)
                        .font(.inlineLabel)
                        .foregroundColor(AppColors.inkSoft)
                }

                Spacer()

                Text("\(formatCurrency(spent)) / \(formatCurrency(budget))")
                    .font(.footnoteSemibold)
                    .foregroundColor(AppColors.inkPrimary)
            }

            GeometryReader { geo in
                let width = max(geo.size.width, 0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.inkTrack)
                        .frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: width * progress, height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, AppSpacing.sm + AppSpacing.xs)
        .padding(.vertical, AppSpacing.sm)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(color.opacity(0.20), lineWidth: 1)
        )
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

private struct CategoryBudgetRow: View {
    let category: BudgetCategoryBudget
    let accent: Color
    let tint: Color

    private var progress: Double {
        guard category.amount > 0 else { return 0 }
        return min(max(category.spent / category.amount, 0), 1)
    }

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(category.name)
                .font(.footnoteRegular)
                .foregroundColor(AppColors.inkSoft)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatCurrency(max(category.spent, 0)))
                .font(.footnoteSemibold)
                .foregroundColor(AppColors.inkPrimary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint)
                Capsule()
                    .fill(accent)
                    .frame(maxWidth: 96 * progress, alignment: .leading)
            }
            .frame(width: 96, height: 7)

            Text(formatCurrency(max(category.amount, 0)))
                .font(.footnoteSemibold)
                .foregroundColor(AppColors.inkPrimary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 5)
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
        BudgetCard(
            spending: MockData.cashflowData.spending,
            apiBudget: MockData.apiMonthlyBudget,
            needsCategories: [
                BudgetCategoryBudget(name: "Rent", parent: .needs, amount: 1800),
                BudgetCategoryBudget(name: "Utilities", parent: .needs, amount: 400)
            ],
            wantsCategories: [
                BudgetCategoryBudget(name: "Dining", parent: .wants, amount: 300),
                BudgetCategoryBudget(name: "Travel", parent: .wants, amount: 500)
            ]
        )
        .padding()
    }
}
