//
//  OB_TrackingBenefitsView.swift
//  Flamora app
//
//  Onboarding Step 4 - Tracking benefits with 3x confidence card
//  Layout: cards on top, then title/body. Staged animation: left card → right card (grow) → text.
//

import SwiftUI

struct OB_TrackingBenefitsView: View {
    var onNext: () -> Void

    @State private var leftCardShown = false
    @State private var gradientCardShown = false
    @State private var textShown = false
    @State private var hasAnimated = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 0) {
                    Spacer().frame(height: 48)

                    // ── 1. 双卡片（上）左右对称，右卡高度更高 ─────────────────────
                    HStack(alignment: .bottom, spacing: 28) {
                        // Left: small dark card + label below（更矮、更小）
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(AppColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(AppColors.borderDefault, lineWidth: 1)
                                )
                                .frame(width: 120, height: 120)
                                .scaleEffect(leftCardShown ? 1 : 0.92)
                                .opacity(leftCardShown ? 1 : 0)

                            Text("ON YOUR OWN")
                                .font(.caption)
                                .foregroundColor(.white)
                                .tracking(0.8)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Right: large gradient card + label below（更高，体现 3x）
                        VStack(spacing: 8) {
                            VStack(alignment: .center, spacing: 6) {
                                Spacer()
                                    .frame(minHeight: 8)
                                Text("3x")
                                    .font(.system(size: 46, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                Text("more")
                                    .font(.bodySmall)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                Text("confidence in your freedom")
                                    .font(.bodySmall)
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                    .frame(minHeight: 8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 22)
                            .frame(width: 176)
                            .frame(minHeight: 216)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.99, green: 0.78, blue: 0.39),
                                        Color(red: 0.96, green: 0.48, blue: 0.62),
                                        Color(red: 0.67, green: 0.47, blue: 0.98)
                                    ],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .shadow(color: Color.black.opacity(0.28), radius: 22, x: 0, y: 18)
                            .scaleEffect(gradientCardShown ? 1 : 0.88)
                            .opacity(gradientCardShown ? 1 : 0)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.78),
                                value: gradientCardShown
                            )

                            Text("WITH FLAMORA")
                                .font(.caption)
                                .foregroundColor(.white)
                                .tracking(0.8)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // 卡片区与标语区明显分离
                    Spacer().frame(height: AppSpacing.xxl)

                    // ── 2. 标题与正文（下）──────────────────────────────────
                    VStack(alignment: .center, spacing: 12) {
                        Text("You can't reach a goal without tracking it.")
                            .font(.obQuestion)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        bodyText
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(textShown ? 1 : 0)
                    .offset(y: textShown ? 0 : 8)
                    .animation(.easeOut(duration: 0.35), value: textShown)
                    .frame(maxWidth: .infinity, alignment: .center)

                    Spacer().frame(height: 160)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // CTA（与标语、正文同步出现）
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
            .opacity(textShown ? 1 : 0)
            .offset(y: textShown ? 0 : 8)
            .animation(.easeOut(duration: 0.35), value: textShown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true

            // Phase 1: left card
            withAnimation(.easeOut(duration: 0.3)) {
                leftCardShown = true
            }

            // Phase 2: right card (grow) after 0.25s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                gradientCardShown = true
            }

            // Phase 3: title + body after right card (0.25 + ~0.5 + 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                textShown = true
            }
        }
    }

    private var bodyText: some View {
        (
            Text("By automating your financial overview, you are ")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
            + Text("3x more likely")
                .font(.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            + Text(" to stay on track for your financial goals.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_TrackingBenefitsView(onNext: {})
    }
}
