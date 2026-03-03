//
//  OBV2_SocialProofView.swift
//  Flamora app
//
//  V2 Onboarding - Step 6: Social Proof Transition
//

import SwiftUI

struct OBV2_SocialProofView: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showLeftCard = false
    @State private var showRightCard = false
    @State private var showLabels = false
    @State private var showText = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
                HStack {
                    OBV2_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                Spacer()

                // MARK: - Comparison Cards
                HStack(alignment: .bottom, spacing: 20) {
                    // Left card: ON YOUR OWN
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(AppColors.backgroundCard)
                            .frame(width: 100, height: 120)

                        Text("ON YOUR OWN")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                            .opacity(showLabels ? 1 : 0)
                    }
                    .opacity(showLeftCard ? 1 : 0)

                    // Right card: WITH FLAMORA
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.gradientEnd, AppColors.gradientMiddle, AppColors.gradientStart],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                )
                            )
                            .frame(width: 140, height: 160)
                            .overlay {
                                VStack(spacing: 6) {
                                    Text("3x")
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("more confidence\nin your freedom")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .scaleEffect(showRightCard ? 1.0 : 0.5)
                            .opacity(showRightCard ? 1 : 0)

                        (Text("WITH ")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textTertiary) +
                         Text("FLAMORA")
                            .font(.system(size: 12, weight: .medium).italic())
                            .foregroundColor(.white))
                            .opacity(showLabels ? 1 : 0)
                    }
                }

                Spacer().frame(height: 40)

                // MARK: - Text Section
                VStack(spacing: 16) {
                    Text("You can't reach a goal\nwithout tracking it.")
                        .font(.h2)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    (Text("By automating your financial overview, you are ")
                        .foregroundColor(AppColors.textSecondary) +
                     Text("3x more likely")
                        .foregroundColor(AppColors.textPrimary)
                        .bold() +
                     Text(" to stay on track for your financial goals.")
                        .foregroundColor(AppColors.textSecondary))
                        .font(.bodyRegular)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.lg)
                .opacity(showText ? 1 : 0)

                Spacer()

                // CTA
                OBV2_PrimaryButton(title: "Continue", action: onNext)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showLeftCard = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showRightCard = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showLabels = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showText = true
                }
            }
        }
    }
}
