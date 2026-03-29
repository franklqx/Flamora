//
//  BS_ConfirmView.swift
//  Flamora app
//
//  Budget Setup — Step 6: Confirm & Save
//  V2: Budget ring + extra savings compound growth + plan details
//

import SwiftUI

struct BS_ConfirmView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    var onComplete: () -> Void

    private let gradientColors = [Color(hex: "F5C842"), Color(hex: "E88BC4"), Color(hex: "B4A0E5")]
    private let purpleColor = Color(hex: "C084FC")
    private let tealColor = Color(hex: "34D399")
    private let goldColor = Color(hex: "FBBF24")

    @State private var showContent = false
    @State private var ringProgress: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0A0A0C").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer().frame(height: 60)

                    headerSection
                        .padding(.horizontal, 26)

                    if let plan = viewModel.spendingPlan, let selected = viewModel.selectedPlan {
                        budgetSummaryRing(plan: plan, selectedPlan: selected)
                            .padding(.horizontal, 26)

                        planDetailsCard(plan: plan, selectedPlan: selected)
                            .padding(.horizontal, 26)

                        tipCard
                            .padding(.horizontal, 26)
                    }

                    Spacer().frame(height: 140)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { showContent = true }
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) { ringProgress = 1.0 }
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

            Text("Your Plan")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "F2F0ED"))
        }
    }

    // MARK: - Budget Summary Ring

    private func budgetSummaryRing(plan: SpendingPlanResponse, selectedPlan: PlanDetail) -> some View {
        let budgetTotal = plan.fixedBudget.total + plan.flexibleBudget.total
        let fixedFrac = budgetTotal > 0 ? plan.fixedBudget.total / budgetTotal : 0.5

        return VStack(spacing: 20) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 20)
                    .frame(width: 200, height: 200)

                // Fixed arc (purple) with round caps
                Circle()
                    .trim(from: 0, to: fixedFrac * ringProgress)
                    .stroke(purpleColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Flexible arc (teal) with round caps
                Circle()
                    .trim(from: fixedFrac * ringProgress, to: ringProgress)
                    .stroke(tealColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("MONTHLY BUDGET")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("$\(formattedInt(selectedPlan.monthlySpend))")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(hex: "F2F0ED"))
                        .monospacedDigit()
                }
            }

            // Legend — side by side
            HStack(spacing: 32) {
                legendItem(color: purpleColor, label: "Fixed", amount: plan.fixedBudget.total)
                legendItem(color: tealColor, label: "Flexible", amount: plan.flexibleBudget.total)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String, amount: Double) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "ABABAB"))
                Text("$\(formattedInt(amount))")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "F2F0ED"))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Plan Details Card

    private func planDetailsCard(plan: SpendingPlanResponse, selectedPlan: PlanDetail) -> some View {
        let income = viewModel.spendingStats?.avgMonthlyIncome ?? viewModel.monthlyIncome
        let rows: [(label: String, value: String, isRate: Bool)] = [
            ("Plan", viewModel.selectedPlanName, false),
            ("Monthly income", "$\(formattedInt(income))", false),
            ("Monthly budget", "$\(formattedInt(selectedPlan.monthlySpend))", false),
            ("Monthly savings", "$\(formattedInt(selectedPlan.monthlySave))", false),
            ("Savings rate", formattedPct(selectedPlan.savingsRate), true)
        ]

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                }
                HStack {
                    Text(row.label)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text(row.value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(row.isRate ? goldColor : Color(hex: "F2F0ED"))
                        .monospacedDigit()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\u{1F4A1}")
                .font(.system(size: 16))
            Text("You can adjust your budget anytime in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.35))
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: "0A0A0C").opacity(0), Color(hex: "0A0A0C")], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)

            VStack(spacing: 0) {
                Button {
                    Task {
                        let success = await viewModel.saveFinalBudget()
                        if success { onComplete() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView().tint(.white)
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Start My Journey")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "E88BC4").opacity(0.25), radius: 16, y: 8)
                }
                .disabled(viewModel.isSaving)

                if let error = viewModel.saveError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "F56B6B"))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
            .background(Color(hex: "0A0A0C"))
        }
    }

    // MARK: - Helpers

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formattedPct(_ value: Double) -> String {
        if value == value.rounded() { return "\(Int(value))%" }
        return String(format: "%.1f%%", value)
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
