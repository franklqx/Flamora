//
//  OB_FreedomIntroView.swift
//  Flamora app
//
//  Onboarding Step 2 - Intro: Let's build your freedom plan
//

import SwiftUI

struct OB_FreedomIntroView: View {
    var onNext: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 48)

                    HStack(alignment: .center, spacing: 16) {
                        // 小图标卡片
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppColors.surfaceElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.borderDefault, lineWidth: 1)
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        Spacer()
                    }

                    Spacer().frame(height: 20)

                    // 标题
                    Text("Let’s build your freedom plan")
                        .font(.obQuestion)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 12)

                    // 副标题
                    Text("Answer a few questions and we’ll create your personalized path to financial freedom.")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: AppSpacing.xl)

                    VStack(spacing: 10) {
                        OBInfoPill(
                            systemIcon: "bolt",
                            title: "Takes less than 3 minutes"
                        )

                        OBInfoPill(
                            systemIcon: "lock",
                            title: "Your data stays private"
                        )
                    }

                    Spacer().frame(height: 140)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // CTA
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)

                Button(action: onNext) {
                    Text("Let’s Do This")
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, AppSpacing.xxl)
                .background(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Info Pill

private struct OBInfoPill: View {
    let systemIcon: String
    let title: String

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.bodySmall)
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.borderDefault, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_FreedomIntroView(onNext: {})
    }
}

