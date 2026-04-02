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
    private let tealColor   = AppColors.accentGreen   // #34D399 — exact match
    private let goldColor   = Color(hex: "FBBF24")

    @State private var showContent = false
    @State private var ringProgress: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundSecondary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if let plan = viewModel.spendingPlan, let selected = viewModel.selectedPlan {
                        budgetSummaryRing(plan: plan, selectedPlan: selected)
                            .padding(.horizontal, AppSpacing.lg)

                        planDetailsCard(plan: plan, selectedPlan: selected)
                            .padding(.horizontal, AppSpacing.lg)

                        tipCard
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { showContent = true }
                withAnimation(.easeOut(duration: 1.2).delay(0.3)) { ringProgress = 1.0 }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button { viewModel.goBack() } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.sm)

            Text("Your Plan")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Budget Summary Ring

    private func budgetSummaryRing(plan: SpendingPlanResponse, selectedPlan: PlanDetail) -> some View {
        // `fixedBudget` / `flexibleBudget` 为 API 字段名；UI 展示为 Needs / Wants。
        let budgetTotal = plan.fixedBudget.total + plan.flexibleBudget.total
        let needsShare = budgetTotal > 0 ? plan.fixedBudget.total / budgetTotal : 0.5

        return VStack(spacing: AppSpacing.lg) {
            ZStack {
                // Background track
                Circle()
                    .stroke(AppColors.overlayWhiteWash, lineWidth: 20)
                    .frame(width: 200, height: 200)

                // Needs arc (purple) with round caps
                Circle()
                    .trim(from: 0, to: needsShare * ringProgress)
                    .stroke(purpleColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Wants arc (teal) with round caps
                Circle()
                    .trim(from: needsShare * ringProgress, to: ringProgress)
                    .stroke(tealColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: AppSpacing.xs) {
                    Text("MONTHLY BUDGET")
                        .font(.cardHeader)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    Text("$\(formattedInt(selectedPlan.monthlySpend))")
                        .font(.h1)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                }
            }

            // Legend — side by side
            HStack(spacing: AppSpacing.xl) {
                legendItem(color: purpleColor, label: "Needs", amount: plan.fixedBudget.total)
                legendItem(color: tealColor, label: "Wants", amount: plan.flexibleBudget.total)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String, amount: Double) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Circle().fill(color).frame(width: AppSpacing.sm, height: AppSpacing.sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textSecondary)
                Text("$\(formattedInt(amount))")
                    .font(.statRowSemibold)
                    .foregroundStyle(AppColors.textPrimary)
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
                        .fill(AppColors.overlayWhiteWash)
                        .frame(height: 1)
                }
                HStack {
                    Text(row.label)
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    Spacer()
                    Text(row.value)
                        .font(.bodySmallSemibold)
                        .foregroundStyle(row.isRate ? goldColor : AppColors.textPrimary)
                        .monospacedDigit()
                }
                .padding(.vertical, AppSpacing.sm + AppSpacing.xs)
                .padding(.horizontal, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm + AppSpacing.xs) {
            Text("\u{1F4A1}")
                .font(.bodyRegular)
            Text("You can adjust your budget anytime in Settings.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                .lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [AppColors.backgroundSecondary.opacity(0), AppColors.backgroundSecondary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            VStack(spacing: 0) {
                Button {
                    print("📍 [Flow] Start My Journey tapped")
                    Task {
                        let success = await viewModel.saveFinalBudget()
                        if success {
                            UserDefaults.standard.set(true, forKey: FlamoraStorageKey.budgetSetupCompleted)
                            print("📍 [Flow] saveFinalBudget done, will dismiss")
                            onComplete()
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if viewModel.isSaving {
                            ProgressView().tint(AppColors.textPrimary)
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Start My Journey")
                            .font(.figureSecondarySemibold)
                    }
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .shadow(color: gradientColors[1].opacity(0.25), radius: AppSpacing.md, y: AppSpacing.sm)
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
            .background(AppColors.backgroundSecondary)
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
