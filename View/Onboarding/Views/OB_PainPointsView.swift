//
//  OB_PainPointsView.swift
//  Flamora app
//
//  Onboarding Step - Primary financial challenge (single-select cards)
//

import SwiftUI
import UIKit

struct OB_PainPointsView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void
    var onBack: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: OB_OnboardingHeader.height)

                    Spacer().frame(height: AppSpacing.sm)

                    Text("What's your biggest financial challenge right now?")
                        .font(.obQuestion)
                        .foregroundStyle(AppColors.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 8)

                    Text("Select the one that feels most true right now.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.inkSoft)

                    Spacer().frame(height: AppSpacing.lg)

                    VStack(spacing: 10) {
                        ForEach(challengeOptions) { option in
                            ChallengeCard(
                                option: option,
                                isSelected: data.painPoint == option.key,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        if data.painPoint == option.key {
                                            data.painPoint = ""
                                        } else {
                                            data.painPoint = option.key
                                        }
                                    }
                                }
                            )
                        }
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Sticky CTA
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [AppColors.shellBg2.opacity(0), AppColors.shellBg2],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)

                OB_PrimaryButton(isValid: isValid, action: onNext)
            }
            .padding(.bottom, 16)
            .background(AppColors.shellBg2)
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.shellBg2)
    }

    private var isValid: Bool {
        !data.painPoint.isEmpty
    }
}

// MARK: - Challenge Card

private struct ChallengeCard: View {
    let option: ChallengeOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(
                                    colors: AppColors.gradientShellAccent,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                                : AnyShapeStyle(AppColors.glassCardBg)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: option.icon)
                        .font(.fieldBodyMedium)
                        .foregroundColor(isSelected ? AppColors.textInverse : AppColors.inkSoft)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                // 始终预留勾选位宽度，选中与否文字区域不变，避免换行
                Group {
                    if isSelected {
                        Image(systemName: "checkmark.circle")
                            .font(.h3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: AppColors.gradientShellAccent,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected
                    ? AppColors.glassCardBg.opacity(0.9)
                    : AppColors.glassCardBg.opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSelected
                            ? LinearGradient(colors: AppColors.gradientShellAccent, startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [AppColors.inkBorder], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isSelected ? 1 : 0.75
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        OB_PainPointsView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
