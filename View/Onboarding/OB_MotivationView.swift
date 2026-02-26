//
//  OB_MotivationView.swift
//  Flamora app
//
//  Onboarding Step 3 - 动机选择（多选卡片）
//

import SwiftUI

struct OB_MotivationView: View {
    var data: OnboardingData
    var onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 60)

            Text("Hi \(data.userName)! \u{1F44B}")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)

            Spacer().frame(height: 8)

            Text("Why are you chasing\nFinancial Independence?")
                .font(.h2)
                .foregroundColor(AppColors.textPrimary)

            Spacer().frame(height: 8)

            Text("Pick all that resonate. This shapes your whole plan.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)

            Spacer().frame(height: AppSpacing.lg)

            // 可选卡片
            VStack(spacing: 12) {
                ForEach(motivationOptions) { option in
                    MotivationCard(
                        option: option,
                        isSelected: data.motivations.contains(option.key),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if data.motivations.contains(option.key) {
                                    data.motivations.remove(option.key)
                                } else {
                                    data.motivations.insert(option.key)
                                }
                            }
                        }
                    )
                }
            }

            Spacer()

            // Next 按钮
            Button(action: onNext) {
                Text("This Is My Why →")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(isValid ? AppColors.textInverse : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? Color.white : AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(!isValid)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private var isValid: Bool {
        !data.motivations.isEmpty
    }
}

// MARK: - Motivation Card
struct MotivationCard: View {
    let option: MotivationOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: option.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.bodyRegular)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
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
            .padding(.vertical, 16)
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
    data.userName = "Alex"
    return OB_MotivationView(data: data, onNext: {})
        .background(AppBackgroundView())
}
