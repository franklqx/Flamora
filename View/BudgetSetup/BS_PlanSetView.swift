//
//  BS_PlanSetView.swift
//  Flamora app
//
//  Budget Setup — Plan-set celebration step.
//  Shown after user picks a plan (.plan) and before optional category split (.split).
//  Forks: "Set category budgets" → .split   |   "Skip for now" → .confirm
//

import SwiftUI

struct BS_PlanSetView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private var monthlyBudgetValue: Double {
        viewModel.committedSpendCeiling
            ?? viewModel.spendingPlan?.totalSpend
            ?? viewModel.selectedPlan?.monthlyBudget
            ?? 0
    }

    private var monthlySaveValue: Double {
        viewModel.committedMonthlySave
            ?? viewModel.spendingPlan?.totalSavings
            ?? viewModel.selectedPlan?.monthlySave
            ?? 0
    }

    private func formatted(_ value: Double) -> String {
        let symbol = viewModel.currencySymbol
        let number = Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(symbol)\(number)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xxl)

                checkmarkBadge
                    .padding(.bottom, AppSpacing.sm)

                Text("Your plan is set")
                    .font(.h1)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)

                VStack(spacing: AppSpacing.xs) {
                    Text(formatted(monthlyBudgetValue))
                        .font(.currencyHero)
                        .foregroundStyle(AppColors.inkPrimary)

                    Text("MONTHLY BUDGET")
                        .font(.cardHeader)
                        .tracking(AppTypography.Tracking.cardHeader)
                        .foregroundStyle(AppColors.inkSoft)
                }

                Text("Save \(formatted(monthlySaveValue)) each month toward your FIRE goal.")
                    .font(.bodyRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }

            stickyBottomCTAs
        }
    }

    private var checkmarkBadge: some View {
        ZStack {
            Circle()
                .strokeBorder(AppColors.inkPrimary, lineWidth: 2)
                .frame(width: 72, height: 72)
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppColors.inkPrimary)
        }
    }

    private var stickyBottomCTAs: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color.clear, AppColors.shellBg2], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            VStack(spacing: AppSpacing.sm) {
                if viewModel.isManualMode {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.categoryBudgets = [:]
                        viewModel.didSkipCategoryBudgets = true
                        viewModel.goToStep(.confirm)
                    } label: {
                        Text("Continue")
                            .font(.sheetPrimaryButton)
                            .foregroundStyle(AppColors.ctaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.inkPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.didSkipCategoryBudgets = false
                        viewModel.goToStep(.split)
                    } label: {
                        Text("Set category budgets")
                            .font(.sheetPrimaryButton)
                            .foregroundStyle(AppColors.ctaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.inkPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.categoryBudgets = [:]
                        viewModel.didSkipCategoryBudgets = true
                        viewModel.goToStep(.confirm)
                    } label: {
                        Text("Skip for now")
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }
}
