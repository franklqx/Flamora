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

    private let goldColor = Color(hex: "F5C842")
    private let gradientColors = [Color(hex: "F5C842"), Color(hex: "E88BC4")]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0A0C").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer().frame(height: 60)

                    headerSection
                        .padding(.horizontal, 26)

                    if viewModel.isLoadingPlans {
                        loadingSection
                    } else if let plans = viewModel.plansResponse {
                        // Plan cards
                        planCard(plan: plans.plans.steady, name: "Steady", type: .steady,
                                 difficulty: 1, difficultyLabel: "Easy", difficultyColor: Color(hex: "5DDEC0"))
                            .padding(.horizontal, 26)

                        planCard(plan: plans.plans.recommended, name: "Recommended", type: .recommended,
                                 difficulty: 2, difficultyLabel: "Moderate", difficultyColor: goldColor,
                                 showBestFit: true)
                            .padding(.horizontal, 26)

                        planCard(plan: plans.plans.accelerate, name: "Accelerate", type: .accelerate,
                                 difficulty: 3, difficultyLabel: "Ambitious", difficultyColor: Color(hex: "F59E42"))
                            .padding(.horizontal, 26)

                        // Custom option
                        customPlanToggle
                            .padding(.horizontal, 26)

                        if showCustom {
                            customPlanSection
                                .padding(.horizontal, 26)
                        }

                        // Disclaimer
                        assumptionsNote
                            .padding(.horizontal, 26)
                    }

                    Spacer().frame(height: 140)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { viewModel.goBack() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "ABABAB"))
            }
            .padding(.bottom, 8)

            Text("Pick Your Plan")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "F2F0ED"))

            Group {
                let avgExpense = viewModel.spendingStats?.avgMonthlyExpenses ?? 0
                if avgExpense > 0 {
                    Text("Choose how much to spend each month. You currently spend ")
                        .foregroundStyle(Color(hex: "ABABAB"))
                    + Text("$\(formattedInt(avgExpense))/mo")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.75))
                    + Text(" on average.")
                        .foregroundStyle(Color(hex: "ABABAB"))
                } else {
                    Text("Choose how much to spend each month.")
                        .foregroundStyle(Color(hex: "ABABAB"))
                }
            }
            .font(.system(size: 14))
            .lineSpacing(3)
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white.opacity(0.5))
            Text("Generating your plans...")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "ABABAB"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Plan Card

    @ViewBuilder
    private func planCard(plan: PlanDetail, name: String, type: BudgetSetupViewModel.PlanSelection,
                          difficulty: Int, difficultyLabel: String, difficultyColor: Color,
                          showBestFit: Bool = false) -> some View {
        let isSelected = viewModel.selectedPlanType == type
        let extraPerMonth = plan.extraPerMonth

        Button {
            withAnimation(.easeOut(duration: 0.3)) {
                viewModel.selectedPlanType = type
                showCustom = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Header row: name + difficulty + radio
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color(hex: "F2F0ED"))

                            if showBestFit {
                                Text("BEST FIT")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(goldColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }

                        // Difficulty dots
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(i < difficulty ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 7, height: 7)
                            }
                            Text(difficultyLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.leading, 2)
                        }
                    }

                    Spacer()

                    // Radio button
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        if isSelected {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }
                }

                // Hero Budget/Mo number
                VStack(spacing: 2) {
                    Text("MONTHLY BUDGET")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.35))
                    Text("$\(formattedInt(plan.monthlySpend))")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color(hex: "F2F0ED"))
                        .monospacedDigit()
                        .accessibilityLabel("Monthly budget \(formattedInt(plan.monthlySpend)) dollars")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // Secondary stats row
                HStack(spacing: 0) {
                    statColumnSmall(label: "SAVE/MO", value: "$\(formattedInt(plan.monthlySave))")
                    Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 24)
                    statColumnSmall(label: "RATE", value: formattedPct(plan.savingsRate))
                }
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Growth tip card (only when selected)
                if isSelected {
                    growthTipCard(plan: plan, planType: type)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .padding(16)
            .background(isSelected ? Color.white.opacity(0.08) : Color(hex: "161619"))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(color: isSelected ? Color.white.opacity(0.05) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color(hex: "8E8E93"))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "F2F0ED"))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statColumnSmall(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "F2F0ED"))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Growth Tip Card

    @ViewBuilder
    private func growthTipCard(plan: PlanDetail, planType: BudgetSetupViewModel.PlanSelection) -> some View {
        let monthlySave = plan.monthlySave
        let g10y = nominalGrowth8pct(monthly: monthlySave, years: 10)
        let greenLabel = Color(red: 0.47, green: 0.90, blue: 0.63)
        let saveColor = Color(hex: "5EEAA0")

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

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("✨")
                    .font(.system(size: 12))
                Text("YOUR POTENTIAL GROWTH")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(greenLabel)
            }

            (Text("$\(formattedCompact(monthlySave))/mo")
                .fontWeight(.bold)
                .foregroundStyle(saveColor)
            + Text(" invested at 8% annual return, grows to ")
                .foregroundStyle(.white.opacity(0.8))
            + Text("$\(formattedCompact(g10y))")
                .fontWeight(.bold)
                .foregroundStyle(.white)
            + Text(" in 10 years.")
                .foregroundStyle(.white.opacity(0.8)))
            .font(.system(size: 14))
            .lineSpacing(3)

            Text(subText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 34/255, green: 120/255, blue: 80/255).opacity(0.35),
                    Color(red: 22/255, green: 80/255, blue: 55/255).opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 52/255, green: 180/255, blue: 100/255).opacity(0.2), lineWidth: 1)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Image(systemName: showCustom ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .padding(16)
            .background(Color(hex: "161619"))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        viewModel.selectedPlanType == .custom ? Color.white : Color(hex: "2A2A30"),
                        lineWidth: viewModel.selectedPlanType == .custom ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var customPlanSection: some View {
        let income = viewModel.spendingStats?.avgMonthlyIncome ?? viewModel.monthlyIncome
        let avgExpense = viewModel.spendingStats?.avgMonthlyExpenses ?? income * 0.8
        let fixedExpense = viewModel.spendingStats?.avgMonthlyFixed ?? avgExpense * 0.5
        let sliderMin: Double = 10_000
        let sliderMax = max((avgExpense * 1.2 / 500).rounded() * 500, sliderMin + 500)
        let budget = customBudgetAmount > 0 ? customBudgetAmount : sliderMin
        let monthlySave = max(0, income - budget)
        let savingsRate = income > 0 ? monthlySave / income * 100 : 0
        let g10y = nominalGrowth8pct(monthly: monthlySave, years: 10)

        // Determine zone
        let zone: CustomZone = {
            if budget <= fixedExpense { return .danger }
            if budget <= fixedExpense * 1.4 { return .warning }
            if budget < avgExpense * 0.7 { return .ambitious }
            return .healthy
        }()

        return VStack(spacing: 16) {
            // Budget display
            VStack(spacing: 6) {
                Text("MONTHLY BUDGET")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.35))

                Text("$\(formattedInt(budget))")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(zone == .danger ? Color(hex: "EF4444") : Color(hex: "F2F0ED"))
                    .monospacedDigit()
                    .animation(.easeOut(duration: 0.15), value: customBudgetAmount)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            // Slider
            Slider(value: $customBudgetAmount, in: sliderMin...sliderMax, step: 500)
                .tint(.white.opacity(0.6))
                .accessibilityLabel("Monthly budget slider")
                .accessibilityValue("$\(formattedInt(budget))")

            HStack {
                Text("$\(formattedCompact(sliderMin))").font(.system(size: 11)).foregroundStyle(Color(hex: "8E8E93"))
                Spacer()
                Text("$\(formattedCompact(sliderMax))").font(.system(size: 11)).foregroundStyle(Color(hex: "8E8E93"))
            }

            // Stats row
            HStack(spacing: 0) {
                statColumnSmall(label: "SAVE/MO", value: "$\(formattedInt(monthlySave))")
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1, height: 24)
                statColumnSmall(label: "RATE", value: formattedPct(savingsRate))
            }
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .animation(.easeOut(duration: 0.15), value: customBudgetAmount)

            // Zone feedback card
            customZoneCard(zone: zone, budget: budget, avgExpense: avgExpense, g10y: g10y, monthlySave: monthlySave)
                .transition(.opacity.combined(with: .offset(y: 4)))
                .animation(.easeOut(duration: 0.25), value: zone)
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .onAppear {
            if customBudgetAmount == 0 {
                let initial = viewModel.plansResponse?.plans.recommended.monthlySpend ?? avgExpense * 0.85
                customBudgetAmount = (initial / 500).rounded() * 500
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
                return ([Color(hex: "7F1D1D").opacity(0.4), Color(hex: "450A0A").opacity(0.3)],
                        Color(hex: "EF4444").opacity(0.3), "⚠️", "NOT ACHIEVABLE")
            case .warning:
                return ([Color(hex: "78350F").opacity(0.4), Color(hex: "431407").opacity(0.3)],
                        Color(hex: "F59E0B").opacity(0.3), "💪", "VERY AGGRESSIVE")
            case .ambitious:
                return ([Color(hex: "1E3A5F").opacity(0.4), Color(hex: "0F2236").opacity(0.3)],
                        Color(hex: "60A5FA").opacity(0.3), "🎯", "AMBITIOUS BUT DOABLE")
            case .healthy:
                return ([Color(red: 34/255, green: 120/255, blue: 80/255).opacity(0.35),
                         Color(red: 22/255, green: 80/255, blue: 55/255).opacity(0.25)],
                        Color(red: 52/255, green: 180/255, blue: 100/255).opacity(0.2), "✨", "YOUR POTENTIAL GROWTH")
            }
        }()

        let bodyText: String = {
            switch zone {
            case .danger:
                return "This budget is below your fixed expenses of $\(formattedInt(viewModel.spendingStats?.avgMonthlyFixed ?? 0))/mo and isn't achievable."
            case .warning:
                return "This leaves very little buffer above your fixed expenses. You'd need to cut most flexible spending."
            case .ambitious:
                return "You're spending less than 70% of your average. This is doable with discipline and a clear plan."
            case .healthy:
                return "Investing $\(formattedCompact(monthlySave))/mo at 8% annual return grows to $\(formattedCompact(g10y)) in 10 years."
            }
        }()

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(config.icon).font(.system(size: 12))
                Text(config.label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(bodyText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .lineSpacing(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: config.bg, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(config.border, lineWidth: 1))
    }

    // MARK: - Assumptions Note

    private var assumptionsNote: some View {
        Text("Growth projections assume 8% annual return (5.5% after inflation) based on S&P 500 historical performance.")
            .font(.system(size: 11))
            .foregroundStyle(Color(hex: "8E8E93"))
            .lineSpacing(3)
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: "0A0A0C").opacity(0), Color(hex: "0A0A0C")], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)

            Button {
                Task { await viewModel.loadSpendingPlan() }
                viewModel.goToStep(.confirm)
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                            .opacity(viewModel.selectedPlan != nil && !viewModel.isLoadingPlans ? 1 : 0.4)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(viewModel.selectedPlan == nil || viewModel.isLoadingPlans)
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
            .background(Color(hex: "0A0A0C"))
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
        if value == value.rounded() {
            return "\(Int(value))%"
        }
        return String(format: "%.1f%%", value)
    }

    private func formattedCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return "\(Int(value / 1_000))K"
        }
        return formattedInt(value)
    }
}

#Preview {
    BS_ChoosePathView(viewModel: BudgetSetupViewModel())
}
