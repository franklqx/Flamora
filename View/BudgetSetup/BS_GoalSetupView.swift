//
//  BS_GoalSetupView.swift
//  Flamora app
//
//  Budget Setup — Step 0: Minimum Goal Setup
//  Collects retirement spending + lifestyle preset, calls save-fire-goal.
//

import SwiftUI

struct BS_GoalSetupView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @FocusState private var spendingFieldFocused: Bool

    // Local formatted string for the text field
    @State private var spendingText: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    spendingInputCard
                        .padding(.horizontal, AppSpacing.lg)

                    lifestylePresetSection
                        .padding(.horizontal, AppSpacing.lg)

                    fireNumberPreview
                        .padding(.horizontal, AppSpacing.lg)

                    if let error = viewModel.goalSaveError {
                        Text(error)
                            .font(.footnoteRegular)
                            .foregroundStyle(AppColors.error)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
                if viewModel.retirementSpendingMonthly > 0 {
                    spendingText = formattedNoDecimal(viewModel.retirementSpendingMonthly)
                }
            }
            .onTapGesture { spendingFieldFocused = false }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Set Your FIRE Goal")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text("How much would you spend each month in retirement? We'll use this to calculate your FIRE number.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Spending Input

    private var spendingInputCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("MONTHLY RETIREMENT SPENDING")
                .font(.cardHeader)
                .tracking(1.2)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            HStack(spacing: AppSpacing.xs) {
                Text("$")
                    .font(.h2)
                    .foregroundStyle(AppColors.textPrimary)

                TextField("5,000", text: $spendingText)
                    .font(.h1)
                    .foregroundStyle(AppColors.textPrimary)
                    .keyboardType(.numberPad)
                    .focused($spendingFieldFocused)
                    .onChange(of: spendingText) { _, newValue in
                        // Strip non-digits, update viewModel
                        let digits = newValue.filter { $0.isNumber }
                        let numeric = Double(digits) ?? 0
                        viewModel.retirementSpendingMonthly = numeric
                        // Reformat only when not focused to avoid cursor jumping
                        // We keep raw digits while focused
                        spendingText = digits.isEmpty ? "" : digits
                    }
                    .onSubmit { spendingFieldFocused = false }
            }
            .padding(AppSpacing.md)
            .background(AppColors.overlayWhiteWash)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(spendingFieldFocused ? AppColors.textPrimary : AppColors.overlayWhiteStroke, lineWidth: spendingFieldFocused ? 2 : 1)
            )
            .onTapGesture { spendingFieldFocused = true }

            Text("Include rent/mortgage, food, transport, healthcare, and lifestyle costs.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textTertiary)
                .lineSpacing(2)
        }
    }

    // MARK: - Lifestyle Preset

    private var lifestylePresetSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("LIFESTYLE")
                .font(.cardHeader)
                .tracking(1.2)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            HStack(spacing: AppSpacing.sm) {
                presetButton(label: "Lean", value: "lean",
                             description: "Frugal, essentials only")
                presetButton(label: "Current", value: "current",
                             description: "Similar to today")
                presetButton(label: "Fat", value: "fat",
                             description: "Comfortable & flexible")
            }
        }
    }

    @ViewBuilder
    private func presetButton(label: String, value: String, description: String) -> some View {
        let isSelected = viewModel.lifestylePreset == value
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                viewModel.lifestylePreset = value
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                Text(label)
                    .font(.bodySemibold)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                Text(description)
                    .font(.footnoteRegular)
                    .foregroundStyle(isSelected ? AppColors.textSecondary : AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.sm)
            .background(isSelected ? AppColors.overlayWhiteMid : AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(isSelected ? AppColors.textPrimary : AppColors.borderLight, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - FIRE Number Preview

    @ViewBuilder
    private var fireNumberPreview: some View {
        let spending = viewModel.retirementSpendingMonthly
        if spending > 0 {
            let fireNumber = spending * 12 * 25  // 25× rule (4% withdrawal rate)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("YOUR FIRE NUMBER")
                    .font(.cardHeader)
                    .tracking(1.2)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text("≈ $\(formattedCompact(fireNumber))")
                        .font(.h2)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                    Text("to retire")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Text("Based on the 4% safe withdrawal rule: $\(formattedCompact(spending * 12))/yr × 25")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineSpacing(2)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.overlayWhiteWash)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
            )
            .transition(.opacity.combined(with: .offset(y: 4)))
        }
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColors.backgroundPrimary.opacity(0), AppColors.backgroundPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: AppRadius.button)

            Button {
                spendingFieldFocused = false
                Task {
                    let success = await viewModel.saveFireGoal()
                    if success {
                        await MainActor.run { viewModel.goToStep(.accountSelection) }
                    }
                }
            } label: {
                Group {
                    if viewModel.isSavingGoal {
                        ProgressView().tint(AppColors.textInverse)
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
                        .opacity(viewModel.retirementSpendingMonthly > 0 && !viewModel.isSavingGoal ? 1 : 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(viewModel.retirementSpendingMonthly <= 0 || viewModel.isSavingGoal)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Helpers

    private func formattedNoDecimal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formattedCompact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return "\(Int(value / 1_000))K" }
        return formattedNoDecimal(value)
    }
}

#Preview {
    BS_GoalSetupView(viewModel: BudgetSetupViewModel())
}
