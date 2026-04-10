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
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            GeometryReader { geo in
                let cardsHeight: CGFloat = 180 + 180 + 40  // top spacer + cards area + gap
                let textAreaHeight = max(200, geo.size.height - cardsHeight - 120)  // 120 for bottom CTA
                let verticalPadding = max(24, (textAreaHeight - 120) / 2)  // 120 approx text block height

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 180)

                        // MARK: - Comparison Cards
                        HStack(alignment: .bottom, spacing: 20) {
                        // Left card: ON YOUR OWN
                        VStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .fill(AppColors.glassCardBg)
                                .frame(width: 100, height: 96)

                            Text("ON YOUR OWN")
                                .font(.caption)
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
                                    VStack(spacing: AppSpacing.sm) {
                                        Text("3x")
                                            .font(.display)
                                            .foregroundColor(AppColors.textInverse)
                                        Text("more confidence\nin your freedom")
                                            .font(.footnoteRegular)
                                            .foregroundColor(AppColors.textInverse)
                                            .multilineTextAlignment(.center)
                                    }
                                    .opacity(showRightCard ? 1 : 0)
                                    .animation(.easeOut(duration: 0.3).delay(0.4), value: showRightCard)
                                }
                                .mask(
                                    VStack {
                                        Spacer(minLength: 0)
                                        Rectangle()
                                            .frame(height: showRightCard ? 160 : 0)
                                    }
                                    .frame(width: 140, height: 160)
                                )
                                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showRightCard)

                            Text("WITH \(Text("FLAMORA").font(.caption.italic()).foregroundStyle(AppColors.inkPrimary))")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                                .opacity(showLabels ? 1 : 0)
                        }
                    }
                    .allowsHitTesting(false)

                        Spacer().frame(height: 40)
                            .allowsHitTesting(false)

                        // MARK: - Text Section (垂直居中)
                        Spacer().frame(height: verticalPadding)
                            .allowsHitTesting(false)

                        VStack(spacing: 16) {
                            Text("You can't reach a goal\nwithout tracking it.")
                                .font(.obQuestion)
                                .foregroundColor(AppColors.inkPrimary)
                                .multilineTextAlignment(.center)

                            Text("By automating your financial overview, you are \(Text("3x more likely").foregroundColor(AppColors.inkPrimary).bold()) to stay on track for your financial goals.")
                                .foregroundColor(AppColors.inkSoft)
                                .font(.bodyRegular)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .opacity(showText ? 1 : 0)
                        .allowsHitTesting(false)

                        Spacer().frame(height: verticalPadding)
                            .allowsHitTesting(false)
                    }
                }
            }

            // 固定在屏幕最下方的 CTA
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [AppColors.shellBg2.opacity(0), AppColors.shellBg2],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Continue", action: onNext)
            }
            .padding(.bottom, 16)
            .background(AppColors.shellBg2)
            .ignoresSafeArea(edges: .bottom)
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
