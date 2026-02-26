//
//  OB_SuccessView.swift
//  Flamora app
//
//  Onboarding Step 10 - 成功页 / Dashboard 介绍
//

import SwiftUI

struct OB_SuccessView: View {
    var data: OnboardingData
    var onFinish: () -> Void

    @State private var appear = false
    @State private var sunriseProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 日出动画
            ZStack {
                // 光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.gradientEnd.opacity(0.3),
                                AppColors.gradientMiddle.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(sunriseProgress)

                // 发射图标
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appear ? 1.0 : 0.3)
                    .opacity(appear ? 1 : 0)
            }

            Spacer().frame(height: AppSpacing.xxl)

            Text("Your FIRE journey\nstarts now, \(data.userName)! 🔥")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: appear)

            Spacer().frame(height: AppSpacing.md)

            Text("Your personalized FIRE dashboard is ready.\nLet's see how close you are to freedom.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: appear)

            Spacer()

            // Go to Dashboard 按钮
            Button(action: onFinish) {
                Text("See My Dashboard 🔥")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.8), value: appear)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 1.2)) {
                sunriseProgress = 1.0
            }
        }
    }
}

#Preview {
    let data = OnboardingData()
    data.userName = "Alex"
    return OB_SuccessView(data: data, onFinish: {})
        .background(AppBackgroundView())
}
