//
//  OB_IncomeView.swift
//  Flamora app
//
//  Onboarding - Step 10: Monthly Income (Snapshot 2/5)
//

import SwiftUI
import UIKit

struct OB_IncomeView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var incomeValue: Double = 0
    @FocusState private var isAmountFocused: Bool
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?
    @State private var lastSliderHapticTime = Date.distantPast
    private let incomeRange: ClosedRange<Double> = 0...20_000

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: OB_OnboardingHeader.height)

                    Spacer().frame(height: AppSpacing.sm)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's your monthly income?")
                            .font(.obQuestion)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("A rough estimate is fine")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.inkSoft)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MONTHLY INCOME")
                            .font(.cardRowMeta)
                            .foregroundColor(AppColors.inkFaint)
                            .tracking(0.8)

                        incomeCard
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    if showInsight && incomeValue > 0 {
                        let percentile = incomePercentile(age: Int(data.age), income: incomeValue)
                        OB_MicroInsightCard(
                            systemImage: "chart.line.uptrend.xyaxis",
                            text: "Your income is higher than \(percentile)% of people in your age group.",
                            highlightText: "\(percentile)%"
                        )
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)

            // Sticky CTA（与 AgeView 一致）
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [AppColors.shellBg2.opacity(0), AppColors.shellBg2],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Next", action: {
                    data.monthlyIncome = "\(Int(incomeValue))"
                    onNext()
                })
            }
            .padding(.bottom, 16)
            .background(AppColors.shellBg2)
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: { isAmountFocused = false }) {
                    Image(systemName: "checkmark")
                }
            }
        }
        .onAppear {
            _ = Self._sliderSetup
            if let saved = Double(data.monthlyIncome), saved > 0 {
                incomeValue = saved
                showInsight = true
            }
        }
    }

    // MARK: - 收入玻璃卡片（与 AgeView 滑块样式一致）

    private var incomeCard: some View {
        VStack(spacing: 16) {
            OB_EditableAmountDisplay(
                value: $incomeValue,
                isFocused: $isAmountFocused,
                range: incomeRange,
                currencySymbol: data.currencySymbol,
                suffix: "/mo",
                accentGradient: accentGradient
            )

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        let progress = CGFloat(min(1.0, (incomeValue - incomeRange.lowerBound) / (incomeRange.upperBound - incomeRange.lowerBound)))
                        let thumbOffset: CGFloat = 14
                        let trackWidth = geo.size.width - thumbOffset * 2

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.inkBorder)
                                .frame(width: trackWidth, height: 4)
                            Capsule()
                                .fill(accentGradient)
                                .frame(width: trackWidth * progress, height: 4)
                        }
                        .offset(x: thumbOffset)
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 28)
                    .allowsHitTesting(false)

                    Slider(value: Binding(get: { min(incomeValue, incomeRange.upperBound) }, set: { incomeValue = $0 }), in: incomeRange, step: 100)
                        .frame(height: 28)
                        .onChange(of: incomeValue) { _, newVal in
                            let now = Date()
                            if now.timeIntervalSince(lastSliderHapticTime) >= 0.06 {
                                UISelectionFeedbackGenerator().selectionChanged()
                                lastSliderHapticTime = now
                            }
                            if newVal > 0 {
                                scheduleInsight()
                            } else {
                                showInsight = false
                            }
                        }
                }
                .frame(height: 28)

                HStack {
                    Text("\(data.currencySymbol)0")
                        .font(.caption)
                        .foregroundColor(AppColors.inkFaint)
                    Spacer()
                    Text("\(data.currencySymbol)20K+")
                        .font(.caption)
                        .foregroundColor(AppColors.inkFaint)
                }
                .frame(height: 18)
            }
            .frame(height: 62)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(minHeight: 200)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: AppColors.gradientShellAccent,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static let _sliderSetup: Void = {
        UISlider.appearance().thumbTintColor = AppColors.uiSliderThumbTint
        UISlider.appearance().minimumTrackTintColor = .clear
        UISlider.appearance().maximumTrackTintColor = .clear
    }()

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

#Preview {
    ZStack {
        LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        OB_IncomeView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
