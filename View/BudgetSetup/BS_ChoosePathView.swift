//
//  BS_ChoosePathView.swift
//  Flamora app
//
//  Budget Setup — Step 5: Choose Your Plan
//  Phase D wiring: consumes the new dynamic `plans[]` contract from generate-plans.
//  Visual redesign stays intentionally light until Phase E.
//

import SwiftUI

struct BS_ChoosePathView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var showCapsSheet = false
    @State private var customSaveDraft: Double = 0

    private let goldColor = AppColors.budgetGold

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if viewModel.isLoadingPlans {
                        loadingSection
                    } else if let primary = viewModel.primaryPlan {
                        stateBanner(for: primary)
                            .padding(.horizontal, AppSpacing.lg)

                        ForEach(Array(viewModel.plans.enumerated()), id: \.element.id) { index, plan in
                            planCard(plan: plan, index: index, showBestFit: index == 0)
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        if let sliderBounds {
                            customSaveCard(bounds: sliderBounds)
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        capsCard
                            .padding(.horizontal, AppSpacing.lg)

                        assumptionsNote
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
                if viewModel.plans.isEmpty {
                    Task { await viewModel.loadPlans() }
                } else {
                    seedCustomSaveDraft()
                }
            }
            .onChange(of: viewModel.selectedPlanIndex) { _, _ in
                if !viewModel.isUsingCustomPlan {
                    seedCustomSaveDraft()
                }
            }

            stickyBottomCTA
        }
        .sheet(isPresented: $showCapsSheet) {
            BS_CapsSheet(viewModel: viewModel)
        }
        .alert("Couldn't continue", isPresented: Binding(
            get: { viewModel.spendingPlanError != nil },
            set: { if !$0 { viewModel.spendingPlanError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.spendingPlanError = nil }
        } message: {
            Text(viewModel.spendingPlanError ?? "")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Choose Your Plan")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            Text("Choose the plan you want to commit to. We’ll carry its monthly save, monthly budget, and FIRE timing straight into confirmation.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private func stateBanner(for plan: BudgetPlanOption) -> some View {
        switch plan.feasibility {
        case "already_fire":
            bannerRow(
                icon: "checkmark.seal.fill",
                tint: AppColors.budgetTeal,
                title: "You're already financially free",
                subtitle: "This flow now just locks in a sustainable spending level and starts tracking."
            )
        case "closest_far":
            bannerRow(
                icon: "exclamationmark.triangle.fill",
                tint: AppColors.budgetOrange,
                title: "Your target needs adjustment",
                subtitle: plan.sub
            )
        case "closest_near":
            bannerRow(
                icon: "arrow.trianglehead.clockwise",
                tint: goldColor,
                title: "Closest reasonable plan",
                subtitle: plan.sub
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.bodySemibold)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(subtitle)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(tint.opacity(0.4), lineWidth: 1)
        )
    }

    private var loadingSection: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.inkPrimary)
            Text("Generating your plans...")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)
    }

    @ViewBuilder
    private func planCard(plan: BudgetPlanOption, index: Int, showBestFit: Bool = false) -> some View {
        let isSelected = viewModel.selectedPlanIndex == index
        let difficulty = min(index + 1, 3)
        let difficultyLabel = difficultyLabel(for: plan)

        Button {
            withAnimation(.easeOut(duration: 0.3)) {
                viewModel.selectPlan(at: index)
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm) {
                            Text(viewModel.displayName(for: plan.label))
                                .font(.h3)
                                .foregroundStyle(AppColors.inkPrimary)

                            if showBestFit {
                                Text("BEST FIT")
                                    .font(.miniLabel)
                                    .foregroundStyle(AppColors.ctaWhite)
                                    .padding(.horizontal, AppSpacing.sm - 2)
                                    .padding(.vertical, 2)
                                    .background(goldColor)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                            }

                            if let badge = plan.badge, !badge.isEmpty, !showBestFit {
                                Text(badge.uppercased())
                                    .font(.miniLabel)
                                    .foregroundStyle(AppColors.ctaWhite)
                                    .padding(.horizontal, AppSpacing.sm - 2)
                                    .padding(.vertical, 2)
                                    .background(AppColors.budgetOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                            }
                        }

                        HStack(spacing: AppSpacing.xs) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(i < difficulty ? AppColors.inkPrimary : AppColors.inkSoft)
                                    .frame(width: AppSpacing.sm - 1, height: AppSpacing.sm - 1)
                            }
                            Text(difficultyLabel)
                                .font(.cardRowMeta)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.inkPrimary)
                                .padding(.leading, AppSpacing.xs / 2)
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(isSelected ? AppColors.inkPrimary : AppColors.inkBorder, lineWidth: 2)
                            .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                        if isSelected {
                            Circle()
                                .fill(AppColors.inkPrimary)
                                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                            Image(systemName: "checkmark")
                                .font(.cardRowMeta)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.ctaWhite)
                        }
                    }
                }

                VStack(spacing: AppSpacing.xs) {
                    Text("MONTHLY BUDGET")
                        .font(.cardHeader)
                        .tracking(1.5)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("$\(formattedInt(plan.monthlyBudget))")
                        .font(.display)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                        .accessibilityLabel("Monthly budget \(formattedInt(plan.monthlyBudget)) dollars")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)

                HStack(spacing: 0) {
                    statColumnSmall(label: "SAVE/MO", value: "$\(formattedInt(plan.monthlySave))")
                    Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.lg)
                    statColumnSmall(label: "RATE", value: formattedPct(plan.savingsRate * 100))
                    Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.lg)
                    statColumnSmall(label: "RETIRE AT", value: "Age \(plan.projectedFireAge)")
                }
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.glassCardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                if isSelected {
                    fireDetailExpand(plan: plan)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.inkPrimary, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(color: isSelected ? AppColors.glassCardBg : .clear, radius: AppSpacing.sm + AppSpacing.xs, y: AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fireDetailExpand(plan: BudgetPlanOption) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPENDING CEILING")
                        .font(.label)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.inkFaint)
                    Text("$\(formattedInt(plan.committedSpendCeiling))/mo")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(AppSpacing.sm)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TARGET GAP")
                        .font(.label)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.inkFaint)
                    Text(plan.gapYears > 0 ? "About \(plan.gapYears)y later than target" : "On track for your target")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                Spacer()
            }
            .padding(AppSpacing.sm)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

            HStack(alignment: .top, spacing: AppSpacing.sm - 2) {
                Image(systemName: "info.circle")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkFaint)
                    .padding(.top, 1)
                Text(plan.sub)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(3)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColors.glassCardBg, AppColors.glassCardBg.opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var assumptionsNote: some View {
        Text("FIRE estimates use the 4% withdrawal rule with 4% real annual returns (inflation-adjusted). Projections, not guarantees.")
            .font(.cardRowMeta)
            .foregroundStyle(AppColors.inkFaint)
            .lineSpacing(3)
    }

    @ViewBuilder
    private func customSaveCard(bounds: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("CUSTOM MONTHLY SAVE")
                        .font(.label)
                        .tracking(1)
                        .foregroundStyle(AppColors.inkFaint)
                    Text("$\(formattedInt(viewModel.committedMonthlySave ?? customSaveDraft))/mo")
                        .font(.h2)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                }
                Spacer()
                if viewModel.isUsingCustomPlan {
                    Button("Reset") {
                        viewModel.resetCommittedToSelectedPlan()
                        seedCustomSaveDraft()
                    }
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.accentAmber)
                }
            }

            Slider(
                value: Binding(
                    get: { min(max(customSaveDraft, bounds.lowerBound), bounds.upperBound) },
                    set: { newValue in
                        customSaveDraft = newValue
                        viewModel.applyCustomMonthlySave(newValue)
                    }
                ),
                in: bounds,
                step: 10
            )
            .tint(AppColors.accentAmber)

            HStack {
                Text("$\(formattedInt(bounds.lowerBound))")
                Spacer()
                Text("$\(formattedInt(bounds.upperBound))")
            }
            .font(.caption)
            .foregroundStyle(AppColors.inkFaint)

            HStack(spacing: 0) {
                statColumnSmall(label: "BUDGET", value: "$\(formattedInt(viewModel.committedSpendCeiling ?? 0))")
                Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.lg)
                statColumnSmall(label: "RATE", value: formattedPct((viewModel.committedSavingsRate ?? 0) * 100))
                Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.lg)
                statColumnSmall(label: "RETIRE AT", value: fireAgeValue)
            }
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.shellBg2.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var capsCard: some View {
        Button {
            viewModel.ensureCategoryBudgetsSeeded()
            showCapsSheet = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("CUSTOMIZE SUBCATEGORIES")
                            .font(.label)
                            .tracking(1)
                            .foregroundStyle(AppColors.inkFaint)
                        Text("Optionally split your monthly budget into category caps now.")
                            .font(.footnoteRegular)
                            .foregroundStyle(AppColors.inkSoft)
                            .lineSpacing(3)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.bodySemibold)
                        .foregroundStyle(AppColors.accentAmber)
                }

                if viewModel.categoryBudgets.isEmpty {
                    Text("Use suggested category caps")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.accentAmber)
                } else {
                    Text("$\(formattedInt(viewModel.categoryBudgetTotal)) assigned · $\(formattedInt(abs(viewModel.categoryBudgetRemaining))) \(viewModel.categoryBudgetRemaining >= 0 ? "left" : "over")")
                        .font(.bodySmallSemibold)
                        .foregroundStyle(viewModel.categoryBudgetRemaining >= 0 ? AppColors.inkPrimary : AppColors.error)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                Task {
                    await viewModel.loadSpendingPlan()
                    guard viewModel.spendingPlan != nil else { return }
                    await MainActor.run { viewModel.goToStep(.confirm) }
                }
            } label: {
                Group {
                    if viewModel.isLoadingSpendingPlan {
                        ProgressView().tint(AppColors.ctaWhite)
                    } else {
                        Text("Continue")
                            .font(.sheetPrimaryButton)
                    }
                }
                .foregroundStyle(AppColors.ctaWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    AppColors.inkPrimary
                        .opacity(viewModel.selectedPlan != nil && !viewModel.isLoadingPlans && !viewModel.isLoadingSpendingPlan ? 1 : 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(viewModel.selectedPlan == nil || viewModel.isLoadingPlans || viewModel.isLoadingSpendingPlan)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    @ViewBuilder
    private func statColumnSmall(label: String, value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(label)
                .font(.label)
                .tracking(0.8)
                .foregroundStyle(AppColors.inkFaint)
            Text(value)
                .font(.bodySemibold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func difficultyLabel(for plan: BudgetPlanOption) -> String {
        switch plan.anchor {
        case "target": return "Target"
        case "lifestyle": return "Lifestyle"
        case "acceleration": return "Acceleration"
        default: return "Plan"
        }
    }

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formattedPct(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return "\(Int(rounded))%" }
        return String(format: "%.1f%%", rounded)
    }

    private var sliderBounds: ClosedRange<Double>? {
        guard let slider = viewModel.customSliderRange,
              slider.isAvailable,
              let min = slider.minMonthlySave,
              let max = slider.maxMonthlySave,
              max > min else {
            return nil
        }
        return min...max
    }

    private var fireAgeValue: String {
        if let age = viewModel.committedProjectedFireAge {
            return "Age \(age)"
        }
        return "Later"
    }

    private func seedCustomSaveDraft() {
        if let committed = viewModel.committedMonthlySave {
            customSaveDraft = committed
        } else if let selected = viewModel.selectedPlan {
            customSaveDraft = selected.monthlySave
        }
    }
}

private struct BS_CapsSheet: View {
    @Bindable var viewModel: BudgetSetupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftBudgets: [String: Double] = [:]

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var sortedCategories: [(String, Double)] {
        draftBudgets
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
    }

    private var ceiling: Double {
        viewModel.committedSpendCeiling ?? viewModel.currentSnapshotSpend
    }

    private var total: Double {
        draftBudgets.values.reduce(0, +)
    }

    private var remaining: Double {
        ceiling - total
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    summaryCard

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("CATEGORY CAPS")
                            .font(.label)
                            .tracking(1)
                            .foregroundStyle(AppColors.inkFaint)

                        ForEach(sortedCategories, id: \.0) { key, _ in
                            capRow(for: key)
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .navigationTitle("Customize Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.categoryBudgets = draftBudgets
                        dismiss()
                    }
                    .disabled(remaining < 0)
                }
            }
            .onAppear {
                viewModel.ensureCategoryBudgetsSeeded()
                draftBudgets = viewModel.categoryBudgets
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("These caps help split your total monthly budget into categories. They do not change your overall monthly budget.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)

            HStack(spacing: AppSpacing.sm) {
                summaryMetric(title: "Budget", value: ceiling, tint: AppColors.inkPrimary)
                summaryMetric(title: "Assigned", value: total, tint: AppColors.budgetTeal)
                summaryMetric(title: remaining >= 0 ? "Left" : "Over", value: abs(remaining), tint: remaining >= 0 ? AppColors.accentAmber : AppColors.error)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private func summaryMetric(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.miniLabel)
                .tracking(0.8)
                .foregroundStyle(AppColors.inkFaint)
            Text("$\(formatted(value))")
                .font(.bodySemibold)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func capRow(for key: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(displayName(for: key))
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.inkPrimary)

            HStack(spacing: AppSpacing.sm) {
                Text("$")
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkFaint)
                TextField("0", value: binding(for: key), formatter: Self.currencyFormatter)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkPrimary)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 46)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            )
        }
    }

    private func binding(for key: String) -> Binding<Double> {
        Binding(
            get: { draftBudgets[key] ?? 0 },
            set: { draftBudgets[key] = max(0, $0) }
        )
    }

    private func displayName(for key: String) -> String {
        key
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
    }
}
