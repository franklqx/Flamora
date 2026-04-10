//
//  OB_SpendingView.swift
//  Flamora app
//
//  Onboarding - Step 11: Monthly Spending (Snapshot 3/5)
//

import SwiftUI
import UIKit

struct OB_SpendingView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var spendingValue: Double = 0
    @FocusState private var isAmountFocused: Bool
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?
    @State private var lastSliderHapticTime = Date.distantPast
    private let spendingRange: ClosedRange<Double> = 0...20_000

    private var income: Double {
        Double(data.monthlyIncome) ?? 0
    }

    private var savingsRate: Int {
        guard income > 0 else { return 0 }
        return Int(((income - spendingValue) / income) * 100)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: OB_OnboardingHeader.height)

                    Spacer().frame(height: AppSpacing.sm)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("How much do you typically spend per month?")
                            .font(.obQuestion)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("Include rent, groceries, entertainment, etc.")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.inkSoft)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MONTHLY SPENDING")
                            .font(.cardRowMeta)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.8)

                        spendingCard
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    if showInsight && spendingValue > 0 && income > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SAVINGS RATE")
                                .font(.cardRowMeta)
                                .foregroundColor(AppColors.textTertiary)
                                .tracking(0.8)

                            savingsRateCard
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    data.monthlyExpenses = "\(Int(spendingValue))"
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
            if let saved = Double(data.monthlyExpenses), saved > 0 {
                spendingValue = saved
                showInsight = true
            }
        }
    }

    // MARK: - 支出玻璃卡片（与 AgeView 滑块样式一致）

    private var spendingCard: some View {
        VStack(spacing: 16) {
            OB_EditableAmountDisplay(
                value: $spendingValue,
                isFocused: $isAmountFocused,
                range: spendingRange,
                currencySymbol: data.currencySymbol,
                suffix: "/mo",
                accentGradient: accentGradient
            )

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        let progress = CGFloat(min(1.0, (spendingValue - spendingRange.lowerBound) / (spendingRange.upperBound - spendingRange.lowerBound)))
                        let thumbOffset: CGFloat = 14
                        let trackWidth = geo.size.width - thumbOffset * 2

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.glassPillStroke)
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

                    Slider(value: Binding(get: { min(spendingValue, spendingRange.upperBound) }, set: { spendingValue = $0 }), in: spendingRange, step: 100)
                        .frame(height: 28)
                        .onChange(of: spendingValue) { _, newVal in
                            let now = Date()
                            if now.timeIntervalSince(lastSliderHapticTime) >= 0.06 {
                                UISelectionFeedbackGenerator().selectionChanged()
                                lastSliderHapticTime = now
                            }
                            if newVal > 0 && income > 0 {
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
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(data.currencySymbol)20K+")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
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
            colors: [AppColors.gradientStart, AppColors.gradientMiddle, AppColors.gradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static let _sliderSetup: Void = {
        UISlider.appearance().thumbTintColor = AppColors.uiSliderThumbTint
        UISlider.appearance().minimumTrackTintColor = .clear
        UISlider.appearance().maximumTrackTintColor = .clear
    }()

    // MARK: - Savings Rate Card

    private var savingsRateCard: some View {
        let rate = max(0, savingsRate)
        let monthlySavings = max(0, income - spendingValue)

        return VStack(spacing: AppSpacing.md) {
            // 大数字：saving rate
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Spacer()
                Text("\(rate)")
                    .font(.currencyHero.monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: rate)
                Text("%")
                    .font(.cardFigurePrimary)
                    .foregroundStyle(AppColors.inkPrimary)
                Spacer()
            }

            // 分割线
            Rectangle()
                .fill(AppColors.inkBorder)
                .frame(height: 1)

            // Income − Spending = Saved 分解
            HStack(spacing: 0) {
                VStack(spacing: AppSpacing.xs) {
                    Text("Income")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(data.currencySymbol)\(formattedAmount(income))")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                Spacer()
                Text("−")
                    .font(.h4)
                    .fontWeight(.light)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                VStack(spacing: AppSpacing.xs) {
                    Text("Spending")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(data.currencySymbol)\(formattedAmount(spendingValue))")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.inkPrimary)
                }
                Spacer()
                Text("=")
                    .font(.h4)
                    .fontWeight(.light)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                VStack(spacing: 4) {
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(data.currencySymbol)\(formattedAmount(monthlySavings))")
                        .font(.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentGradient)
                }
            }

            // 鼓励语
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(accentGradient)
                Text(savingsMicrocopy(rate: rate))
                    .font(.caption)
                    .foregroundColor(AppColors.inkSoft)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.vertical, AppSpacing.cardPadding)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    private func savingsMicrocopy(rate: Int) -> String {
        switch rate {
        case 25...: return "Outstanding! You're building wealth fast."
        case 15..<25: return "Solid rate — let's push it even further."
        case 5..<15: return "Good start. Small tweaks go a long way."
        case 1..<5: return "Don't worry — we'll help you save more."
        default: return "Spending matches income. Let's find room."
        }
    }

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
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
        OB_SpendingView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
