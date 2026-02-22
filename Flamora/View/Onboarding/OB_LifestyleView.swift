//
//  OB_LifestyleView.swift
//  Flamora app
//
//  Onboarding Step 8 - 生活方式选择
//

import SwiftUI

struct OB_LifestyleView: View {
    var data: OnboardingData
    var onNext: () -> Void

    @State private var selected: String = "maintain"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 60)

            Text("How do you want to live\nafter financial freedom?")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)

            Spacer().frame(height: 8)

            let expenseStr = data.currencySymbol + (data.monthlyExpenses.isEmpty ? "0" : data.monthlyExpenses)
            Text("Based on your current spending of \(expenseStr)/mo.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)

            Spacer().frame(height: AppSpacing.lg)

            // 三个选项卡片
            VStack(spacing: 14) {
                LifestyleCard(
                    icon: "bicycle",
                    title: "Simpler Life",
                    desc: "Efficient & low stress",
                    detail: "80% of current spending",
                    key: "minimalist",
                    isSelected: selected == "minimalist",
                    onTap: { selected = "minimalist" }
                )

                LifestyleCard(
                    icon: "equal.circle",
                    title: "Current Lifestyle",
                    desc: "Same life, just no work",
                    detail: "100% of current spending",
                    key: "maintain",
                    isSelected: selected == "maintain",
                    onTap: { selected = "maintain" }
                )

                LifestyleCard(
                    icon: "wineglass",
                    title: "Dream Life",
                    desc: "Travel more, spend more",
                    detail: "150% of current spending",
                    key: "upgrade",
                    isSelected: selected == "upgrade",
                    onTap: { selected = "upgrade" }
                )
            }

            Spacer()

            // Generate My Plan 按钮
            Button(action: {
                data.fireType = selected
                let expenses = Double(data.monthlyExpenses) ?? 0
                switch selected {
                case "minimalist": data.targetMonthlySpend = expenses * 0.8
                case "upgrade": data.targetMonthlySpend = expenses * 1.5
                default: data.targetMonthlySpend = expenses
                }
                onNext()
            }) {
                Text("Generate My Plan")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }
}

// MARK: - Lifestyle Card
struct LifestyleCard: View {
    let icon: String
    let title: String
    let desc: String
    let detail: String
    let key: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.bodyRegular)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    Text(desc)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text(detail)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.system(size: 22))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                isSelected
                ? AppColors.backgroundCard.opacity(0.8)
                : AppColors.backgroundCard.opacity(0.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSelected
                        ? LinearGradient(colors: AppColors.gradientFire, startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let data = OnboardingData()
    data.monthlyExpenses = "3000"
    data.currencySymbol = "$"
    return OB_LifestyleView(data: data, onNext: {})
        .background(AppBackgroundView())
}
