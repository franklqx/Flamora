//
//  OB_ExpensesView.swift
//  Flamora app
//
//  Onboarding Step 6 - 月支出（Financial Snapshot 3/5）
//  改为滑块输入
//

import SwiftUI

struct OB_ExpensesView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    @State private var sliderValue: Double = 0.32   // 默认 ~$3,200

    private let maxExpenses: Double = 10_000

    var expensesValue: Double {
        sliderValue * maxExpenses
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 40)

                Text("How much do you\ntypically spend per month?")
                    .font(.obQuestion)
                    .foregroundColor(.white)
                    .lineSpacing(2)

                Spacer().frame(height: AppSpacing.xxl)

                // 大数字
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(data.currencySymbol)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)

                    Text(formatNumber(expensesValue))
                        .font(.obDisplay)
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2), value: formatNumber(expensesValue))

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
                        .onChange(of: sliderValue) { _, _ in
                            let rounded = round(expensesValue / 100) * 100
                            data.monthlyExpenses = "\(Int(rounded))"
                        }

                    HStack {
                        Text("\(data.currencySymbol)0")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Spacer()
                        Text("\(data.currencySymbol)10K+")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Spacer().frame(height: AppSpacing.lg)

                // 洞察卡片
                if expensesValue > 0, let income = Double(data.monthlyIncome), income > 0 {
                    savingsInsightCard(income: income)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .animation(.easeInOut(duration: 0.3), value: expensesValue > 0)

            // CTA
            Button(action: {
                let rounded = round(expensesValue / 100) * 100
                data.monthlyExpenses = "\(Int(max(1, rounded)))"
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
            if let existing = Double(data.monthlyExpenses), existing > 0 {
                sliderValue = min(existing / maxExpenses, 1.0)
            }
        }
    }

    // MARK: - Insight Card

    private func savingsInsightContent(income: Double) -> (emoji: String, message: String) {
        let rate = max(0, (income - expensesValue) / income * 100)
        if rate >= 40 {
            return ("🎉", "Your savings rate is **\(Int(rate))%** — this is a solid foundation!")
        } else if rate >= 20 {
            return ("📈", "Your savings rate is **\(Int(rate))%** — you're building momentum.")
        } else if rate > 0 {
            return ("💡", "Your savings rate is **\(Int(rate))%** — Flamora can help you find more.")
        } else {
            return ("⚠️", "Your expenses exceed income right now — let's find solutions together.")
        }
    }

    private func savingsInsightCard(income: Double) -> some View {
        let content = savingsInsightContent(income: income)
        return HStack(alignment: .top, spacing: 12) {
            Text(content.emoji)
                .font(.system(size: 20))
            Text((try? AttributedString(markdown: content.message)) ?? AttributedString(content.message))
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
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        let data = OnboardingData()
        let _ = { data.monthlyIncome = "5500" }()
        OB_ExpensesView(data: data, onNext: {})
    }
}
