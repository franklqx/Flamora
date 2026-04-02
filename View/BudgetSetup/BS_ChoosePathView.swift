//
//  BS_ChoosePathView.swift
//  Flamora app
//
//  Budget Setup — Step 4: Choose Your Path
//  V2: Three plan cards (Steady / Recommended / Accelerate)
//  with difficulty dots, dark inset stats, expandable compound growth bars
//

import SwiftUI

struct BS_ChoosePathView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var showCustom = false
    @State private var customBudgetAmount: Double = 0

    private let goldColor = AppColors.budgetGold

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if viewModel.isLoadingPlans {
                        loadingSection
                    } else if let plans = viewModel.plansResponse {
                        // Plan cards
                        planCard(plan: plans.plans.steady, name: "Steady", type: .steady,
                                 difficulty: 1, difficultyLabel: "Easy", difficultyColor: AppColors.budgetTeal)
                            .padding(.horizontal, AppSpacing.lg)

                        planCard(plan: plans.plans.recommended, name: "Recommended", type: .recommended,
                                 difficulty: 2, difficultyLabel: "Moderate", difficultyColor: goldColor,
                                 showBestFit: true)
                            .padding(.horizontal, AppSpacing.lg)

                        planCard(plan: plans.plans.accelerate, name: "Accelerate", type: .accelerate,
                                 difficulty: 3, difficultyLabel: "Ambitious", difficultyColor: AppColors.budgetOrange)
                            .padding(.horizontal, AppSpacing.lg)

                        // Custom option
                        customPlanToggle
                            .padding(.horizontal, AppSpacing.lg)

                        if showCustom {
                            customPlanSection
                                .padding(.horizontal, AppSpacing.lg)
                        }

                        // Disclaimer
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
            }

            stickyBottomCTA
        }
        .alert("Couldn’t continue", isPresented: Binding(
            get: { viewModel.spendingPlanError != nil },
            set: { if !$0 { viewModel.spendingPlanError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.spendingPlanError = nil }
        } message: {
            Text(viewModel.spendingPlanError ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Pick Your Plan")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Group {
                let avgExpense = viewModel.spendingStats?.avgMonthlyExpenses ?? 0
                if avgExpense > 0 {
                    Text("Choose how much to spend each month. You currently spend \(Text("$\(formattedInt(avgExpense))/mo").fontWeight(.semibold).foregroundStyle(AppColors.overlayWhiteOnGlass)) on average.")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("Choose how much to spend each month.")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .font(.bodySmall)
            .lineSpacing(3)
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.overlayWhiteOnPhoto)
            Text("Generating your plans...")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)
    }

    // MARK: - Plan Card

    @ViewBuilder
    private func planCard(plan: PlanDetail, name: String, type: BudgetSetupViewModel.PlanSelection,
                          difficulty: Int, difficultyLabel: String, difficultyColor: Color,
                          showBestFit: Bool = false) -> some View {
        let isSelected = viewModel.selectedPlanType == type

        Button {
            withAnimation(.easeOut(duration: 0.3)) {
                viewModel.selectedPlanType = type
                showCustom = false
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                // Header row: name + difficulty + radio
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm) {
                            Text(name)
                                .font(.h3)
                                .foregroundStyle(AppColors.textPrimary)

                            if showBestFit {
                                Text("BEST FIT")
                                    .font(.miniLabel)
                                    .foregroundStyle(AppColors.textInverse)
                                    .padding(.horizontal, AppSpacing.sm - 2)
                                    .padding(.vertical, 2)
                                    .background(goldColor)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                            }
                        }

                        // Difficulty dots
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(i < difficulty ? AppColors.textPrimary : AppColors.overlayWhiteForegroundSoft)
                                    .frame(width: AppSpacing.sm - 1, height: AppSpacing.sm - 1)
                            }
                            Text(difficultyLabel)
                                .font(.cardRowMeta)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.leading, AppSpacing.xs / 2)
                        }
                    }

                    Spacer()

                    // Radio button
                    ZStack {
                        Circle()
                            .stroke(isSelected ? AppColors.textPrimary : AppColors.overlayWhiteStroke, lineWidth: 2)
                            .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                        if isSelected {
                            Circle()
                                .fill(AppColors.textPrimary)
                                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                            Image(systemName: "checkmark")
                                .font(.cardRowMeta)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.textInverse)
                        }
                    }
                }

                // Hero Budget/Mo number
                VStack(spacing: AppSpacing.xs) {
                    Text("MONTHLY BUDGET")
                        .font(.cardHeader)
                        .tracking(1.5)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    Text("$\(formattedInt(plan.monthlySpend))")
                        .font(.display)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                        .accessibilityLabel("Monthly budget \(formattedInt(plan.monthlySpend)) dollars")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)

                // Secondary stats row
                HStack(spacing: 0) {
                    statColumnSmall(label: "SAVE/MO", value: "$\(formattedInt(plan.monthlySave))")
                    Rectangle().fill(AppColors.overlayWhiteStroke).frame(width: 1, height: AppSpacing.lg)
                    statColumnSmall(label: "RATE", value: formattedPct(plan.savingsRate))
                }
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.backgroundPrimary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                // Growth tip card (only when selected)
                if isSelected {
                    growthTipCard(plan: plan, planType: type)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .padding(AppSpacing.md)
            .background(isSelected ? AppColors.overlayWhiteMid : AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.textPrimary, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(color: isSelected ? AppColors.overlayWhiteWash : .clear, radius: AppSpacing.sm + AppSpacing.xs, y: AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(label)
                .font(.miniLabel)
                .tracking(0.5)
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .font(.figureSecondarySemibold)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statColumnSmall(label: String, value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(label)
                .font(.label)
                .tracking(0.8)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            Text(value)
                .font(.bodySemibold)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Growth Tip Card

    @ViewBuilder
    private func growthTipCard(plan: PlanDetail, planType: BudgetSetupViewModel.PlanSelection) -> some View {
        let monthlySave = plan.monthlySave
        let g10y = nominalGrowth8pct(monthly: monthlySave, years: 10)
        let greenLabel = AppColors.budgetGreenLabel
        let saveColor = AppColors.budgetGreenLabel

        let subText: String = {
            switch planType {
            case .steady:
                let passiveIncome = g10y * 0.08 / 12
                return "That's like earning an extra $\(formattedCompact(passiveIncome))/mo in passive income."
            case .recommended:
                return "Every $1 you save today is worth $2.16 in a decade."
            case .accelerate:
                return "You're closing in on passive income covering all expenses."
            case .custom:
                return "Your savings are growing toward financial independence."
            }
        }()

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm - 2) {
                Text("✨")
                    .font(.caption)
                Text("YOUR POTENTIAL GROWTH")
                    .font(.cardRowMeta)
                    .fontWeight(.semibold)
                    .tracking(0.6)
                    .foregroundStyle(greenLabel)
            }

        Text("\(Text("$\(formattedCompact(monthlySave))/mo").fontWeight(.bold).foregroundStyle(saveColor)) invested at 8% annual return, grows to \(Text("$\(formattedCompact(g10y))").fontWeight(.bold).foregroundStyle(AppColors.textPrimary)) in 10 years.")
            .font(.bodySmall)
            .foregroundStyle(AppColors.overlayWhiteOnGlass)
            .lineSpacing(3)

            Text(subText)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                .lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    AppColors.budgetGreenDarkStart.opacity(0.35),
                    AppColors.budgetGreenDarkEnd.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.budgetGreenStroke.opacity(0.2), lineWidth: 1)
        )
    }

    private func nominalGrowth8pct(monthly: Double, years: Int) -> Double {
        monthly * 12 * (pow(1.08, Double(years)) - 1) / 0.08
    }

    // MARK: - Custom Plan

    private var customPlanToggle: some View {
        Button {
            withAnimation(.easeOut(duration: 0.3)) {
                showCustom.toggle()
                if showCustom {
                    viewModel.selectedPlanType = .custom
                }
            }
        } label: {
            HStack {
                Text(showCustom ? "Custom budget" : "Or set a custom amount")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.overlayWhiteAt60)
                Spacer()
                Image(systemName: showCustom ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        viewModel.selectedPlanType == .custom ? AppColors.textPrimary : AppColors.borderLight,
                        lineWidth: viewModel.selectedPlanType == .custom ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var customPlanSection: some View {
        let income = viewModel.spendingStats?.avgMonthlyIncome ?? viewModel.monthlyIncome
        let avgExpense = viewModel.spendingStats?.avgMonthlyExpenses ?? income * 0.8
        // 月均必需支出下限（API avg_monthly_fixed）；用于自定义预算危险区判断
        let monthlyNeedsBaseline = viewModel.spendingStats?.avgMonthlyFixed ?? avgExpense * 0.5
        let sliderMin = max(0, roundedDown(min(monthlyNeedsBaseline * 0.9, avgExpense * 0.65)))
        let sliderMax = max(roundedUp(max(avgExpense * 1.25, income * 0.95)), sliderMin + 200)
        let budget = customBudgetAmount > 0 ? customBudgetAmount : sliderMin
        let monthlySave = max(0, income - budget)
        let savingsRate = income > 0 ? monthlySave / income * 100 : 0
        let g10y = nominalGrowth8pct(monthly: monthlySave, years: 10)

        // Determine zone
        let zone: CustomZone = {
            if budget <= monthlyNeedsBaseline { return .danger }
            if budget <= monthlyNeedsBaseline * 1.4 { return .warning }
            if budget < avgExpense * 0.7 { return .ambitious }
            return .healthy
        }()

        return VStack(spacing: AppSpacing.md) {
            // Budget display
            VStack(spacing: AppSpacing.sm) {
                Text("MONTHLY BUDGET")
                    .font(.cardHeader)
                    .tracking(1.5)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

                Text("$\(formattedInt(budget))")
                    .font(.currencyHero)
                    .foregroundStyle(zone == .danger ? AppColors.error : AppColors.textPrimary)
                    .monospacedDigit()
                    .animation(.easeOut(duration: 0.15), value: customBudgetAmount)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)

            // Slider
            Slider(value: $customBudgetAmount, in: sliderMin...sliderMax, step: 10)
                .tint(AppColors.overlayWhiteAt60)
                .accessibilityLabel("Monthly budget slider")
                .accessibilityValue("$\(formattedInt(budget))")

            HStack {
                Text("$\(formattedCompact(sliderMin))").font(.cardRowMeta).foregroundStyle(AppColors.textTertiary)
                Spacer()
                Text("$\(formattedCompact(sliderMax))").font(.cardRowMeta).foregroundStyle(AppColors.textTertiary)
            }

            // Stats row
            HStack(spacing: 0) {
                statColumnSmall(label: "SAVE/MO", value: "$\(formattedInt(monthlySave))")
                Rectangle().fill(AppColors.overlayWhiteStroke).frame(width: 1, height: AppSpacing.lg)
                statColumnSmall(label: "RATE", value: formattedPct(savingsRate))
            }
            .padding(.vertical, AppSpacing.sm + AppSpacing.xs)
            .background(AppColors.backgroundPrimary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .animation(.easeOut(duration: 0.15), value: customBudgetAmount)

            // Zone feedback card
            customZoneCard(zone: zone, budget: budget, avgExpense: avgExpense, g10y: g10y, monthlySave: monthlySave)
                .transition(.opacity.combined(with: .offset(y: 4)))
                .animation(.easeOut(duration: 0.25), value: zone)
        }
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .onAppear {
            if customBudgetAmount == 0 {
                let initial = viewModel.plansResponse?.plans.recommended.monthlySpend ?? avgExpense * 0.85
                customBudgetAmount = min(max(roundedToNearest10(initial), sliderMin), sliderMax)
            }
        }
        .onChange(of: customBudgetAmount) { _, newBudget in
            if income > 0 {
                viewModel.customSavingsRate = max(0, (income - newBudget) / income * 100)
            }
        }
    }

    enum CustomZone { case danger, warning, ambitious, healthy }

    @ViewBuilder
    private func customZoneCard(zone: CustomZone, budget: Double, avgExpense: Double, g10y: Double, monthlySave: Double) -> some View {
        let config: (bg: [Color], border: Color, icon: String, label: String) = {
            switch zone {
            case .danger:
                return ([AppColors.budgetDangerStart.opacity(0.4), AppColors.budgetDangerEnd.opacity(0.3)],
                        AppColors.error.opacity(0.3), "⚠️", "NOT ACHIEVABLE")
            case .warning:
                return ([AppColors.budgetWarningStart.opacity(0.4), AppColors.budgetWarningEnd.opacity(0.3)],
                        AppColors.warning.opacity(0.3), "💪", "VERY AGGRESSIVE")
            case .ambitious:
                return ([AppColors.budgetAmbitiousStart.opacity(0.4), AppColors.budgetAmbitiousEnd.opacity(0.3)],
                        AppColors.accentBlueBright.opacity(0.3), "🎯", "AMBITIOUS BUT DOABLE")
            case .healthy:
                return ([AppColors.budgetGreenDarkStart.opacity(0.35), AppColors.budgetGreenDarkEnd.opacity(0.25)],
                        AppColors.budgetGreenStroke.opacity(0.2), "✨", "YOUR POTENTIAL GROWTH")
            }
        }()

        let bodyText: String = {
            switch zone {
            case .danger:
                return "This budget is below your needs (essential spending) of $\(formattedInt(viewModel.spendingStats?.avgMonthlyFixed ?? 0))/mo and isn't achievable."
            case .warning:
                return "This leaves very little buffer above your needs. You'd need to cut most wants spending."
            case .ambitious:
                return "You're spending less than 70% of your average. This is doable with discipline and a clear plan."
            case .healthy:
                return "Investing $\(formattedCompact(monthlySave))/mo at 8% annual return grows to $\(formattedCompact(g10y)) in 10 years."
            }
        }()

        VStack(alignment: .leading, spacing: AppSpacing.sm - 2) {
            HStack(spacing: AppSpacing.sm - 2) {
                Text(config.icon).font(.caption)
                Text(config.label)
                    .font(.cardRowMeta)
                    .fontWeight(.semibold)
                    .tracking(0.6)
                    .foregroundStyle(AppColors.overlayWhiteOnGlass)
            }
            Text(bodyText)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                .lineSpacing(3)
        }
        .padding(AppSpacing.sm + AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: config.bg, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(config.border, lineWidth: 1))
    }

    // MARK: - Assumptions Note

    private var assumptionsNote: some View {
        Text("Growth projections assume 8% annual return (5.5% after inflation) based on S&P 500 historical performance.")
            .font(.cardRowMeta)
            .foregroundStyle(AppColors.textTertiary)
            .lineSpacing(3)
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [AppColors.backgroundPrimary.opacity(0), AppColors.backgroundPrimary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                // 必须先等 generate-spending-plan 完成再进确认页，否则 spendingPlan 为 nil，saveFinalBudget 会静默失败。
                Task {
                    await viewModel.loadSpendingPlan()
                    guard viewModel.spendingPlan != nil else { return }
                    await MainActor.run {
                        viewModel.goToStep(.confirm)
                    }
                }
            } label: {
                Group {
                    if viewModel.isLoadingSpendingPlan {
                        ProgressView()
                            .tint(AppColors.textInverse)
                    } else {
                        Text("Continue")
                            .font(.sheetPrimaryButton)
                    }
                }
                .foregroundStyle(AppColors.textInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: AppColors.gradientFire, startPoint: .leading, endPoint: .trailing)
                        .opacity(viewModel.selectedPlan != nil && !viewModel.isLoadingPlans && !viewModel.isLoadingSpendingPlan ? 1 : 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(viewModel.selectedPlan == nil || viewModel.isLoadingPlans || viewModel.isLoadingSpendingPlan)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Formatters

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formattedPct(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))%"
        }
        return String(format: "%.1f%%", rounded)
    }

    private func formattedCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return "\(Int(value / 1_000))K"
        }
        return formattedInt(value)
    }

    private func roundedToNearest10(_ value: Double) -> Double {
        (value / 10).rounded() * 10
    }

    private func roundedDown(_ value: Double) -> Double {
        floor(value / 10) * 10
    }

    private func roundedUp(_ value: Double) -> Double {
        ceil(value / 10) * 10
    }
}

#Preview {
    BS_ChoosePathView(viewModel: BudgetSetupViewModel())
}
