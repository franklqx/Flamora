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
                    .foregroundStyle(AppColors.accentAmber)
                    .frame(width: 32, height: 32)
                    .background(AppColors.glassCardBg)
                    .clipShape(Circle())
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.glassCardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            )
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
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
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
                tint: AppColors.budgetTeal,
                title: "You're already financially free",
                subtitle: "Choose a monthly budget to start tracking sustainable spending."
            )
        case "closest_far":
            bannerRow(
                icon: "exclamationmark.triangle.fill",
                tint: AppColors.budgetOrange,
                title: "Your target needs adjustment",
                subtitle: "The earliest reasonable path reaches FIRE at age \(plan.projectedFireAge)."
            )
        case "closest_near":
            bannerRow(
                icon: "arrow.trianglehead.clockwise",
                tint: goldColor,
                title: "Closest reasonable plan",
                subtitle: "Your target is close. This plan gets you to FIRE around age \(plan.projectedFireAge)."
            )
        case "exact":
            let currentSave = currentMonthlySavings
            let needsMore = max(0, plan.monthlySave - currentSave)
            if needsMore > 1 {
                bannerRow(
                    icon: "checkmark.seal.fill",
                    tint: AppColors.budgetTeal,
                    title: "Target is within reach",
                    subtitle: "Save $\(formattedInt(needsMore))/mo more than today to aim for age \(viewModel.targetRetirementAge)."
                )
            } else {
                bannerRow(
                    icon: "checkmark.seal.fill",
                    tint: AppColors.budgetTeal,
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
                            Text(planTitle(for: plan))
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
            planInsightRows(plan: plan)

            HStack(alignment: .top, spacing: AppSpacing.sm - 2) {
                Image(systemName: "info.circle")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkFaint)
                    .padding(.top, 1)
                Text(planDetailCopy(for: plan))
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
            return plan.monthlySave <= currentMonthlySavings + 1 ? "Keep your pace" : "Hit your target"
        default:
            switch plan.anchor {
            case "lifestyle": return "Comfortable"
            case "acceleration": return "Push harder"
            default: return viewModel.displayName(for: plan.label)
            }
        }
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
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
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
        .background(AppColors.glassCardBg)
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
