//
//  OB_InvestmentView.swift
//  Flamora app
//
//  Onboarding - Step 12: Investment Portfolio (Snapshot 4/5)
//

import SwiftUI
import UIKit

struct OB_InvestmentView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var investmentValue: Double = 0
    @FocusState private var isAmountFocused: Bool
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?
    @State private var lastSliderHapticTime = Date.distantPast
    // Slider caps at $1M — covers ~99% of users at this onboarding stage.
    // Users with larger portfolios tap the amount above to type any value;
    // the slider visually pins to max via `min(value, upperBound)` in the
    // binding getter, so the typed amount isn't clamped — only the slider
    // thumb is. Pinning still lets them refine downward with the slider.
    private let investmentRange: ClosedRange<Double> = 0...1_000_000

    private var monthlyPassiveIncome: Int {
        Int((investmentValue * 0.04) / 12)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: OB_OnboardingHeader.height)

                    Spacer().frame(height: AppSpacing.sm)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's your total investment portfolio value?")
                            .font(.obQuestion)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("Including stocks, bonds, retirement (401k, IRA), crypto, etc.")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.inkSoft)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("INVESTMENT PORTFOLIO")
                            .font(.cardRowMeta)
                            .foregroundColor(AppColors.inkFaint)
                            .tracking(0.8)

                        investmentCard
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    if showInsight {
                        insightCard
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
                    data.currentNetWorth = "\(Int(investmentValue))"
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
            if let saved = Double(data.currentNetWorth), saved > 0 {
                investmentValue = saved
                showInsight = true
            }
        }
    }

    // MARK: - 投资玻璃卡片（与 AgeView 滑块样式一致）

    private var investmentCard: some View {
        VStack(spacing: 16) {
            OB_EditableAmountDisplay(
                value: $investmentValue,
                isFocused: $isAmountFocused,
                range: investmentRange,
                currencySymbol: data.currencySymbol,
                suffix: "",
                accentGradient: accentGradient
            )

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        let progress = CGFloat(min(1.0, (investmentValue - investmentRange.lowerBound) / (investmentRange.upperBound - investmentRange.lowerBound)))
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

                    Slider(value: Binding(get: { min(investmentValue, investmentRange.upperBound) }, set: { investmentValue = $0 }), in: investmentRange, step: 1000)
                        .frame(height: 28)
                        .onChange(of: investmentValue) { _, _ in
                            let now = Date()
                            if now.timeIntervalSince(lastSliderHapticTime) >= 0.06 {
                                UISelectionFeedbackGenerator().selectionChanged()
                                lastSliderHapticTime = now
                            }
                            scheduleInsight()
                        }
                }
                .frame(height: 28)

                HStack {
                    Text("\(data.currencySymbol)0")
                        .font(.caption)
                        .foregroundColor(AppColors.inkFaint)
                    Spacer()
                    Text("\(data.currencySymbol)1M+")
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

    // MARK: - Dynamic Insight Card

    @ViewBuilder
    private var insightCard: some View {
        let passiveStr = formatCurrency(Double(monthlyPassiveIncome))
        if investmentValue == 0 {
            OB_MicroInsightCard(
                systemImage: "chart.line.uptrend.xyaxis",
                text: "Everyone starts at zero. Let's build your plan."
            )
        } else if investmentValue <= 50000 {
            OB_MicroInsightCard(
                systemImage: "chart.line.uptrend.xyaxis",
                text: "Your investments currently generate ~\(passiveStr)/mo in sustainable passive income (based on the 4% rule) — let's grow it.",
                highlightText: "~\(passiveStr)/mo"
            )
        } else {
            OB_MicroInsightCard(
                systemImage: "chart.line.uptrend.xyaxis",
                text: "Your investments currently generate ~\(passiveStr)/mo in sustainable passive income (based on the 4% rule) — you're on your way!",
                highlightText: "~\(passiveStr)/mo"
            )
        }
    }

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

#Preview {
    ZStack {
        LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        OB_InvestmentView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
