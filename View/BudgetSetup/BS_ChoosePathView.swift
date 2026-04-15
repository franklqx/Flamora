//
//  BS_ChoosePathView.swift
//  Flamora app
//
//  Budget Setup — Step 5: Choose Your Plan
//  V3: Three plan cards (Steady / Recommended / Accelerate) with inline FIRE expand.
//  Expand shows: savings target / FIRE date / FIRE age / spending ceiling / tradeoff note.
//

import SwiftUI

struct BS_ChoosePathView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false

    private let goldColor = AppColors.budgetGold

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if viewModel.isLoadingPlans {
                        loadingSection
                    } else if let plans = viewModel.plansResponse {
                        phaseBanner(for: plans)
                            .padding(.horizontal, AppSpacing.lg)

                        planCard(plan: plans.plans.steady, name: "Steady", type: .steady,
                                 difficulty: 1, difficultyLabel: "Easy", difficultyColor: AppColors.budgetTeal)
                            .padding(.horizontal, AppSpacing.lg)

                        planCard(plan: plans.plans.recommended, name: "Recommended", type: .recommended,
                                 difficulty: 2, difficultyLabel: "Moderate", difficultyColor: goldColor,
                                 showBestFit: true)
                            .padding(.horizontal, AppSpacing.lg)

                        planCard(plan: plans.plans.accelerate, name: "Accelerate", type: .accelerate,
                                 difficulty: 3, difficultyLabel: "Ambitious", difficultyColor: AppColors.budgetOrange)
                            .padding(.horizontal, AppSpacing.lg)

                        assumptionsNote
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
                if viewModel.plansResponse == nil {
                    Task { await viewModel.loadPlans() }
                }
            }

            stickyBottomCTA
        }
        .alert("Couldn't continue", isPresented: Binding(
            get: { viewModel.spendingPlanError != nil },
            set: { if !$0 { viewModel.spendingPlanError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.spendingPlanError = nil }
        } message: {
            Text(viewModel.spendingPlanError ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Choose Your Plan")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)

            Text("Three paths to your retirement goal. Tap to compare savings rate, spending ceiling, and FIRE age.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Phase Banner

    @ViewBuilder
    private func phaseBanner(for response: PlansResponse) -> some View {
        if response.goalDriven == true, let phase = response.phase {
            switch phase {
            case 0:
                bannerRow(
                    icon: "checkmark.seal.fill",
                    tint: AppColors.budgetTeal,
                    title: "You're on track",
                    subtitle: "Your current pace already hits your goal. These plans show how much faster you could retire."
                )
            case 2:
                bannerRow(
                    icon: "exclamationmark.triangle.fill",
                    tint: AppColors.budgetOrange,
                    title: "Goal may need adjustment",
                    subtitle: "The target age + spending combo isn't realistic on today's income. Accelerate shows the best-effort path."
                )
            default:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.bodySemibold)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(tint.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.overlayWhiteOnPhoto)
            Text("Generating your plans...")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)
    }

    // MARK: - Plan Card

    @ViewBuilder
    private func planCard(plan: PlanDetail, name: String, type: BudgetSetupViewModel.PlanSelection,
                          difficulty: Int, difficultyLabel: String, difficultyColor: Color,
                          showBestFit: Bool = false) -> some View {
        let isSelected = viewModel.selectedPlanType == type

        Button {
            withAnimation(.easeOut(duration: 0.3)) {
                viewModel.selectedPlanType = type
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.cardGap) {
                // Header row: name + difficulty + radio
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm) {
                            Text(name)
                                .font(.h3)
                                .foregroundStyle(AppColors.textPrimary)

                            if showBestFit {
                                Text("BEST FIT")
                                    .font(.miniLabel)
                                    .foregroundStyle(AppColors.textInverse)
                                    .padding(.horizontal, AppSpacing.sm - 2)
                                    .padding(.vertical, 2)
                                    .background(goldColor)
                                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                            }

                            if plan.warning == true {
                                HStack(spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.miniLabel)
                                    Text("REVIEW GOAL")
                                        .font(.miniLabel)
                                }
                                .foregroundStyle(AppColors.textInverse)
                                .padding(.horizontal, AppSpacing.sm - 2)
                                .padding(.vertical, 2)
                                .background(AppColors.budgetOrange)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                            }
                        }

                        // Difficulty dots
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(i < difficulty ? AppColors.textPrimary : AppColors.overlayWhiteForegroundSoft)
                                    .frame(width: AppSpacing.sm - 1, height: AppSpacing.sm - 1)
                            }
                            Text(difficultyLabel)
                                .font(.cardRowMeta)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.leading, AppSpacing.xs / 2)
                        }
                    }

                    Spacer()

                    // Radio button
                    ZStack {
                        Circle()
                            .stroke(isSelected ? AppColors.textPrimary : AppColors.overlayWhiteStroke, lineWidth: 2)
                            .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                        if isSelected {
                            Circle()
                                .fill(AppColors.textPrimary)
                                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                            Image(systemName: "checkmark")
                                .font(.cardRowMeta)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.textInverse)
                        }
                    }
                }

                // Hero: Monthly spend
                VStack(spacing: AppSpacing.xs) {
                    Text("MONTHLY BUDGET")
                        .font(.cardHeader)
                        .tracking(1.5)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                    Text("$\(formattedInt(plan.monthlySpend))")
                        .font(.display)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()
                        .accessibilityLabel("Monthly budget \(formattedInt(plan.monthlySpend)) dollars")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)

                // Secondary stats row
                HStack(spacing: 0) {
                    statColumnSmall(label: "SAVE/MO", value: "$\(formattedInt(plan.monthlySave))")
                    Rectangle().fill(AppColors.overlayWhiteStroke).frame(width: 1, height: AppSpacing.lg)
                    statColumnSmall(label: "RATE", value: formattedPct(plan.savingsRate))
                    Rectangle().fill(AppColors.overlayWhiteStroke).frame(width: 1, height: AppSpacing.lg)
                    statColumnSmall(label: "RETIRE AT", value: plan.officialFireAge.map { "Age \($0)" } ?? "—")
                }
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.backgroundPrimary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                // Inline FIRE expand (only when selected)
                if isSelected {
                    fireDetailExpand(plan: plan)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                }
            }
            .padding(AppSpacing.md)
            .background(isSelected ? AppColors.overlayWhiteMid : AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.textPrimary, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(color: isSelected ? AppColors.overlayWhiteWash : .clear, radius: AppSpacing.sm + AppSpacing.xs, y: AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - FIRE Detail Expand

    @ViewBuilder
    private func fireDetailExpand(plan: PlanDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // FIRE date (age已在折叠态展示，展开态只补充具体日期)
            if let fireDate = plan.officialFireDate {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FIRE DATE")
                            .font(.label)
                            .tracking(0.8)
                            .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                        Text(formattedFireDate(fireDate))
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    Spacer()
                }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundPrimary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }

            // Spending ceiling
            if let ceiling = plan.spendingCeilingMonthly {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SPENDING CEILING")
                            .font(.label)
                            .tracking(0.8)
                            .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                        Text("$\(formattedInt(ceiling))/mo")
                            .font(.bodySemibold)
                            .foregroundStyle(AppColors.textPrimary)
                            .monospacedDigit()
                    }
                    Spacer()
                }
                .padding(AppSpacing.sm)
                .background(AppColors.backgroundPrimary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }

            // Tradeoff note
            if let note = plan.tradeoffNote, !note.isEmpty {
                HStack(alignment: .top, spacing: AppSpacing.sm - 2) {
                    Image(systemName: "info.circle")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.top, 1)
                    Text(note)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                        .lineSpacing(3)
                }
            }

            // Positioning copy (fallback if no tradeoff note)
            if plan.tradeoffNote == nil || plan.tradeoffNote?.isEmpty == true,
               let copy = plan.positioningCopy, !copy.isEmpty {
                Text(copy)
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.overlayWhiteOnPhoto)
                    .lineSpacing(3)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColors.overlayWhiteWash, AppColors.overlayWhiteWash.opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    // MARK: - Assumptions Note

    private var assumptionsNote: some View {
        Text("FIRE estimates use the 4% withdrawal rule with 4% real annual returns (inflation-adjusted). Projections, not guarantees.")
            .font(.cardRowMeta)
            .foregroundStyle(AppColors.textTertiary)
            .lineSpacing(3)
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [AppColors.backgroundPrimary.opacity(0), AppColors.backgroundPrimary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            Button {
                Task {
                    await viewModel.loadSpendingPlan()
                    guard viewModel.spendingPlan != nil else { return }
                    await MainActor.run { viewModel.goToStep(.confirm) }
                }
            } label: {
                Group {
                    if viewModel.isLoadingSpendingPlan {
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
                        .opacity(viewModel.selectedPlan != nil && !viewModel.isLoadingPlans && !viewModel.isLoadingSpendingPlan ? 1 : 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(viewModel.selectedPlan == nil || viewModel.isLoadingPlans || viewModel.isLoadingSpendingPlan)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func statColumnSmall(label: String, value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(label)
                .font(.label)
                .tracking(0.8)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            Text(value)
                .font(.bodySemibold)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func expandStat(label: String, value: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(label)
                .font(.label)
                .tracking(0.8)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            Text(value)
                .font(.bodySemibold)
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatters

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

    /// Converts "2031-04" → "Apr 2031"
    private func formattedFireDate(_ isoMonth: String) -> String {
        let parts = isoMonth.split(separator: "-")
        guard parts.count >= 2, let year = parts.first.map(String.init),
              let monthNum = Int(parts[1]) else { return isoMonth }
        let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        guard monthNum >= 1, monthNum <= 12 else { return isoMonth }
        return "\(months[monthNum - 1]) \(year)"
    }
}

#Preview {
    BS_ChoosePathView(viewModel: BudgetSetupViewModel())
}
