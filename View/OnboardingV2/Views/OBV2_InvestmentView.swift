//
//  OBV2_InvestmentView.swift
//  Flamora app
//
//  V2 Onboarding - Step 12: Investment Portfolio (Snapshot 4/5)
//

import SwiftUI

struct OBV2_InvestmentView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var investmentValue: Double = 0
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?

    private var monthlyPassiveIncome: Int {
        Int((investmentValue * 0.04) / 12)
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

                OBV2_SnapshotProgress(current: 4)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 32)

                Text("What's your total\ninvestment portfolio\nvalue?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 8)

                Text("Including stocks, bonds, retirement (401k, IRA), crypto, etc.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 48)

                // Slider
                OBV2_IncomeSlider(
                    value: $investmentValue,
                    range: 0...2_000_000,
                    step: 1000,
                    currencySymbol: data.currencySymbol,
                    suffix: "",
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
                if showInsight {
                    insightCard
                        .padding(.horizontal, AppSpacing.lg)
                }

                Spacer()

                // CTA
                OBV2_PrimaryButton(title: "Next") {
                    data.currentNetWorth = "\(Int(investmentValue))"
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .onAppear {
            if let saved = Double(data.currentNetWorth), saved > 0 {
                investmentValue = saved
                showInsight = true
            }
        }
    }

    // MARK: - Dynamic Insight

    @ViewBuilder
    private var insightCard: some View {
        let passiveStr = formatCurrency(Double(monthlyPassiveIncome))
        if investmentValue == 0 {
            OBV2_MicroInsightCard(
                emoji: "🌱",
                text: "Everyone starts at zero. Let's build your plan."
            )
        } else if investmentValue <= 50000 {
            OBV2_MicroInsightCard(
                emoji: "📈",
                text: "Your investments currently generate ~\(passiveStr)/mo in sustainable passive income (based on the 4% rule) — let's grow it.",
                highlightText: "~\(passiveStr)/mo"
            )
        } else {
            OBV2_MicroInsightCard(
                emoji: "🔥",
                text: "Your investments currently generate ~\(passiveStr)/mo in sustainable passive income (based on the 4% rule) — you're on your way!",
                highlightText: "~\(passiveStr)/mo"
            )
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(data.currencySymbol)\(formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")"
    }

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
