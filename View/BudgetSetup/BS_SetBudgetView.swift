//
//  BS_SetBudgetView.swift
//  Flamora app
//
//  Budget Setup — Step 4: Set Budget (Needs / Wants)
//  User allocates remaining income (after savings) between Needs and Wants
//

import SwiftUI

struct BS_SetBudgetView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    // Gradient
    private let gradientColors = [Color(hex: "F5D76E"), Color(hex: "E8829B"), Color(hex: "B4A0E5")]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer().frame(height: 56)

                    // Header
                    headerSection
                        .padding(.horizontal, 26)

                    // Target summary cards
                    targetSummaryCards
                        .padding(.horizontal, 26)

                    // Disclaimer under summary cards
                    Text("*Based on 9% annual return assumption")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.horizontal, 26)

                    // Needs card
                    needsCard
                        .padding(.horizontal, 26)

                    // Wants card
                    wantsCard
                        .padding(.horizontal, 26)

                    // Monthly split bar
                    monthlySplitBar
                        .padding(.horizontal, 26)

                    Spacer().frame(height: 140)
                }
            }

            // Sticky CTA
            stickyBottomCTA
        }
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

            Text("Set Your Budget")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("Based on your FIRE goal and real spending data.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Target Summary Cards

    private var targetSummaryCards: some View {
        HStack(spacing: 12) {
            // Target age
            VStack(alignment: .leading, spacing: 8) {
                Text("TARGET AGE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.08 * 9)
                    .foregroundStyle(.white.opacity(0.3))

                Text("\(viewModel.selectedPlan?.retirementAge ?? 0)")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
            )

            // Monthly savings
            VStack(alignment: .leading, spacing: 8) {
                Text("MONTHLY SAVINGS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.08 * 9)
                    .foregroundStyle(.white.opacity(0.3))

                Text("$\(formattedInt(viewModel.savingsAmount))")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Color(hex: "F5D76E"))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
            )
        }
    }

    // MARK: - Needs Card

    private var needsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "B4A0E5"))
                        .frame(width: 8, height: 8)
                    Text("NEEDS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.08 * 9)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Text("$\(formattedInt(viewModel.needsBudget)) /mo")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            // Needs slider
            if let spending = viewModel.avgSpending {
                let minVal = spending.avgMonthlyNeeds * 0.50
                let maxVal = viewModel.remaining

                Slider(
                    value: Binding(
                        get: { viewModel.needsBudget },
                        set: { viewModel.adjustNeeds(to: $0) }
                    ),
                    in: minVal...max(minVal + 1, maxVal),
                    step: 10
                )
                .tint(Color(hex: "B4A0E5"))
            }

            // Warning
            warningView

            // Category breakdown
            if !viewModel.needsCategories.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.needsCategories) { category in
                        HStack {
                            Text(category.name)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("$\(formattedInt(category.amount))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.top, 4)
            }

            // Footer
            Text("Based on your past 6 months average")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.25))
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
        )
    }

    // MARK: - Warning View

    @ViewBuilder
    private var warningView: some View {
        switch viewModel.needsWarning {
        case .none:
            EmptyView()
        case .belowAverage:
            warningBanner(
                message: "Below your typical spending — make sure this is realistic",
                color: Color(hex: "FB923C")
            )
        case .significantlyBelow:
            warningBanner(
                message: "Significantly below your essential spending. Rent, utilities, and groceries are hard to cut.",
                color: Color(hex: "EF4444")
            )
        case .noRoomForWants:
            warningBanner(
                message: "Your savings target leaves no room for flexible spending. Consider adjusting your FIRE goal.",
                color: Color(hex: "EF4444")
            )
        }
    }

    @ViewBuilder
    private func warningBanner(message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(color.opacity(0.9))
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Wants Card

    private var wantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "6BB8C4"))
                        .frame(width: 8, height: 8)
                    Text("WANTS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.08 * 9)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if let spending = viewModel.avgSpending {
                    Text("Avg: $\(formattedInt(spending.avgMonthlyWants))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            // Amount
            Text("$\(formattedInt(viewModel.wantsBudget)) /mo")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()

            // Comparison badge
            if let spending = viewModel.avgSpending {
                let diff = viewModel.wantsBudget - spending.avgMonthlyWants
                if diff >= 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                        Text("+$\(formattedInt(diff)) buffer")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "4ADE80"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "4ADE80").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10))
                        Text("-$\(formattedInt(abs(diff))) less than usual")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "FB923C"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "FB923C").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Explanation
            Text("This is your flexible spending — dining, shopping, entertainment, travel.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
                .lineSpacing(2)
        }
        .padding(16)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
        )
    }

    // MARK: - Monthly Split Bar

    private var monthlySplitBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR MONTHLY SPLIT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.08 * 9)
                .foregroundStyle(.white.opacity(0.3))

            // Bar
            GeometryReader { geo in
                let total = viewModel.monthlyIncome
                let needsPct = total > 0 ? viewModel.needsBudget / total : 0
                let wantsPct = total > 0 ? viewModel.wantsBudget / total : 0
                let savingsPct = total > 0 ? viewModel.savingsAmount / total : 0

                HStack(spacing: 2) {
                    // Needs segment
                    if needsPct > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "B4A0E5"))
                            .frame(width: geo.size.width * needsPct)
                            .overlay(
                                Text("\(Int(needsPct * 100))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .opacity(needsPct > 0.12 ? 1 : 0)
                            )
                    }

                    // Wants segment
                    if wantsPct > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "6BB8C4"))
                            .frame(width: geo.size.width * wantsPct)
                            .overlay(
                                Text("\(Int(wantsPct * 100))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .opacity(wantsPct > 0.12 ? 1 : 0)
                            )
                    }

                    // Savings segment
                    if savingsPct > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * savingsPct)
                            .overlay(
                                Text("\(Int(savingsPct * 100))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .opacity(savingsPct > 0.12 ? 1 : 0)
                            )
                    }
                }
            }
            .frame(height: 28)

            // Labels
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "B4A0E5")).frame(width: 6, height: 6)
                    Text("Needs $\(formattedInt(viewModel.needsBudget))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "6BB8C4")).frame(width: 6, height: 6)
                    Text("Wants $\(formattedInt(viewModel.wantsBudget))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "F5D76E")).frame(width: 6, height: 6)
                    Text("Save $\(formattedInt(viewModel.savingsAmount))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "2A2A2E"), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.2), value: viewModel.needsBudget)
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
                    viewModel.goToStep(.confirm)
                } label: {
                    Text("Review Plan →")
                        .font(.system(size: 15, weight: .semibold))
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

                Text("Next: Review and confirm your plan")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
            .background(Color.black)
        }
    }

    // MARK: - Helpers

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview {
    BS_SetBudgetView(viewModel: BudgetSetupViewModel())
}
