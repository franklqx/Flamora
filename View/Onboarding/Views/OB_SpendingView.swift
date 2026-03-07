//
//  OB_SpendingView.swift
//  Flamora app
//
//  Onboarding - Step 11: Monthly Spending (Snapshot 3/5)
//

import SwiftUI

struct OB_SpendingView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var spendingValue: Double = 0
    @State private var showInsight = false
    @State private var insightWorkItem: DispatchWorkItem?
    private let spendingRange: ClosedRange<Double> = 0...20000

    private var income: Double {
        Double(data.monthlyIncome) ?? 0
    }

    private var savingsRate: Int {
        guard income > 0 else { return 0 }
        return Int(((income - spendingValue) / income) * 100)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    OB_SnapshotProgress(current: 3, total: 5)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, AppSpacing.md)

                    Spacer().frame(height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("How much do you typically spend per month?")
                            .font(.obQuestion)
                            .foregroundColor(.white)
                        Text("Include rent, groceries, entertainment, etc.")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MONTHLY SPENDING")
                            .font(.obStepLabel)
                            .foregroundColor(AppColors.textTertiary)
                            .tracking(0.8)

                        spendingCard
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    if showInsight && spendingValue > 0 && income > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SAVINGS RATE")
                                .font(.obStepLabel)
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

            // Sticky CTA（与 AgeView 一致）
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Next", action: {
                    data.monthlyExpenses = "\(Int(spendingValue))"
                    onNext()
                })
                .background(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Spacer()
                Text(data.currencySymbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                Text(formattedSpending)
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
                        let progress = CGFloat((spendingValue - spendingRange.lowerBound) / (spendingRange.upperBound - spendingRange.lowerBound))
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

                    Slider(value: $spendingValue, in: spendingRange, step: 100)
                        .frame(height: 28)
                        .onChange(of: spendingValue) { _, newVal in
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

    private var formattedSpending: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: spendingValue)) ?? "\(Int(spendingValue))"
    }

    // MARK: - Savings Rate Card

    private var savingsRateCard: some View {
        let rate = max(0, savingsRate)
        let monthlySavings = max(0, income - spendingValue)

        return VStack(spacing: 16) {
            // 大数字：saving rate
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Spacer()
                Text("\(rate)")
                    .font(.system(size: 56, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: rate)
                Text("%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            // 分割线
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Income − Spending = Saved 分解
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Income")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(data.currencySymbol)\(formattedAmount(income))")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                Spacer()
                Text("−")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                VStack(spacing: 4) {
                    Text("Spending")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(data.currencySymbol)\(formattedAmount(spendingValue))")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                Spacer()
                Text("=")
                    .font(.system(size: 18, weight: .light))
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
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(accentGradient)
                Text(savingsMicrocopy(rate: rate))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(AppColors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
        Color.black.ignoresSafeArea()
        OB_SpendingView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
