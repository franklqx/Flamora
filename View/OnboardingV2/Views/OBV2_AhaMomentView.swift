//
//  OBV2_AhaMomentView.swift
//  Flamora app
//
//  V2 Onboarding - Step 16: Aha Moment / Blind Spots
//

import SwiftUI

struct OBV2_AhaMomentView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showCards: [Bool] = [false, false, false]
    @State private var showFooter = false

    private var isHardCase: Bool {
        data.savingsRate <= 0 || data.freedomAge > 65
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    OBV2_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 24)

                        // Title
                        Group {
                            if isHardCase {
                                Text("\(data.userName), your journey\nto freedom starts now.")
                            } else {
                                Text("\(data.userName), your estimated\nfreedom age is \(data.freedomAge).")
                            }
                        }
                        .font(.h1)
                        .foregroundColor(AppColors.textPrimary)
                        .opacity(showTitle ? 1 : 0)

                        Spacer().frame(height: 12)

                        // Subtitle
                        Text("But this is based on your rough estimates.\nHere's what you might be missing.")
                            .font(.bodyRegular)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                            .opacity(showSubtitle ? 1 : 0)

                        Spacer().frame(height: 28)

                        // Blind spot cards
                        VStack(spacing: 12) {
                            blindSpotCard(
                                emoji: "💰",
                                title: "Your real spending might be higher",
                                body: "Most people underestimate their expenses by 20–30%. Your freedom age could shift by years.",
                                index: 0
                            )
                            blindSpotCard(
                                emoji: "🔍",
                                title: "You may have hidden savings potential",
                                body: "Unused subscriptions, duplicate charges, overspending patterns — only visible with real data.",
                                index: 1
                            )
                            blindSpotCard(
                                emoji: "📈",
                                title: "Your investments change daily",
                                body: "A static number can't capture market movement. Your FIRE progress needs live tracking.",
                                index: 2
                            )
                        }

                        Spacer().frame(height: 28)

                        // Footer
                        Text("Flamora connects to your real accounts to give you the precise picture — and keeps it updated automatically.")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .opacity(showFooter ? 1 : 0)

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }

                // CTA
                OBV2_PrimaryButton(title: "Get My Real Numbers", action: onNext)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
        .onAppear { startAnimations() }
    }

    @ViewBuilder
    private func blindSpotCard(emoji: String, title: String, body: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(body)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(AppRadius.md)
        .opacity(showCards[index] ? 1 : 0)
        .offset(y: showCards[index] ? 0 : 20)
    }

    private func startAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            withAnimation(.easeOut(duration: 0.4)) { showTitle = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) { showSubtitle = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) { showCards[0] = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.4)) { showCards[1] = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) { showCards[2] = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.4)) { showFooter = true }
        }
    }
}
