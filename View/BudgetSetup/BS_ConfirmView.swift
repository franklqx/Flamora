//
//  BS_ConfirmView.swift
//  Flamora app
//
//  Budget Setup — Step 6: Confirm & Save (V3, Phase E rewrite)
//
//  Spec (`~/.claude/plans/budget-plan-budget-plan-gentle-blossom.md` §"每页契约" Step 6):
//    • Monthly save · Monthly budget · FIRE progress 进度条
//    • Progress bar shows: $net_worth of $fire_number · 火焰渐变填充
//      · X% complete / ~Xy to age N · ✓ on-track 徽章
//    • already_fire 态：save = $0, budget = retirement_spending_monthly,
//      100% bar + "🎉 You're free" 徽章, 不再展示 ~Xy to age N
//    • 不再单独展示 "Projected FIRE years" / "at age X" — 合并进 progress bar
//

import SwiftUI

struct BS_ConfirmView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    var onComplete: () -> Void

    @State private var showContent = false
    @State private var animatedProgress: Double = 0

    private var isAlreadyFire: Bool {
        viewModel.committedPlanLabel == "already_fire"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    metricsStack
                        .padding(.horizontal, AppSpacing.lg)

                    fireProgressCard
                        .padding(.horizontal, AppSpacing.lg)

                    tipCard
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { showContent = true }
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                    animatedProgress = isAlreadyFire ? 1.0 : viewModel.fireProgressRatio
                }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(isAlreadyFire ? "You're already free" : "Review Plan")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            Text(isAlreadyFire
                 ? "Your net worth already covers your FIRE number. Start tracking your sustainable spending."
                 : "Confirm your monthly commitments. You can adjust these anytime in Settings.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    // MARK: - Metric stack (Monthly save · Monthly budget)

    private var metricsStack: some View {
        VStack(spacing: AppSpacing.cardGap) {
            metricCard(
                title: "MONTHLY SAVE",
                value: monthlySaveDisplay,
                accentTint: AppColors.accentAmber,
                subtitle: monthlySaveSubtitle
            )

            metricCard(
                title: "MONTHLY BUDGET",
                value: monthlyBudgetDisplay,
                accentTint: AppColors.budgetTeal,
                subtitle: monthlyBudgetSubtitle
            )
        }
    }

    private func metricCard(title: String, value: String, accentTint: Color, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)

            Text(value)
                .font(.cardFigurePrimary)
                .foregroundStyle(accentTint)
                .monospacedDigit()

            if let subtitle {
                Text(subtitle)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    // MARK: - FIRE progress card

    private var fireProgressCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("FIRE PROGRESS")
                    .font(.label)
                    .tracking(1)
                    .foregroundStyle(AppColors.inkFaint)
                Spacer()
                progressBadge
            }

            // Headline: net worth / fire number
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("$\(formattedCompact(viewModel.currentNetWorth))")
                    .font(.h2)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
                Text("of $\(formattedCompact(targetFireNumber))")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
                    .monospacedDigit()
            }

            // Progress bar with flame gradient
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(AppColors.glassCardBg)
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(
                            LinearGradient(
                                colors: AppColors.gradientShellAccent,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(animatedProgress)), height: 14)
                }
            }
            .frame(height: 14)

            // Footnote: X% complete · ~Xy to age N (suppressed in already_fire)
            HStack {
                Text(progressPercentText)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                if let etaText {
                    Text("·")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkFaint)
                    Text(etaText)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkSoft)
                }
                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var progressBadge: some View {
        if isAlreadyFire {
            badgePill(text: "🎉 You're free", tint: AppColors.accentAmber)
        } else if viewModel.fireProgressRatio >= 0.999 {
            badgePill(text: "✓ Reached", tint: AppColors.accentAmber)
        } else if isOnTrack {
            badgePill(text: "✓ On track", tint: AppColors.budgetTeal)
        } else {
            EmptyView()
        }
    }

    private func badgePill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.footnoteSemibold)
            .foregroundStyle(tint)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.glassCardBg)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Tip card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm + AppSpacing.xs) {
            Text("\u{1F4A1}")
                .font(.bodyRegular)
            Text("You can adjust your budget anytime in Settings.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkFaint)
                .lineSpacing(3)
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

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            VStack(spacing: 0) {
                Button {
                    Task {
                        let success = await viewModel.finalizeSetup()
                        if success {
                            UserDefaults.standard.set(true, forKey: FlamoraStorageKey.budgetSetupCompleted)
                            onComplete()
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if viewModel.isSaving {
                            ProgressView().tint(AppColors.inkPrimary)
                        }
                        Text(viewModel.isSaving ? "Saving..." : (isAlreadyFire ? "Start tracking" : "Start My Journey"))
                            .font(.sheetPrimaryButton)
                    }
                    .foregroundStyle(AppColors.ctaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.inkPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
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
            .background(AppColors.shellBg2)
        }
    }

    // MARK: - Derived values

    private var monthlySaveDisplay: String {
        if isAlreadyFire { return "$0" }
        let value = viewModel.committedMonthlySave ?? viewModel.spendingPlan?.totalSavings ?? 0
        return "$\(formattedInt(value))"
    }

    private var monthlySaveSubtitle: String? {
        if isAlreadyFire { return "Your portfolio funds itself." }
        let rate = (viewModel.committedSavingsRate ?? 0) * 100
        guard rate > 0 else { return nil }
        return "\(formattedPct(rate)) of monthly income"
    }

    private var monthlyBudgetDisplay: String {
        let value: Double
        if isAlreadyFire {
            value = viewModel.retirementSpendingMonthly
        } else {
            value = viewModel.committedSpendCeiling ?? viewModel.spendingPlan?.totalSpend ?? 0
        }
        return "$\(formattedInt(value))"
    }

    private var monthlyBudgetSubtitle: String? {
        isAlreadyFire ? "Sustainable spending" : "Spend ceiling per month"
    }

    private var targetFireNumber: Double {
        if let plan = viewModel.selectedPlan, plan.fireNumber > 0 { return plan.fireNumber }
        // Fallback: 25× annual retirement spending (4% rule)
        return max(0, viewModel.retirementSpendingMonthly) * 12 / 0.04
    }

    private var progressPercentText: String {
        let pct = isAlreadyFire ? 100 : Int((viewModel.fireProgressRatio * 100).rounded())
        return "\(pct)% complete"
    }

    /// `~Xy to age N` — suppressed in already_fire branch per spec.
    private var etaText: String? {
        if isAlreadyFire { return nil }
        guard let plan = viewModel.selectedPlan else { return nil }
        let age = plan.projectedFireAge
        guard age > viewModel.currentAge else { return nil }
        let years = age - viewModel.currentAge
        return "~\(years)y to age \(age)"
    }

    /// "On track" if user's selected plan hits or beats their target age.
    private var isOnTrack: Bool {
        guard let plan = viewModel.selectedPlan else { return false }
        guard viewModel.targetRetirementAge > 0 else { return false }
        return plan.projectedFireAge <= viewModel.targetRetirementAge
    }

    // MARK: - Formatting helpers

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

    private func formattedCompact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return "\(Int(value / 1_000))K" }
        return formattedInt(value)
    }
}

#Preview {
    BS_ConfirmView(viewModel: BudgetSetupViewModel(), onComplete: {})
}
