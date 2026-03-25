//
//  BS_FireGoalView.swift
//  Flamora app
//
//  Budget Setup — Step 3: FIRE Goal + Reality Calibration
//  User sets target retirement age, system shows achievability + plan options
//

import SwiftUI

struct BS_FireGoalView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    // Animation states
    @State private var showResults = false
    @State private var showBanner = false
    @State private var showCards = false
    @State private var showCTA = false
    @State private var showInfoSheet = false

    // Gradient colors
    private let gradientColors = [Color(hex: "F5D76E"), Color(hex: "E8829B"), Color(hex: "B4A0E5")]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 56)

                    // Header
                    headerSection
                        .padding(.horizontal, 26)
                        .padding(.bottom, 24)

                    if !viewModel.hasCalculated {
                        // Phase 1: Age selector
                        ageSelector
                            .padding(.horizontal, 26)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        // Phase 2: Results
                        resultsSection
                            .padding(.horizontal, 26)
                    }

                    Spacer().frame(height: 140)
                }
            }

            // Sticky CTA
            stickyBottomCTA
        }
        .animation(.easeOut(duration: 0.5), value: viewModel.hasCalculated)
        .sheet(isPresented: $showInfoSheet) { infoSheet }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Back button
            Button {
                viewModel.goBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.bodySmall)
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 8)

            Text("The Big Picture")
                .font(.cardFigurePrimary)
                .foregroundStyle(.white)

            Text("What's your target retirement age?")
                .font(.bodySmall)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Age Selector

    private var ageSelector: some View {
        VStack(spacing: 20) {
            // Age card
            VStack(spacing: 16) {
                HStack {
                    // Minus button
                    Button {
                        if viewModel.targetRetirementAge > viewModel.minTargetAge {
                            viewModel.targetRetirementAge -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.h4)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppColors.overlayWhiteStroke)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Age number
                    Text("\(viewModel.targetRetirementAge)")
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Spacer()

                    // Plus button
                    Button {
                        if viewModel.targetRetirementAge < viewModel.maxTargetAge {
                            viewModel.targetRetirementAge += 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.h4)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppColors.overlayWhiteStroke)
                            .clipShape(Circle())
                    }
                }

                // Slider
                Slider(
                    value: Binding(
                        get: { Double(viewModel.targetRetirementAge) },
                        set: { viewModel.targetRetirementAge = Int($0) }
                    ),
                    in: Double(viewModel.minTargetAge)...Double(viewModel.maxTargetAge),
                    step: 1
                )
                .tint(Color(hex: "F5D76E"))

                // Min/Max labels
                HStack {
                    Text("\(viewModel.minTargetAge)")
                        .font(.cardHeader)
                        .foregroundStyle(.white.opacity(0.3))
                    Spacer()
                    Text("\(viewModel.maxTargetAge)")
                        .font(.cardHeader)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(20)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
            )

            // Assumption text
            Text("Your plan assumes monthly savings are invested with an average 9% annual return, based on S&P 500 historical performance net of fees.*")
                .font(.cardHeader)
                .foregroundStyle(.white.opacity(0.3))
                .lineSpacing(3)
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: 16) {
            // Phase banner
            if let result = viewModel.fireGoalResult {
                phaseBanner(for: result)
                    .opacity(showBanner ? 1 : 0)
                    .offset(y: showBanner ? 0 : 10)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                            showBanner = true
                        }
                    }
            }

            // Plan cards
            if let result = viewModel.fireGoalResult {
                planCardsSection(for: result)
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 10)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                            showCards = true
                        }
                    }
            }

            // Income growth hint
            if let hint = viewModel.fireGoalResult?.incomeGrowthHint {
                incomeGrowthHint(hint)
                    .opacity(showCards ? 1 : 0)
            }

            // Disclaimer
            HStack {
                Button { showInfoSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.cardHeader)
                        Text("How this is calculated")
                            .font(.cardHeader)
                    }
                    .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
            }
            .padding(.top, 8)
            .opacity(showCards ? 1 : 0)
        }
    }

    // MARK: - Phase Banner

    @ViewBuilder
    private func phaseBanner(for result: FireGoalResponse) -> some View {
        let config = bannerConfig(for: result)

        HStack(alignment: .top, spacing: 12) {
            Text(config.icon)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text(config.title)
                    .font(.bodySemibold)
                    .foregroundStyle(config.color)

                Text(config.message)
                    .font(.footnoteRegular)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(config.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(config.color.opacity(0.2), lineWidth: 1)
        )
    }

    private struct BannerConfig {
        let icon: String
        let title: String
        let message: String
        let color: Color
    }

    private func bannerConfig(for result: FireGoalResponse) -> BannerConfig {
        switch result.effectivePhaseSub {
        case "0a":
            return BannerConfig(
                icon: "🎉",
                title: "You're already financially free!",
                message: "Your net worth already exceeds your FIRE number. Your budget will help you stay on track and enjoy it.",
                color: Color(hex: "4ADE80")
            )
        case "0b":
            return BannerConfig(
                icon: "🎉",
                title: "Your goal is achievable!",
                message: "At your current savings rate of \(formatted(result.currentPath.savingsRate))%, you'll reach financial freedom by age \(result.currentPath.retirementAge). No changes needed — just stay consistent.",
                color: Color(hex: "4ADE80")
            )
        case "0c":
            let yearsAhead = viewModel.targetRetirementAge - result.currentPath.retirementAge
            return BannerConfig(
                icon: "🎉",
                title: "You're ahead of schedule!",
                message: "At your current pace, you'll reach freedom by age \(result.currentPath.retirementAge) — that's \(yearsAhead) years before your target. Keep it up!",
                color: Color(hex: "4ADE80")
            )
        case "0d":
            let gap = result.currentPath.retirementAge - viewModel.targetRetirementAge
            let extraPerMonth = (result.planA?.monthlySavings ?? 0) - result.currentPath.monthlySavings
            return BannerConfig(
                icon: "🎉",
                title: "Your goal is within reach!",
                message: "You're just \(gap) \(gap == 1 ? "year" : "years") away from your target. A small bump in savings — +$\(formatted(extraPerMonth))/mo — gets you there.",
                color: Color(hex: "4ADE80")
            )
        case "1":
            return BannerConfig(
                icon: "⚡",
                title: "Let's find your sweet spot",
                message: "Retiring at \(viewModel.targetRetirementAge) would mean saving \(formatted(result.requiredSavingsRate))% of your income. That's ambitious — here are a few paths to choose from:",
                color: Color(hex: "FB923C")
            )
        case "2":
            return BannerConfig(
                icon: "🎯",
                title: "Let's set a more realistic target",
                message: "Retiring at \(viewModel.targetRetirementAge) would require saving \(formatted(result.requiredSavingsRate))% of your income — that doesn't leave enough for daily life. Here are paths that actually work:",
                color: Color(hex: "EF4444")
            )
        default:
            return BannerConfig(icon: "💡", title: "Your plan", message: "", color: .white)
        }
    }

    // MARK: - Plan Cards

    @ViewBuilder
    private func planCardsSection(for result: FireGoalResponse) -> some View {
        VStack(spacing: 12) {
            // Phase 0: single card (auto-selected)
            if result.phase == 0 {
                if result.effectivePhaseSub == "0d", let planA = result.planA {
                    planCard(
                        plan: planA,
                        planType: "plan_a",
                        subtitle: "Small adjustment to hit your target",
                        showDelta: true,
                        currentRate: result.currentPath.savingsRate,
                        currentSavings: result.currentPath.monthlySavings
                    )
                } else {
                    planCard(
                        plan: result.currentPath,
                        planType: "current",
                        subtitle: "Stay on your current path"
                    )
                }
            }

            // Phase 1: Plan A + Recommended + Plan B
            if result.phase == 1 {
                if let planA = result.planA {
                    planCard(plan: planA, planType: "plan_a", subtitle: "Increase savings")
                }
                if let rec = result.recommended {
                    planCard(plan: rec, planType: "recommended", subtitle: "Best balance of speed and comfort", isRecommended: true)
                }
                planCard(plan: result.currentPath, planType: "plan_b", subtitle: "Keep current savings")
            }

            // Phase 2: Recommended + Plan B only
            if result.phase == 2 {
                if let rec = result.recommended {
                    planCard(plan: rec, planType: "recommended", subtitle: "Best balance of speed and comfort", isRecommended: true)
                }
                planCard(plan: result.currentPath, planType: "plan_b", subtitle: "Keep current savings")
            }
        }
    }

    @ViewBuilder
    private func planCard(
        plan: FireGoalPlan,
        planType: String,
        subtitle: String,
        isRecommended: Bool = false,
        showDelta: Bool = false,
        currentRate: Double = 0,
        currentSavings: Double = 0
    ) -> some View {
        let isSelected = viewModel.selectedPlanType == planType

        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                viewModel.selectedPlanType = planType
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Recommended badge
                if isRecommended {
                    Text("RECOMMENDED")
                        .font(.miniLabel)
                        .tracking(0.08 * 9)
                        .foregroundStyle(Color(hex: "F5D76E"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "F5D76E").opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Title + Feasibility badge
                HStack {
                    Text("Retire at \(plan.retirementAge)")
                        .font(.h4)
                        .foregroundStyle(.white)
                    Spacer()
                    feasibilityBadge(plan.feasibility)
                }

                // Subtitle
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))

                // Stats row
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SAVE RATE")
                            .font(.miniLabel)
                            .tracking(0.08 * 9)
                            .foregroundStyle(.white.opacity(0.3))

                        if showDelta {
                            HStack(spacing: 4) {
                                Text("\(formatted(plan.savingsRate))%")
                                    .font(.bodySemibold)
                                    .foregroundStyle(.white)
                                Text("+\(formatted(plan.savingsRate - currentRate))%")
                                    .font(.smallLabel)
                                    .foregroundStyle(Color(hex: "4ADE80"))
                            }
                        } else {
                            Text("\(formatted(plan.savingsRate))%")
                                .font(.bodySemibold)
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MONTHLY")
                            .font(.miniLabel)
                            .tracking(0.08 * 9)
                            .foregroundStyle(.white.opacity(0.3))

                        if showDelta {
                            HStack(spacing: 4) {
                                Text("$\(formatted(plan.monthlySavings))")
                                    .font(.bodySemibold)
                                    .foregroundStyle(.white)
                                Text("+$\(formatted(plan.monthlySavings - currentSavings))")
                                    .font(.smallLabel)
                                    .foregroundStyle(Color(hex: "4ADE80"))
                            }
                        } else {
                            Text("$\(formatted(plan.monthlySavings))")
                                .font(.bodySemibold)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color(hex: "2A2A2E")),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feasibility Badge

    @ViewBuilder
    private func feasibilityBadge(_ feasibility: String) -> some View {
        let (label, color) = feasibilityInfo(feasibility)
        Text(label)
            .font(.label)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func feasibilityInfo(_ feasibility: String) -> (String, Color) {
        switch feasibility {
        case "comfortable": return ("Comfortable", Color(hex: "4ADE80"))
        case "balanced":    return ("Balanced", Color(hex: "F5D76E"))
        case "aggressive":  return ("Aggressive", Color(hex: "FB923C"))
        case "unrealistic": return ("Unrealistic", Color(hex: "EF4444"))
        default:            return ("—", .gray)
        }
    }

    // MARK: - Income Growth Hint

    @ViewBuilder
    private func incomeGrowthHint(_ hint: IncomeGrowthHint) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("💡")
                .font(.bodySmall)

            VStack(alignment: .leading, spacing: 2) {
                Text("What if your income grows?")
                    .font(.footnoteSemibold)
                    .foregroundStyle(.white.opacity(0.7))
                Text("If your income increases to $\(formatted(hint.requiredIncome))/mo, your original target becomes achievable at \(Int(hint.targetRate))% savings rate.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardTopHighlight, lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            // Fade gradient
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            VStack(spacing: 8) {
                if !viewModel.hasCalculated {
                    // Calculate button
                    Button {
                        Task { await viewModel.calculateFireGoal() }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isCalculating {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text(viewModel.isCalculating ? "Calculating..." : "Calculate My Plan")
                                .font(.figureSecondarySemibold)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 100))
                    }
                    .disabled(viewModel.isCalculating)

                    Text("See how your target holds up")
                        .font(.cardHeader)
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    // Set My Budget button
                    Button {
                        Task {
                            let success = await viewModel.saveFireGoalAndProceed()
                            if success {
                                viewModel.goToStep(.setBudget)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text("Set My Budget →")
                                .font(.figureSecondarySemibold)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .opacity(viewModel.selectedPlan != nil ? 1 : 0.4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 100))
                    }
                    .disabled(viewModel.selectedPlan == nil || viewModel.isSaving)

                    Text("Next: Allocate your budget")
                        .font(.cardHeader)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
            .background(Color.black)
        }
    }

    // MARK: - Info Sheet

    private var infoSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How this is calculated")
                .font(.h4)
                .foregroundStyle(.white)
                .padding(.bottom, 4)

            infoRow(label: "Annual return", value: "9%")
            infoRow(label: "Withdrawal rate", value: "4% (25× rule)")
            if let result = viewModel.fireGoalResult {
                infoRow(label: "Your FIRE number", value: "$\(formatted(result.fireNumber))")
            }

            Divider().background(AppColors.cardTopHighlight)

            Text("Based on the historical nominal return of the S&P 500 (~10% annually since 1957), adjusted for estimated fees. Projections assume consistent monthly contributions and reinvested returns. Actual results vary with market conditions. This tool provides estimates for planning purposes only and does not constitute financial advice. Past performance does not guarantee future results.")
                .font(.cardHeader)
                .foregroundStyle(.white.opacity(0.3))
                .lineSpacing(3)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.medium])
        .presentationBackground(Color(white: 0.12))
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.bodySmall)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.inlineFigureBold)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Formatting Helpers

    private func formatted(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 10_000 {
            return String(format: "%.0f", value)
        } else if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

#Preview {
    BS_FireGoalView(viewModel: BudgetSetupViewModel())
}
