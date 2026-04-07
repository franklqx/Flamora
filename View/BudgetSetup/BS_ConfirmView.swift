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

    private let goldColor   = AppColors.budgetGold

    @State private var showContent = false
    @State private var ringProgress: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if let plan = viewModel.spendingPlan {
                        budgetSummaryRing(plan: plan)
                            .padding(.horizontal, AppSpacing.lg)

                        planDetailsCard(plan: plan)
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
            Text("Review Plan")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Budget Summary Ring

    private func budgetSummaryRing(plan: SpendingPlanResponse) -> some View {
        let ringWidth: CGFloat = 220
        let ringHeight: CGFloat = 176
        let lineWidth: CGFloat = 20

        return VStack(spacing: 0) {
            ZStack {
                ConfirmTopSemiRing(startProgress: 0, endProgress: 1)
                    .stroke(
                        AppColors.overlayWhiteWash,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                ConfirmTopSemiRing(startProgress: 0, endProgress: CGFloat(ringProgress))
                    .stroke(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                VStack(spacing: AppSpacing.xs) {
                    Text("$\(formattedInt(plan.totalSpend))")
                        .font(.h1)
                        .foregroundStyle(AppColors.textPrimary)
                        .monospacedDigit()

                    Text("Monthly spend budget")
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 92)
            }
            .frame(width: ringWidth, height: ringHeight)
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
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

    // MARK: - Plan Details Card

    private func planDetailsCard(plan: SpendingPlanResponse) -> some View {
        let income = max(plan.totalIncome, viewModel.spendingStats?.avgMonthlyIncome ?? viewModel.monthlyIncome)
        let rows: [(label: String, value: String, isRate: Bool)] = [
            ("Plan", viewModel.selectedPlanName, false),
            ("Monthly income", "$\(formattedInt(income))", false),
            ("Monthly budget", "$\(formattedInt(plan.totalSpend))", false),
            ("Monthly savings", "$\(formattedInt(plan.totalSavings))", false),
            ("Savings rate", formattedPct(plan.planRate), true)
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
            LinearGradient(colors: [AppColors.backgroundPrimary.opacity(0), AppColors.backgroundPrimary], startPoint: .top, endPoint: .bottom)
                .frame(height: AppRadius.button)

            VStack(spacing: 0) {
                Button {
                    Task {
                        let success = await viewModel.finalizeSetup()
                        if success {
                            UserDefaults.standard.set(true, forKey: FlamoraStorageKey.budgetSetupCompleted)
                            onComplete()
                        }
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if viewModel.isSaving {
                            ProgressView().tint(AppColors.textPrimary)
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Start My Journey")
                            .font(.sheetPrimaryButton)
                    }
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: AppColors.gradientFire, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    .shadow(color: AppColors.gradientMiddle.opacity(0.25), radius: AppSpacing.md, y: AppSpacing.sm)
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
            .background(AppColors.backgroundPrimary)
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
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return "\(Int(rounded))%" }
        return String(format: "%.1f%%", rounded)
    }

    private func formattedCompact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return "\(Int(value / 1_000))K" }
        return formattedInt(value)
    }
}

private struct ConfirmTopSemiRing: Shape {
    let startProgress: CGFloat
    let endProgress: CGFloat

    func path(in rect: CGRect) -> Path {
        let clampedStart = min(max(startProgress, 0), 1)
        let clampedEnd = min(max(endProgress, 0), 1)
        guard clampedEnd > clampedStart else { return Path() }

        let radius = min(rect.width / 2, rect.height) - 10
        let center = CGPoint(x: rect.midX, y: rect.maxY - 10)
        let startAngle = Double.pi * Double(1 - clampedStart)
        let endAngle = Double.pi * Double(1 - clampedEnd)
        let steps = max(Int(ceil((clampedEnd - clampedStart) * 48)), 2)
        var path = Path()

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = startAngle + (endAngle - startAngle) * progress
            let cosValue = CGFloat(Foundation.cos(angle))
            let sinValue = CGFloat(Foundation.sin(angle))
            let point = CGPoint(
                x: center.x + radius * cosValue,
                y: center.y - radius * sinValue
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

#Preview {
    BS_ConfirmView(viewModel: BudgetSetupViewModel(), onComplete: {})
}
