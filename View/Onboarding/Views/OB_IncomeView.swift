//
//  OB_IncomeView.swift
//  Flamora app
//
//  Onboarding - Step 10: Monthly Income (Snapshot 2/5)
//

import SwiftUI

struct OB_IncomeView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var incomeValue: Double = 0
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?
    private let incomeRange: ClosedRange<Double> = 0...20000

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    OB_SnapshotProgress(current: 2, total: 5)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, AppSpacing.md)

                    Spacer().frame(height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's your monthly income?")
                            .font(.obQuestion)
                            .foregroundColor(.white)
                        Text("A rough estimate is fine")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MONTHLY INCOME")
                            .font(.obStepLabel)
                            .foregroundColor(AppColors.textTertiary)
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

            // Sticky CTA（与 AgeView 一致）
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Next", action: {
                    data.monthlyIncome = "\(Int(incomeValue))"
                    onNext()
                })
                .background(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Spacer()
                Text(data.currencySymbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text(formattedIncome)
                    .font(.system(size: 48, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                Text("/mo")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }
            .frame(height: 80)

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        let progress = CGFloat((incomeValue - incomeRange.lowerBound) / (incomeRange.upperBound - incomeRange.lowerBound))
                        let thumbOffset: CGFloat = 14
                        let trackWidth = geo.size.width - thumbOffset * 2

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
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

                    Slider(value: $incomeValue, in: incomeRange, step: 100)
                        .frame(height: 28)
                        .onChange(of: incomeValue) { _, newVal in
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
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                    Text("\(data.currencySymbol)20K")
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
        .background(AppColors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.accentBlue, AppColors.accentPurple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private static let _sliderSetup: Void = {
        UISlider.appearance().thumbTintColor = .white
        UISlider.appearance().minimumTrackTintColor = .clear
        UISlider.appearance().maximumTrackTintColor = .clear
    }()

    private var formattedIncome: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: incomeValue)) ?? "\(Int(incomeValue))"
    }

    private func formatNum(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: val)) ?? "\(Int(val))"
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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_IncomeView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
