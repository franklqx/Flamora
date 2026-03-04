//
//  OB_NetWorthView.swift
//  Flamora app
//
//  Onboarding Step 7 - 投资/净资产（Financial Snapshot 4/5）
//  改为滑块输入 + 被动收入洞察
//

import SwiftUI

struct OB_NetWorthView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    @State private var sliderValue: Double = 0.075   // 默认 ~$150,000

    private let maxNetWorth: Double = 2_000_000

    var netWorthValue: Double {
        sliderValue * maxNetWorth
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 40)

                Text("What's your total\ninvestment portfolio value?")
                    .font(.obQuestion)
                    .foregroundColor(.white)
                    .lineSpacing(2)

                Spacer().frame(height: 8)

                Text("Including stocks, bonds, retirement (401k, IRA), crypto, etc.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer().frame(height: AppSpacing.xxl)

                // 大数字
                Text("\(data.currencySymbol)\(formatCompact(netWorthValue))")
                    .font(.obDisplay)
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.2), value: formatCompact(netWorthValue))
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer().frame(height: AppSpacing.xl)

                // 滑块
                VStack(spacing: 8) {
                    Slider(value: $sliderValue, in: 0...1, step: 0.002)
                        .tint(.white)
                        .onChange(of: sliderValue) { _, _ in
                            data.currentNetWorth = "\(Int(netWorthValue))"
                        }

                    HStack {
                        Text("\(data.currencySymbol)0")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                        Text("\(data.currencySymbol)2M+")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Spacer().frame(height: AppSpacing.lg)

                // 洞察卡片
                passiveIncomeInsightCard
                    .transition(.opacity)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // CTA
            VStack(spacing: 10) {
                Button(action: {
                    data.currentNetWorth = "\(Int(netWorthValue))"
                    onNext()
                }) {
                    Text("Next")
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }

                // 跳过（保留原有逻辑）
                Button {
                    data.currentNetWorth = "0"
                    onNext()
                } label: {
                    Text("I'll Add This Later")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if let existing = Double(data.currentNetWorth), existing > 0 {
                sliderValue = min(existing / maxNetWorth, 1.0)
            }
        }
    }

    // MARK: - Insight Card

    private var passiveIncomeInsightCard: some View {
        let passiveIncome = netWorthValue * 0.04 / 12  // 4% rule / 12 months
        let formattedPassive = passiveIncome >= 1000
            ? "\(data.currencySymbol)\(String(format: "%.0fK", passiveIncome / 1000))"
            : "\(data.currencySymbol)\(Int(passiveIncome))"

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.info.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.info)
            }

            VStack(alignment: .leading, spacing: 3) {
                if netWorthValue > 0 {
                    Text("Your investments currently generate **~\(formattedPassive)/mo** in sustainable passive income (based on the 4% rule) — you're on your way!")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    Text("Every portfolio starts at zero. Your first dollar invested is the most important one.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.borderDefault, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: netWorthValue)
    }

    // MARK: - Helpers

    private func formatCompact(_ val: Double) -> String {
        if val >= 1_000_000 {
            return String(format: "%.1fM", val / 1_000_000)
        } else if val >= 1_000 {
            let thousands = Int(val / 1_000)
            let remainder = Int(val) % 1_000
            return remainder > 0
                ? "\(thousands),\(String(format: "%03d", remainder))"
                : "\(thousands),000"
        }
        return "\(Int(val))"
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_NetWorthView(data: OnboardingData(), onNext: {})
    }
}
