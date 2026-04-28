//
//  BS_ChoosePathView.swift
//  Flamora app
//
//  Budget Setup — Step 5: Choose Your Plan
//  Phase D wiring: consumes the new dynamic `plans[]` contract from generate-plans.
//  Step 5: select the savings plan before splitting wants in Step 5.5.
//

import SwiftUI

struct BS_ChoosePathView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false

    private let dotSize: CGFloat = 7

    /// Blue → indigo-purple gradient (matches DESIGN.md `gradientShellAccent`).
    /// Used for the selected plan's border + select indicator. Static so the
    /// same instance is reused across renders.
    fileprivate static let selectAccentGradient = LinearGradient(
        colors: AppColors.gradientShellAccent,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
                        todayAnchorCard
                            .padding(.horizontal, AppSpacing.lg)

                        targetAnchorCard
                            .padding(.horizontal, AppSpacing.lg)

                        stateBanner(for: primary)
                            .padding(.horizontal, AppSpacing.lg)

                        ForEach(Array(viewModel.plans.enumerated()), id: \.element.id) { index, plan in
                            planCard(plan: plan, index: index, showBestFit: index == 0)
                                .padding(.horizontal, AppSpacing.lg)
                        }

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
                Task { await viewModel.loadPlans() }
            }

            stickyBottomCTA
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

            Text("Pick a monthly budget and saving target.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    private var targetAnchorCard: some View {
        Button {
            viewModel.goToStep(.target)
        } label: {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("YOUR TARGET")
                        .font(.label)
                        .tracking(1)
                        .foregroundStyle(AppColors.inkFaint)

                    HStack(spacing: AppSpacing.md) {
                        anchorMetric(label: "Retire by", value: "Age \(viewModel.targetRetirementAge)")
                        anchorMetric(label: "Retirement budget", value: "$\(formattedInt(viewModel.retirementSpendingMonthly))/mo")
                    }
                }

                Spacer(minLength: AppSpacing.sm)

                Image(systemName: "pencil")
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(width: AppSpacing.xl, height: AppSpacing.xl)
                    .background(AppColors.glassBlockBg)
                    .clipShape(Circle())
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bsGlassCard()
        }
        .buttonStyle(.plain)
    }

    private var todayAnchorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("TODAY")
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)

            HStack(spacing: 0) {
                anchorMetric(label: "Earning", value: "$\(formattedInt(viewModel.currentSnapshotIncome))")
                anchorMetric(label: "Spending", value: "$\(formattedInt(viewModel.currentSnapshotSpend))")
                anchorMetric(label: "Saving", value: "$\(formattedInt(viewModel.spendingStats?.avgMonthlySavings ?? (viewModel.currentSnapshotIncome - viewModel.currentSnapshotSpend)))")
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bsGlassCard()
    }

    private func anchorMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
            Text(value)
                .font(.bodySemibold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func stateBanner(for plan: BudgetPlanOption) -> some View {
        switch plan.feasibility {
        case "already_fire":
            bannerRow(
                icon: "checkmark.seal.fill",
                tint: AppColors.planDifficultySteady,
                title: "You're already financially free",
                subtitle: "Choose a monthly budget to start tracking sustainable spending."
            )
        case "closest_far":
            bannerRow(
                icon: "exclamationmark.triangle.fill",
                tint: AppColors.planDifficultyAccelerate,
                title: "Your target needs adjustment",
                subtitle: "The earliest reasonable path reaches FIRE at age \(plan.projectedFireAge)."
            )
        case "closest_near":
            bannerRow(
                icon: "arrow.trianglehead.clockwise",
                tint: AppColors.warning,
                title: "Closest reasonable plan",
                subtitle: "Your target is close. This plan gets you to FIRE around age \(plan.projectedFireAge)."
            )
        case "exact":
            let currentSave = currentMonthlySavings
            let needsMore = max(0, plan.monthlySave - currentSave)
            if needsMore > 1 {
                bannerRow(
                    icon: "checkmark.seal.fill",
                    tint: AppColors.planDifficultySteady,
                    title: "Target is within reach",
                    subtitle: "Save $\(formattedInt(needsMore))/mo more than today to aim for age \(viewModel.targetRetirementAge)."
                )
            } else {
                bannerRow(
                    icon: "checkmark.seal.fill",
                    tint: AppColors.planDifficultySteady,
                    title: "You have room",
                    subtitle: "Your current pace can support this target. Choose how much flexibility to keep."
                )
            }
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
                .padding(.top, AppSpacing.xxs)
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
        .padding(AppSpacing.cardPadding)
        .bsGlassCard(borderColor: tint.opacity(0.4))
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
                            Text(planTitle(for: plan))
                                .font(.h3)
                                .foregroundStyle(AppColors.inkPrimary)

                            if showBestFit {
                                Text("BEST FIT")
                                    .font(.miniLabel)
                                    .foregroundStyle(AppColors.ctaWhite)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, AppSpacing.xxs)
                                    .background(AppColors.warning)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                            }

                            if let badge = badgeText(for: plan, showBestFit: showBestFit) {
                                Text(badge)
                                    .font(.miniLabel)
                                    .foregroundStyle(AppColors.ctaWhite)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, AppSpacing.xxs)
                                    .background(AppColors.planDifficultyAccelerate)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                            }
                        }

                        HStack(spacing: AppSpacing.xs) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(i < difficulty ? AppColors.inkPrimary : AppColors.inkSoft)
                                    .frame(width: dotSize, height: dotSize)
                            }
                            Text(difficultyLabel)
                                .font(.cardRowMeta)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.inkPrimary)
                                .padding(.leading, AppSpacing.xxs)
                        }
                    }

                    Spacer()

                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(BS_ChoosePathView.selectAccentGradient)
                                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                            Image(systemName: "checkmark")
                                .font(.cardRowMeta)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.ctaWhite)
                        } else {
                            Circle()
                                .stroke(AppColors.inkBorder, lineWidth: 2)
                                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                        }
                    }
                }

                VStack(spacing: AppSpacing.xs) {
                    Text("BUDGET")
                        .font(.cardHeader)
                        .tracking(1.5)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("$\(formattedInt(plan.monthlyBudget))/mo")
                        .font(.display)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                        .accessibilityLabel("Budget \(formattedInt(plan.monthlyBudget)) dollars per month")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)

                HStack(spacing: 0) {
                    statColumnSmall(label: "SAVE", value: "$\(formattedInt(plan.monthlySave))")
                    Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.lg)
                    statColumnSmall(label: "SAVING RATE", value: formattedPct(plan.savingsRate * 100))
                    Rectangle().fill(AppColors.inkBorder).frame(width: 1, height: AppSpacing.lg)
                    statColumnSmall(label: "FIRE AGE", value: "Age \(plan.projectedFireAge)")
                }
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.glassBlockBg)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.glassBlock))

                if isSelected {
                    fireDetailExpand(plan: plan)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .padding(AppSpacing.cardPadding)
            .bsGlassCard(
                borderStyle: isSelected
                    ? AnyShapeStyle(BS_ChoosePathView.selectAccentGradient)
                    : AnyShapeStyle(AppColors.glassCardBorder),
                borderWidth: isSelected ? 2 : 1
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fireDetailExpand(plan: BudgetPlanOption) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            planInsightRows(plan: plan)

            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Image(systemName: "info.circle")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkFaint)
                    .padding(.top, AppSpacing.xxs)
                Text(planDetailCopy(for: plan))
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(3)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.glassBlockBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.glassBlock))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassBlock)
                .stroke(AppColors.glassBlockBorder, lineWidth: 1)
        )
    }

    private var assumptionsNote: some View {
        Text("Projection note: Estimates use the starting asset value available to the model, your selected budget and saving target, a 4% withdrawal rule, and a 4% real return assumption after inflation. Projected portfolio boosts are estimates, not guaranteed returns; actual results can change with income, spending, taxes, market performance, balances, and goals.")
            .font(.cardRowMeta)
            .foregroundStyle(AppColors.inkFaint)
            .lineSpacing(3)
    }

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    await viewModel.loadSpendingPlan()
                    guard viewModel.spendingPlan != nil else { return }
                    await MainActor.run { viewModel.goToStep(.planSet) }
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
        if isEarlyBufferPlan(plan) { return "Earlier FIRE" }

        switch plan.anchor {
        case "target": return "Target"
        case "lifestyle": return "Lifestyle"
        case "acceleration": return "Acceleration"
        default: return "Plan"
        }
    }

    private var currentMonthlySavings: Double {
        viewModel.spendingStats?.avgMonthlySavings
            ?? (viewModel.currentSnapshotIncome - viewModel.currentSnapshotSpend)
    }

    private var currentSavingsRate: Double {
        guard viewModel.currentSnapshotIncome > 0 else { return 0 }
        return max(0, currentMonthlySavings / viewModel.currentSnapshotIncome * 100)
    }

    private func planTitle(for plan: BudgetPlanOption) -> String {
        switch plan.feasibility {
        case "already_fire": return "Already FIRE"
        case "closest_far": return "Fastest reasonable"
        case "closest_near": return "Closest reasonable"
        case "exact":
            let delta = plan.monthlySave - currentMonthlySavings
            if abs(delta) < 1 { return "Keep your pace" }
            return delta < 0 ? "Target pace" : "Hit your target"
        default:
            switch plan.anchor {
            case "lifestyle": return isEarlyBufferPlan(plan) ? "Faster path" : "Comfortable"
            case "acceleration": return "Push harder"
            default: return viewModel.displayName(for: plan.label)
            }
        }
    }

    private func isEarlyBufferPlan(_ plan: BudgetPlanOption) -> Bool {
        guard plan.anchor == "lifestyle" else { return false }
        guard plan.projectedFireAge < viewModel.targetRetirementAge else { return false }
        guard let primary = viewModel.primaryPlan else { return false }
        return plan.monthlySave > primary.monthlySave + 1
    }

    private func badgeText(for plan: BudgetPlanOption, showBestFit: Bool) -> String? {
        if showBestFit { return nil }
        if isEarlyBufferPlan(plan) {
            let yearsEarly = max(1, viewModel.targetRetirementAge - plan.projectedFireAge)
            return "\(yearsEarly)Y EARLY"
        }
        guard let badge = plan.badge, !badge.isEmpty else { return nil }
        return badge.uppercased()
    }

    @ViewBuilder
    private func planInsightRows(plan: BudgetPlanOption) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            detailInsightRow(
                label: "Budget change",
                value: budgetChangeText(for: plan),
                icon: "wallet.pass.fill"
            )
            detailInsightRow(
                label: "Saving rate change",
                value: savingRateChangeText(for: plan),
                icon: "arrow.up.forward.circle.fill"
            )
            detailInsightRow(
                label: "Progress boost",
                value: progressBoostText(for: plan),
                icon: "calendar.badge.clock"
            )
        }
    }

    private func detailInsightRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkFaint)
                .frame(width: AppSpacing.md, alignment: .center)
                .padding(.top, AppSpacing.xxs)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(label.uppercased())
                    .font(.miniLabel)
                    .tracking(0.8)
                    .foregroundStyle(AppColors.inkFaint)
                Text(value)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.glassBlockBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func budgetChangeText(for plan: BudgetPlanOption) -> String {
        let delta = plan.monthlyBudget - viewModel.currentSnapshotSpend
        if abs(delta) < 1 { return "About the same as today" }
        if delta < 0 { return "Spend $\(formattedInt(abs(delta)))/mo less than today" }
        return "Spend $\(formattedInt(delta))/mo more than today"
    }

    private func savingRateChangeText(for plan: BudgetPlanOption) -> String {
        let currentRate = currentSavingsRate
        let planRate = plan.savingsRate * 100
        let delta = planRate - currentRate
        if abs(delta) < 0.05 { return "Same as today at \(formattedPct(planRate))" }
        if delta > 0 {
            return "Increase from \(formattedPct(currentRate)) to \(formattedPct(planRate))"
        }
        return "Decrease from \(formattedPct(currentRate)) to \(formattedPct(planRate))"
    }

    private func progressBoostText(for plan: BudgetPlanOption) -> String {
        let monthlyDelta = plan.monthlySave - currentMonthlySavings
        if abs(monthlyDelta) < 1 {
            return "Similar projected path to today"
        }

        let horizonMonths = max(0, (plan.projectedFireAge - viewModel.currentAge) * 12)
        guard horizonMonths > 0 else {
            return monthlyDelta > 0 ? "Adds more to your FIRE path" : "Keeps more flexibility today"
        }

        let projectedBoost = futureValueOfMonthlyDelta(abs(monthlyDelta), months: horizonMonths)
        if monthlyDelta > 0 {
            return "+$\(formattedInt(monthlyDelta))/mo could add about $\(formattedInt(projectedBoost)) by age \(plan.projectedFireAge)"
        }
        return "$\(formattedInt(abs(monthlyDelta)))/mo less saving could reduce projected assets by about $\(formattedInt(projectedBoost)) by age \(plan.projectedFireAge)"
    }

    private func planDetailCopy(for plan: BudgetPlanOption) -> String {
        let currentSave = currentMonthlySavings
        let delta = plan.monthlySave - currentSave
        let action: String
        if abs(delta) < 1 {
            action = "about the same as today"
        } else if delta > 0 {
            action = "$\(formattedInt(delta))/mo more than today"
        } else {
            action = "$\(formattedInt(abs(delta)))/mo less than today"
        }

        switch plan.feasibility {
        case "closest_far":
            return "This is the earliest path within healthy limits. It saves \(action) and reaches FIRE around age \(plan.projectedFireAge)."
        case "closest_near":
            return "This is the closest reasonable path to your target. It saves \(action) and reaches FIRE around age \(plan.projectedFireAge)."
        case "exact":
            return "This plan is designed around your target age. It saves \(action) with a monthly budget of $\(formattedInt(plan.monthlyBudget))."
        case "already_fire":
            return "You have already reached the modeled FIRE number. Use this plan to set a sustainable monthly budget."
        default:
            if isEarlyBufferPlan(plan) {
                let yearsEarly = max(1, viewModel.targetRetirementAge - plan.projectedFireAge)
                return "This plan keeps a tighter budget than target pace, builds more margin, and projects FIRE about \(yearsEarly) years before your target."
            }
            if plan.anchor == "lifestyle" {
                return "This plan keeps more lifestyle flexibility. It saves \(action), sets a $\(formattedInt(plan.monthlyBudget))/mo budget, and projects FIRE around age \(plan.projectedFireAge)."
            }
            return "This plan saves \(action), sets a $\(formattedInt(plan.monthlyBudget))/mo budget, and projects FIRE around age \(plan.projectedFireAge)."
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

    private func futureValueOfMonthlyDelta(_ monthlyDelta: Double, months: Int) -> Double {
        guard months > 0, monthlyDelta > 0 else { return 0 }
        let monthlyRate = 0.04 / 12.0
        if monthlyRate == 0 { return monthlyDelta * Double(months) }
        let growthFactor = (pow(1 + monthlyRate, Double(months)) - 1) / monthlyRate
        return monthlyDelta * growthFactor
    }

}
