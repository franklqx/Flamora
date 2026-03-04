//
//  OB_IncomeView.swift
//  Flamora app
//
//  Onboarding Step 5 - 月收入（Financial Snapshot 2/5）
//  改为滑块输入，提升交互体验
//

import SwiftUI

struct OB_IncomeView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    // 滑块范围: $0 – $20,000+（对数缩放，线性映射到 [0,1]）
    @State private var sliderValue: Double = 0.275   // 默认 ~$5,500

    private let maxIncome: Double = 20_000

    var incomeValue: Double {
        // 线性映射 → $0 to $20,000
        sliderValue * maxIncome
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 40)

                Text("What's your monthly\nincome?")
                    .font(.obQuestion)
                    .foregroundColor(.white)
                    .lineSpacing(2)

                Spacer().frame(height: 8)

                Text("A rough estimate is fine")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer().frame(height: AppSpacing.xxl)

                // 大数字展示
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(data.currencySymbol)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)

                    Text(formatNumber(incomeValue))
                        .font(.obDisplay)
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2), value: formatNumber(incomeValue))

                    Text("/mo")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer().frame(height: AppSpacing.xl)

                // 滑块
                VStack(spacing: 8) {
                    Slider(value: $sliderValue, in: 0...1, step: 0.005)
                        .tint(.white)
                        .onChange(of: sliderValue) { _, newVal in
                            let rounded = round(incomeValue / 100) * 100
                            data.monthlyIncome = "\(Int(rounded))"
                        }

                    HStack {
                        Text("\(data.currencySymbol)0")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                        Text("\(data.currencySymbol)20K+")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Spacer().frame(height: AppSpacing.lg)

                // 洞察卡片
                if incomeValue > 0 {
                    incomeInsightCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .animation(.easeInOut(duration: 0.3), value: incomeValue > 0)

            // CTA
            Button(action: {
                let rounded = round(incomeValue / 100) * 100
                data.monthlyIncome = "\(Int(max(1, rounded)))"
                onNext()
            }) {
                Text("Next")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(isValid ? .black : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? Color.white : AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(!isValid)
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // 如已有值则初始化滑块
            if let existing = Double(data.monthlyIncome), existing > 0 {
                sliderValue = min(existing / maxIncome, 1.0)
            }
        }
    }

    // MARK: - Insight Card

    private var incomeInsightCard: some View {
        let percentile = incomePercentile(incomeValue)
        return HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)

            Text("Your income is higher than **\(percentile)%** of people in your age group.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var isValid: Bool { sliderValue > 0.005 }

    private func formatNumber(_ val: Double) -> String {
        let rounded = round(val / 100) * 100
        return NumberFormatter.localizedString(from: NSNumber(value: Int(rounded)), number: .decimal)
    }

    private func incomePercentile(_ income: Double) -> Int {
        switch income {
        case ..<2000: return 15
        case ..<4000: return 35
        case ..<6000: return 55
        case ..<8000: return 72
        case ..<12000: return 85
        default: return 94
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_IncomeView(data: OnboardingData(), onNext: {})
    }
}
