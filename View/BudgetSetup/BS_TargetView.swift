//
//  BS_TargetView.swift
//  Flamora app
//
//  Budget Setup — Step 4: Set Your Target
//

import SwiftUI

struct BS_TargetView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showSpendingSheet = false
    @State private var draftSpending: Double = 0

    private var minTargetAge: Int { max(viewModel.currentAge + 1, 1) }
    private var maxTargetAge: Int { 80 }
    private var todaySpend: Double { max(0, viewModel.currentSnapshotSpend) }
    private var currentFireNumber: Double { todaySpend * 12 / 0.04 }
    private var desiredFireNumber: Double { max(0, viewModel.retirementSpendingMonthly) * 12 / 0.04 }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    ageCard
                        .padding(.horizontal, AppSpacing.lg)

                    spendingCard
                        .padding(.horizontal, AppSpacing.lg)

                    fireNumberCard
                        .padding(.horizontal, AppSpacing.lg)

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }

            stickyBottomCTA
        }
        .onAppear {
            viewModel.seedDefaultsForTargetStep()
            draftSpending = max(viewModel.retirementSpendingMonthly, todaySpend)
        }
        .sheet(isPresented: $showSpendingSheet) {
            spendingSheet
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Set Your Target")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            Text("Choose the age you want to retire, then set the monthly spending level you want your future plan to support.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    private var ageCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("TARGET AGE")
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)

            HStack(alignment: .firstTextBaseline) {
                Text("\(viewModel.targetRetirementAge)")
                    .font(.display)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
                Spacer()
                Text("Current age \(viewModel.currentAge)")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.targetRetirementAge) },
                    set: { viewModel.targetRetirementAge = Int($0.rounded()) }
                ),
                in: Double(minTargetAge)...Double(maxTargetAge),
                step: 1
            )
            .tint(AppColors.accentAmber)

            HStack {
                Text("\(minTargetAge)")
                Spacer()
                Text("\(maxTargetAge)")
            }
            .font(.caption)
            .foregroundStyle(AppColors.inkFaint)
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var spendingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("DESIRED MONTHLY SPENDING")
                        .font(.label)
                        .tracking(1)
                        .foregroundStyle(AppColors.inkFaint)
                    Text("$\(formatted(viewModel.retirementSpendingMonthly))/mo")
                        .font(.h2)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()
                }
                Spacer()
                Button("Change") {
                    draftSpending = max(viewModel.retirementSpendingMonthly, todaySpend)
                    showSpendingSheet = true
                }
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.accentAmber)
            }

            HStack(spacing: AppSpacing.sm) {
                quickChip("Match today", value: todaySpend)
                quickChip("-$500", value: max(0, todaySpend - 500))
                quickChip("+$500", value: todaySpend + 500)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var fireNumberCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("FIRE NUMBER")
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)

            HStack {
                comparisonColumn(title: "TODAY", value: currentFireNumber)
                Rectangle()
                    .fill(AppColors.inkBorder)
                    .frame(width: 1, height: 48)
                comparisonColumn(title: "TARGET", value: desiredFireNumber)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private func quickChip(_ label: String, value: Double) -> some View {
        Button {
            viewModel.retirementSpendingMonthly = roundChipValue(value)
        } label: {
            Text(label)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkPrimary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.glassCardBg)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.inkBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func comparisonColumn(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.label)
                .tracking(0.8)
                .foregroundStyle(AppColors.inkFaint)
            Text("$\(formatted(value))")
                .font(.bodySemibold)
                .foregroundStyle(AppColors.inkPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            VStack(spacing: AppSpacing.xs) {
                Button {
                    Task {
                        let saved = await viewModel.saveFireGoal()
                        if saved {
                            await MainActor.run { viewModel.goToStep(.plan) }
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if viewModel.isSavingGoal {
                            ProgressView().tint(AppColors.ctaWhite)
                        }
                        Text(viewModel.isSavingGoal ? "Saving..." : "Continue")
                            .font(.sheetPrimaryButton)
                    }
                    .foregroundStyle(AppColors.ctaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        canContinue ? AppColors.inkPrimary : AppColors.inkFaint
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .disabled(!canContinue || viewModel.isSavingGoal)

                if let error = viewModel.goalSaveError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    private var canContinue: Bool {
        viewModel.retirementSpendingMonthly > 0 && viewModel.targetRetirementAge >= minTargetAge
    }

    private var spendingSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Desired Monthly Spending")
                        .font(.h3)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("This number becomes the spending level your plan is trying to support after you retire.")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.inkSoft)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("$\(formatted(draftSpending))/mo")
                        .font(.display)
                        .foregroundStyle(AppColors.inkPrimary)
                        .monospacedDigit()

                    Slider(value: $draftSpending, in: 500...max(20000, todaySpend + 5000), step: 50)
                        .tint(AppColors.accentAmber)
                }

                HStack(spacing: AppSpacing.sm) {
                    quickSheetChip("Match today", value: todaySpend)
                    quickSheetChip("-$500", value: max(0, todaySpend - 500))
                    quickSheetChip("+$500", value: todaySpend + 500)
                }

                fireNumberCardInSheet

                Spacer()
            }
            .padding(AppSpacing.lg)
            .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showSpendingSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        viewModel.retirementSpendingMonthly = roundChipValue(draftSpending)
                        showSpendingSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var fireNumberCardInSheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Before / After")
                .font(.label)
                .tracking(1)
                .foregroundStyle(AppColors.inkFaint)
            HStack {
                comparisonColumn(title: "CURRENT", value: currentFireNumber)
                Rectangle()
                    .fill(AppColors.inkBorder)
                    .frame(width: 1, height: 48)
                comparisonColumn(title: "NEW", value: draftSpending * 12 / 0.04)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private func quickSheetChip(_ label: String, value: Double) -> some View {
        Button(label) {
            draftSpending = roundChipValue(value)
        }
        .font(.footnoteRegular)
        .foregroundStyle(AppColors.inkPrimary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.glassCardBg)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private func roundChipValue(_ value: Double) -> Double {
        (value / 50).rounded() * 50
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }
}
