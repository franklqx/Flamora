//
//  OBV2_SpendingView.swift
//  Flamora app
//
//  V2 Onboarding - Step 11: Monthly Spending (Snapshot 3/5)
//

import SwiftUI

struct OBV2_SpendingView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var spendingValue: Double = 0
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?

    private var income: Double {
        Double(data.monthlyIncome) ?? 0
    }

    private var savingsRate: Int {
        guard income > 0 else { return 0 }
        return Int(((income - spendingValue) / income) * 100)
    }

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

                OBV2_SnapshotProgress(current: 3)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 32)

                Text("How much do you\ntypically spend per\nmonth?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 48)

                // Slider
                OBV2_IncomeSlider(
                    value: $spendingValue,
                    range: 0...15000,
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
                if showInsight && spendingValue > 0 && income > 0 {
                    insightCard
                        .padding(.horizontal, AppSpacing.lg)
                }

                Spacer()

                // CTA
                OBV2_PrimaryButton(title: "Next") {
                    data.monthlyExpenses = "\(Int(spendingValue))"
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .onAppear {
            if let saved = Double(data.monthlyExpenses), saved > 0 {
                spendingValue = saved
                showInsight = true
            }
        }
    }

    // MARK: - Dynamic Insight Card

    @ViewBuilder
    private var insightCard: some View {
        let rate = savingsRate
        if rate > 20 {
            OBV2_MicroInsightCard(
                emoji: "🚀",
                text: "Your savings rate is \(rate)% — this is a solid foundation!",
                highlightText: "\(rate)%"
            )
        } else if rate >= 10 {
            OBV2_MicroInsightCard(
                emoji: "💪",
                text: "Your savings rate is \(rate)% — a good start, we can help you grow it.",
                highlightText: "\(rate)%"
            )
        } else if rate >= 1 {
            OBV2_MicroInsightCard(
                emoji: "🌱",
                text: "Your savings rate is \(rate)% — don't worry, we'll show you how to boost it.",
                highlightText: "\(rate)%"
            )
        } else {
            OBV2_MicroInsightCard(
                emoji: "💡",
                text: "Looks like your expenses match your income. Let's find some room to save."
            )
        }
    }

    // MARK: - Debounce

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
}
