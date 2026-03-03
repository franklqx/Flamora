//
//  OBV2_IncomeView.swift
//  Flamora app
//
//  V2 Onboarding - Step 10: Monthly Income (Snapshot 2/5)
//

import SwiftUI

struct OBV2_IncomeView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var incomeValue: Double = 0
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    OBV2_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                OBV2_SnapshotProgress(current: 2)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 32)

                // Title
                Text("What's your monthly\nincome?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 8)

                Text("A rough estimate is fine")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 48)

                // Slider
                OBV2_IncomeSlider(
                    value: $incomeValue,
                    range: 0...20000,
                    step: 100,
                    currencySymbol: data.currencySymbol,
                    suffix: "/mo",
                    onEditingChanged: { editing in
                        if editing {
                            showInsight = false
                            insightWorkItem?.cancel()
                        } else {
                            scheduleInsight()
                        }
                    }
                )
                .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 32)

                // Micro insight
                if showInsight && incomeValue > 0 {
                    let percentile = incomePercentile(age: Int(data.age), income: incomeValue)
                    OBV2_MicroInsightCard(
                        emoji: "💪",
                        text: "Your income is higher than \(percentile)% of people in your age group.",
                        highlightText: "\(percentile)%"
                    )
                    .padding(.horizontal, AppSpacing.lg)
                }

                Spacer()

                // CTA
                OBV2_PrimaryButton(title: "Next") {
                    data.monthlyIncome = "\(Int(incomeValue))"
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .onAppear {
            if let saved = Double(data.monthlyIncome), saved > 0 {
                incomeValue = saved
                showInsight = true
            }
        }
    }

    // MARK: - Helpers

    private func scheduleInsight() {
        insightWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) {
                showInsight = true
            }
        }
        insightWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func incomePercentile(age: Int, income: Double) -> Int {
        let median: Double
        if age < 25 { median = 2500 }
        else if age < 30 { median = 3500 }
        else if age < 35 { median = 4500 }
        else if age < 40 { median = 5500 }
        else { median = 5000 }
        let ratio = income / median
        return min(99, max(1, Int(50 + (ratio - 1) * 30)))
    }
}
