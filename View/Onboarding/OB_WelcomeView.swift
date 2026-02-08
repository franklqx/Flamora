//
//  OB_WelcomeView.swift
//  Flamora app
//
//  Onboarding Step 1 - Welcome / Value Prop
//

import SwiftUI

struct OB_WelcomeView: View {
    var onNext: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 旗帜动画
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.gradientStart.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(appear ? 1.0 : 0.6)

                Image(systemName: "flag.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appear ? 1.0 : 0.5)
                    .offset(y: appear ? 0 : 20)
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: appear)

            Spacer()
                .frame(height: AppSpacing.xxl)

            Text("It's not about\nbeing rich.")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: appear)

            Text("It's about being free.")
                .font(.h1)
                .foregroundStyle(
                    LinearGradient(
                        colors: AppColors.gradientFire,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: appear)

            Spacer()
                .frame(height: AppSpacing.md)

            Text("Answer a few simple questions.\nLet's build your personalized map\nto Financial Independence.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: appear)

            Spacer()

            // Start My Journey 按钮
            Button(action: onNext) {
                Text("Start My Journey")
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
        .onAppear { appear = true }
    }
}
