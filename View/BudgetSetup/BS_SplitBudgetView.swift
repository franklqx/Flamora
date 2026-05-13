//
//  BS_SplitBudgetView.swift
//  Meridian
//
//  Budget Setup — Optional category budgets step.
//  Reached only via the Plan-Set celebration page when the user opts in.
//  Shows the user's actual avg spend per category as the baseline reference.
//  Saved limits live in `monthly_budgets.category_budgets` and surface on
//  Cashflow Home as per-category tracking — they do not affect the total budget.
//

import SwiftUI

struct BS_SplitBudgetView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var selectedRow: CategoryBudgetRow?
    @State private var draftLimit: Double = 0
    @State private var showAllCategories = false

    private static let defaultVisibleCount = 8

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    // MARK: - Row Model

    fileprivate struct CategoryBudgetRow: Identifiable, Equatable {
        let id: String       // canonical id
        let name: String
        let icon: String     // SF Symbol
        let parent: String   // "needs" | "wants"
        let average: Double
    }

    // MARK: - Data sources

    private var allRows: [CategoryBudgetRow] {
        // Prefer V3 canonical breakdown — it carries parent + canonical id directly.
        if let canonical = viewModel.spendingStats?.canonicalBreakdown, !canonical.isEmpty {
            return canonical.compactMap { item in
                guard item.avgMonthly > 0,
                      let cat = TransactionCategoryCatalog.category(forStoredSubcategory: item.canonicalId)
                else { return nil }
                return CategoryBudgetRow(
                    id: cat.id,
                    name: cat.name,
                    icon: cat.icon,
                    parent: item.parent,
                    average: item.avgMonthly
                )
            }
        }

        // Fallback for non-V3 stats: combine fixed + flexible breakdowns.
        var rows: [CategoryBudgetRow] = []
        if let fixed = viewModel.spendingStats?.fixedExpenses {
            for item in fixed where item.avgMonthlyAmount > 0 {
                guard let cat = TransactionCategoryCatalog.category(forStoredSubcategory: item.name) else { continue }
                rows.append(CategoryBudgetRow(
                    id: cat.id,
                    name: cat.name,
                    icon: cat.icon,
                    parent: "needs",
                    average: item.avgMonthlyAmount
                ))
            }
        }
        if let flexible = viewModel.spendingStats?.flexibleBreakdown {
            for item in flexible where item.avgMonthlyAmount > 0 {
                guard let cat = TransactionCategoryCatalog.category(forStoredSubcategory: item.subcategory) else { continue }
                rows.append(CategoryBudgetRow(
                    id: cat.id,
                    name: cat.name,
                    icon: cat.icon,
                    parent: "wants",
                    average: item.avgMonthlyAmount
                ))
            }
        }
        return rows
    }

    private var sortedAllRows: [CategoryBudgetRow] {
        allRows.sorted { $0.average > $1.average }
    }

    private var visibleRows: [CategoryBudgetRow] {
        showAllCategories ? sortedAllRows : Array(sortedAllRows.prefix(Self.defaultVisibleCount))
    }

    private var visibleNeeds: [CategoryBudgetRow] {
        visibleRows.filter { $0.parent == "needs" }
    }

    private var visibleWants: [CategoryBudgetRow] {
        visibleRows.filter { $0.parent == "wants" }
    }

    private var hasMoreCategories: Bool {
        sortedAllRows.count > Self.defaultVisibleCount
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if sortedAllRows.isEmpty {
                        emptyState
                            .padding(.horizontal, AppSpacing.lg)
                    } else {
                        if !visibleNeeds.isEmpty {
                            categoryGroup(title: "NEEDS", rows: visibleNeeds)
                                .padding(.horizontal, AppSpacing.lg)
                        }
                        if !visibleWants.isEmpty {
                            categoryGroup(title: "WANTS", rows: visibleWants)
                                .padding(.horizontal, AppSpacing.lg)
                        }
                        if hasMoreCategories {
                            showAllToggle
                                .padding(.horizontal, AppSpacing.lg)
                        }
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }
            .sheet(item: $selectedRow) { row in
                categoryLimitSheet(for: row)
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Set up category budgets")
                .font(.h2)
                .foregroundStyle(AppColors.inkPrimary)

            Text("We'll use your monthly average as a baseline. Tap a category to add a custom limit.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("No category history yet")
                .font(.bodySemibold)
                .foregroundStyle(AppColors.inkPrimary)
            Text("Once you've spent in a few categories we'll show them here.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardPadding)
        .bsGlassCard(cornerRadius: AppRadius.glassBlock)
    }

    // MARK: - Group + Row

    private func categoryGroup(title: String, rows: [CategoryBudgetRow]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.cardHeader)
                .tracking(AppTypography.Tracking.cardHeader)
                .foregroundStyle(AppColors.inkSoft)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    categoryRow(row, isLast: index == rows.count - 1)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .bsGlassCard()
        }
    }

    private func categoryRow(_ row: CategoryBudgetRow, isLast: Bool) -> some View {
        let limit = viewModel.categoryBudgets[row.id]
        let hasLimit = limit != nil

        return Button {
            draftLimit = limit ?? roundBudgetAmount(row.average)
            selectedRow = row
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: AppSpacing.md) {
                    iconBadge(symbol: row.icon, parent: row.parent)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(row.name)
                            .font(.bodySmallSemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                            .lineLimit(1)

                        Text("Avg $\(formattedInt(row.average))/mo")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSoft)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    if hasLimit {
                        Text("$\(formattedInt(limit ?? 0))")
                            .font(.bodySmallSemibold)
                            .foregroundStyle(AppColors.inkPrimary)
                            .monospacedDigit()
                    }

                    trailingGlyph(hasLimit: hasLimit)
                }
                .padding(.vertical, AppSpacing.sm)

                if !isLast {
                    Divider()
                        .background(AppColors.inkDivider)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconBadge(symbol: String, parent: String) -> some View {
        let tint = parent == "needs" ? AppColors.budgetNeedsBlue : AppColors.budgetWantsPurple
        return ZStack {
            Circle()
                .fill(tint.opacity(0.18))
            Image(systemName: symbol)
                .font(.footnoteSemibold)
                .foregroundStyle(tint)
        }
        .frame(width: AppSpacing.xl + AppSpacing.xs, height: AppSpacing.xl + AppSpacing.xs)
    }

    private func trailingGlyph(hasLimit: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(AppColors.inkBorder, lineWidth: 1)
                .background(Circle().fill(hasLimit ? AppColors.inkPrimary : AppColors.ctaWhite))
                .frame(width: AppSpacing.lg + AppSpacing.xs, height: AppSpacing.lg + AppSpacing.xs)
            Image(systemName: hasLimit ? "checkmark" : "plus")
                .font(.footnoteSemibold)
                .foregroundStyle(hasLimit ? AppColors.ctaWhite : AppColors.inkPrimary)
        }
    }

    private var showAllToggle: some View {
        Button {
            withAnimation(.easeOut(duration: 0.22)) {
                showAllCategories.toggle()
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(showAllCategories ? "Show less" : "Show all categories")
                    .font(.bodySmallSemibold)
                Image(systemName: showAllCategories ? "chevron.up" : "chevron.down")
                    .font(.smallLabel)
            }
            .foregroundStyle(AppColors.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.didSkipCategoryBudgets = false
                viewModel.goToStep(.confirm)
            } label: {
                Text("Continue")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(AppColors.ctaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.inkPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    // MARK: - Limit Sheet

    private func categoryLimitSheet(for row: CategoryBudgetRow) -> some View {
        let existingLimit = viewModel.categoryBudgets[row.id]

        // iOS-standard sheet drag indicator dimensions (44×5pt)
        let dragIndicatorWidth: CGFloat = 44
        let dragIndicatorHeight: CGFloat = 5

        return VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Capsule()
                .fill(AppColors.inkBorder)
                .frame(width: dragIndicatorWidth, height: dragIndicatorHeight)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.sm)

            HStack(spacing: AppSpacing.md) {
                iconBadge(symbol: row.icon, parent: row.parent)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(row.name)
                        .font(.detailTitle)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("Avg $\(formattedInt(row.average))/mo")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("MONTHLY LIMIT")
                    .font(.miniLabel)
                    .tracking(0.8)
                    .foregroundStyle(AppColors.inkFaint)

                HStack(spacing: AppSpacing.xs) {
                    Text("$")
                        .font(.cardFigureSecondary)
                        .foregroundStyle(AppColors.inkFaint)

                    TextField("0", value: $draftLimit, formatter: Self.currencyFormatter)
                        .font(.cardFigureSecondary)
                        .foregroundStyle(AppColors.inkPrimary)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                }
                .padding(AppSpacing.md)
                .background(AppColors.glassBlockBg)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.inkBorder, lineWidth: 1)
                )
            }

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                Button {
                    viewModel.categoryBudgets[row.id] = roundBudgetAmount(max(0, draftLimit))
                    selectedRow = nil
                } label: {
                    Text(existingLimit == nil ? "Save limit" : "Update limit")
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(AppColors.ctaWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.inkPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)

                if existingLimit != nil {
                    Button {
                        viewModel.categoryBudgets.removeValue(forKey: row.id)
                        selectedRow = nil
                    } label: {
                        Text("Remove limit")
                            .font(.sheetPrimaryButton)
                            .foregroundStyle(AppColors.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.glassCardBg)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.button)
                                    .stroke(AppColors.inkBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.lg)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.hidden)
        .background(AppColors.shellBg2)
    }

    // MARK: - Helpers

    private func roundBudgetAmount(_ value: Double) -> Double {
        (value / 10).rounded() * 10
    }

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }
}

#Preview {
    BS_SplitBudgetView(viewModel: BudgetSetupViewModel())
}
