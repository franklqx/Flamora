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
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 48)

                    if !data.userName.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary)
                            Text("Hi \(data.userName)")
                                .font(.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.bottom, 6)
                    }

                    Text("What does financial freedom look like to you?")
                        .font(.obQuestion)
                        .foregroundColor(.white)

                    Spacer().frame(height: 8)

                    Text("Select all that apply.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer().frame(height: AppSpacing.lg)

                    VStack(spacing: 10) {
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

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Sticky CTA
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)

                Button(action: onNext) {
                    Text("Continue")
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
                .background(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(
                                    colors: AppColors.gradientFire,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                                : AnyShapeStyle(AppColors.surfaceElevated)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: option.icon)
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .black : AppColors.textSecondary)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                // 始终预留勾选位宽度，选中与否文字区域不变，避免换行
                Group {
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
                    ? AppColors.surface.opacity(0.9)
                    : AppColors.surface.opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSelected
                            ? LinearGradient(colors: AppColors.gradientFire, startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [AppColors.borderDefault], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isSelected ? 1 : 0.75
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        let data = OnboardingData()
        let _ = { data.userName = "Alex" }()
        OB_MotivationView(data: data, onNext: {})
    }
}
