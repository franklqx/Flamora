//
//  OB_MotivationView.swift
//  Flamora app
//
//  Onboarding Step 3 - 动机选择（多选卡片）
//

import SwiftUI

struct OB_MotivationView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void
    var onBack: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: OB_OnboardingHeader.height)

                    Spacer().frame(height: AppSpacing.sm)

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
                        .foregroundStyle(.white)

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

                OB_PrimaryButton(isValid: isValid, action: onNext)
                .background(Color.black)
                .ignoresSafeArea(edges: .bottom)
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
                        .foregroundStyle(.white)
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
                        Image(systemName: "checkmark.circle")
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
        OB_MotivationView(data: data, onNext: {}, onBack: {})
    }
}
