//
//  OB_SocialProofView.swift
//  Flamora app
//
//  Onboarding - Step 6: Social Proof Transition
//

import SwiftUI

struct OB_SocialProofView: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showLeftCard = false
    @State private var showRightCard = false
    @State private var showLabels = false
    @State private var showText = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            // 左半屏点击返回区域（在底层，按钮优先接收点击）
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: geo.size.width / 2)
                        .contentShape(Rectangle())
                        .onTapGesture { onBack() }
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
            }

            VStack(spacing: 0) {
                Spacer()
                    .allowsHitTesting(false)

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
                                        .foregroundColor(.black)
                                    Text("more confidence\nin your freedom")
                                        .font(.system(size: 13))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .scaleEffect(showRightCard ? 1.0 : 0.5)
                            .opacity(showRightCard ? 1 : 0)

                        Text("WITH \(Text("FLAMORA").font(.system(size: 12, weight: .medium).italic()).foregroundColor(.white))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                            .opacity(showLabels ? 1 : 0)
                    }
                }
                .allowsHitTesting(false)

                Spacer().frame(height: 40)
                    .allowsHitTesting(false)

                // MARK: - Text Section
                VStack(spacing: 16) {
                    Text("You can't reach a goal\nwithout tracking it.")
                        .font(.obQuestion)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("By automating your financial overview, you are \(Text("3x more likely").foregroundColor(AppColors.textPrimary).bold()) to stay on track for your financial goals.")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.bodyRegular)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.lg)
                .opacity(showText ? 1 : 0)
                .allowsHitTesting(false)

                Spacer()
                    .allowsHitTesting(false)

                // CTA
                OB_PrimaryButton(title: "Continue", action: onNext)
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

#Preview {
    OB_SocialProofView(onNext: {}, onBack: {})
        .background(AppBackgroundView())
}
