//
//  BS_SplitBudgetView.swift
//  Flamora app
//
//  Budget Setup — Step 5.5: optional category limits after choosing the total plan.
//

import SwiftUI

struct BS_SplitBudgetView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var selectedLimitItem: FlexibleBudgetItem?
    @State private var draftLimit: Double = 0

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private var categoryItems: [FlexibleBudgetItem] { viewModel.effectiveFlexibleItems }
    private var limitsSetCount: Int { viewModel.categoryBudgets.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    planSummaryCard
                        .padding(.horizontal, AppSpacing.lg)

                    categoryLimitsSection
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }
            .sheet(item: $selectedLimitItem) { item in
                categoryLimitSheet(for: item)
            }

            stickyBottomCTA
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Set Category Limits")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            Text("Add optional limits for the categories you want to watch more closely.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    private var planSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: 0) {
                summaryMetric(title: "Monthly budget", value: viewModel.committedSpendCeiling ?? viewModel.spendingPlan?.totalSpend ?? 0, tint: AppColors.inkPrimary)
                Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.xl)
                summaryMetric(title: "Save target", value: viewModel.committedMonthlySave ?? viewModel.spendingPlan?.totalSavings ?? 0, tint: AppColors.accentAmber)
                Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.xl)
                countMetric(title: "Limits set", value: limitsSetCount, tint: AppColors.budgetTeal)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var categoryLimitsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader("OPTIONAL LIMITS", trailing: limitsSetCount == 0 ? "None set" : "\(limitsSetCount) set")

            VStack(spacing: AppSpacing.sm) {
                if categoryItems.isEmpty {
                    Text("No optional categories found for this plan.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                } else {
                    ForEach(categoryItems) { item in
                        categoryLimitRow(item)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            )
        }
    }

    private func categoryLimitRow(_ item: FlexibleBudgetItem) -> some View {
        let key = categoryBudgetKey(for: item.subcategory)
        let limit = viewModel.categoryBudgets[key]
        let average = historicalAverage(for: item)

        return Button {
            draftLimit = limit ?? roundBudgetAmount(average)
            selectedLimitItem = item
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName(for: item.subcategory))
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)

                    Text("Avg $\(formattedInt(average))/mo")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkFaint)
                }

                Spacer(minLength: AppSpacing.sm)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(limit == nil ? "No limit set" : "Limit $\(formattedInt(limit ?? 0))/mo")
                        .font(.smallLabel)
                        .foregroundStyle(limit == nil ? AppColors.inkSoft : AppColors.inkPrimary)
                        .monospacedDigit()

                    Text(limit == nil ? "Set limit" : "Edit")
                        .font(.caption)
                        .foregroundStyle(AppColors.budgetTeal)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, AppSpacing.xs)
    }

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            HStack(spacing: AppSpacing.sm) {
                Button {
                    viewModel.categoryBudgets = [:]
                    viewModel.goToStep(.confirm)
                } label: {
                    Text("Skip")
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

                Button {
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
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    private func categoryLimitSheet(for item: FlexibleBudgetItem) -> some View {
        let key = categoryBudgetKey(for: item.subcategory)
        let average = historicalAverage(for: item)
        let existingLimit = viewModel.categoryBudgets[key]

        return VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Capsule()
                .fill(AppColors.inkBorder)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.sm)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("\(displayName(for: item.subcategory)) Limit")
                    .font(.detailTitle)
                    .foregroundStyle(AppColors.inkPrimary)

                Text("Your average is $\(formattedInt(average))/mo. Set a monthly cap if you want this category tracked in your plan.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(3)
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
                .background(AppColors.ctaWhite.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.inkBorder, lineWidth: 1)
                )
            }

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                Button {
                    viewModel.categoryBudgets[key] = roundBudgetAmount(max(0, draftLimit))
                    selectedLimitItem = nil
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
                        viewModel.categoryBudgets.removeValue(forKey: key)
                        selectedLimitItem = nil
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
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.hidden)
        .background(AppColors.shellBg2)
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)
            Spacer()
            Text(trailing)
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
        }
    }

    private func summaryMetric(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.miniLabel)
                .tracking(0.8)
                .foregroundStyle(AppColors.inkFaint)
            Text("$\(formattedInt(value))")
                .font(.bodySemibold)
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countMetric(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.miniLabel)
                .tracking(0.8)
                .foregroundStyle(AppColors.inkFaint)
            Text("\(value)")
                .font(.bodySemibold)
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryBudgetKey(for raw: String) -> String {
        TransactionCategoryCatalog.canonicalSubcategory(fromStored: raw) ?? raw
    }

    private func historicalAverage(for item: FlexibleBudgetItem) -> Double {
        let key = categoryBudgetKey(for: item.subcategory)
        if let canonicalAverage = viewModel.spendingStats?.canonicalBreakdown?.first(where: { $0.canonicalId == key })?.avgMonthly {
            return canonicalAverage
        }
        if item.historicalAvg > 0 {
            return item.historicalAvg
        }
        return item.suggestedAmount
    }

    private func roundBudgetAmount(_ value: Double) -> Double {
        (value / 10).rounded() * 10
    }

    private func displayName(for key: String) -> String {
        TransactionCategoryCatalog.displayName(forStoredSubcategory: key)
            ?? key.replacingOccurrences(of: "_", with: " ").capitalized
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
