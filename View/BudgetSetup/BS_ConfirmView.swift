//
//  BS_ConfirmView.swift
//  Flamora app
//
//  Budget Setup — Step 5: Confirm & Save
//  Final review before entering the main app
//

import SwiftUI

struct BS_ConfirmView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    var onComplete: () -> Void

    // Gradient
    private let gradientColors = [Color(hex: "F5D76E"), Color(hex: "E8829B"), Color(hex: "B4A0E5")]

    // Animation
    @State private var showContent = false
    @State private var ringProgress: Double = 0
    @State private var showInfoSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer().frame(height: 56)

                    // Header
                    headerSection
                        .padding(.horizontal, 26)

                    // Budget summary ring
                    budgetSummaryRing
                        .padding(.horizontal, 26)

                    // FIRE impact card
                    fireImpactCard
                        .padding(.horizontal, 26)

                    // Tip card
                    tipCard
                        .padding(.horizontal, 26)

                    Spacer().frame(height: 140)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    showContent = true
                }
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                    ringProgress = 1.0
                }
            }

            // Sticky CTA
            stickyBottomCTA
        }
        .sheet(isPresented: $showInfoSheet) { infoSheet }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.goBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 8)

            // Checkmark icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1C1C1E"))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "4ADE80"))
            }
            .padding(.bottom, 4)

            Text("Your FIRE Plan")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("Review and confirm your budget.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Budget Summary Ring

    private var budgetSummaryRing: some View {
        VStack(spacing: 16) {
            Text("MONTHLY BUDGET")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.08 * 9)
                .foregroundStyle(.white.opacity(0.3))

            // Ring chart
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 20)
                    .frame(width: 160, height: 160)

                // Needs arc (purple)
                let needsFraction = viewModel.needsRatio / 100
                let wantsFraction = viewModel.wantsRatio / 100
                let savingsFraction = viewModel.savingsRatio / 100

                Circle()
                    .trim(from: 0, to: needsFraction * ringProgress)
                    .stroke(Color(hex: "B4A0E5"), style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                // Wants arc (teal)
                Circle()
                    .trim(from: needsFraction, to: (needsFraction + wantsFraction) * ringProgress)
                    .stroke(Color(hex: "6BB8C4"), style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                // Savings arc (gradient approximation — use pink)
                Circle()
                    .trim(from: needsFraction + wantsFraction, to: (needsFraction + wantsFraction + savingsFraction) * ringProgress)
                    .stroke(Color(hex: "E8829B"), style: StrokeStyle(lineWidth: 20, lineCap: .butt))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 2) {
                    Text("$\(formattedInt(viewModel.monthlyIncome))")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("income")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // Legend rows
            VStack(spacing: 10) {
                legendRow(
                    color: Color(hex: "B4A0E5"),
                    label: "Needs",
                    percent: Int(viewModel.needsRatio),
                    amount: viewModel.needsBudget
                )
                legendRow(
                    color: Color(hex: "6BB8C4"),
                    label: "Wants",
                    percent: Int(viewModel.wantsRatio),
                    amount: viewModel.wantsBudget
                )
                legendRow(
                    color: Color(hex: "E8829B"),
                    label: "Savings",
                    percent: Int(viewModel.savingsRatio),
                    amount: viewModel.savingsAmount
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func legendRow(color: Color, label: String, percent: Int, amount: Double) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text("\(percent)%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
            Text("$\(formattedInt(amount))")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
        }
    }

    // MARK: - FIRE Impact Card

    private var fireImpactCard: some View {
        let targetAge = viewModel.selectedPlan?.retirementAge ?? 0
        let diff = targetAge - viewModel.freedomAge

        return VStack(alignment: .leading, spacing: 16) {
            Text("FIRE IMPACT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.08 * 9)
                .foregroundStyle(.white.opacity(0.3))

            // Large age
            Text("Age \(viewModel.freedomAge)")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()

            // Status message
            Group {
                if diff == 0 {
                    Text("You'll reach financial freedom at your target age")
                } else if diff > 0 {
                    Text("You'll reach freedom \(diff) \(diff == 1 ? "year" : "years") ahead of your target")
                } else {
                    Text("\(abs(diff)) \(abs(diff) == 1 ? "year" : "years") behind your target — consider increasing savings")
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.5))

            // Three stats row
            HStack(spacing: 0) {
                statItem(
                    label: "Savings Rate",
                    value: "\(Int(viewModel.savingsRatio))%",
                    color: viewModel.savingsRatio >= (viewModel.selectedPlan?.savingsRate ?? 0)
                        ? Color(hex: "4ADE80") : Color(hex: "FB923C")
                )

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 36)

                statItem(
                    label: "Monthly Savings",
                    value: "$\(formattedInt(viewModel.savingsAmount))",
                    color: .white
                )

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 36)

                statItem(
                    label: "FIRE Number",
                    value: "$\(formattedCompact(viewModel.fireGoalResult?.fireNumber ?? 0))",
                    color: .white
                )
            }

            // Disclaimer link
            Button { showInfoSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("Based on 9% annual return assumption")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "F5D76E").opacity(0.05),
                                    Color(hex: "B4A0E5").opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.08 * 9)
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💡")
                .font(.system(size: 16))

            Text("You can always adjust your budget and FIRE goal later in Settings. We'll track your progress and send alerts when you're close to your limits.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
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
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            VStack(spacing: 8) {
                Button {
                    Task {
                        let success = await viewModel.saveFinalBudget()
                        if success {
                            onComplete()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Start My Journey 🚀")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 100))
                    .shadow(color: Color(hex: "E8829B").opacity(0.25), radius: 16, y: 8)
                }
                .disabled(viewModel.isSaving)

                Text("Your budget and FIRE goal will be saved")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))

                // Error message
                if let error = viewModel.saveError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "EF4444"))
                        .padding(.top, 4)
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
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 4)

            infoRow(label: "Annual return assumption", value: "9%")
            infoRow(label: "Withdrawal rate", value: "4% (25× rule)")
            if let result = viewModel.fireGoalResult {
                infoRow(label: "Your FIRE number", value: "$\(formattedCompact(result.fireNumber))")
            }
            infoRow(label: "Monthly savings", value: "$\(formattedInt(viewModel.savingsAmount))")

            Divider().background(Color.white.opacity(0.06))

            Text("Based on the historical nominal return of the S&P 500 (~10% annually since 1957), adjusted for estimated fees. Projections assume consistent monthly contributions and reinvested returns. Actual results vary with market conditions. This tool provides estimates for planning purposes only and does not constitute financial advice. Past performance does not guarantee future results.")
                .font(.system(size: 11))
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
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helpers

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
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
    BS_ConfirmView(viewModel: BudgetSetupViewModel(), onComplete: {})
}
