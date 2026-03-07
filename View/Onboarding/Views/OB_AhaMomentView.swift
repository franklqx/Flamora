//
//  OB_AhaMomentView.swift
//  Flamora app
//
//  Onboarding - Step 16: Aha Moment / Blind Spots
//

import SwiftUI

struct OB_AhaMomentView: View {
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
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 40)

                    // Line 1: 名字
                    Text(data.userName.isEmpty ? "Friend" : data.userName)
                        .font(.obQuestion)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(showTitle ? 1 : 0)

                    Spacer().frame(height: 8)

                    // Line 2: 句子
                    Group {
                        if isHardCase {
                            Text("Your Journey To Freedom Starts Now")
                        } else {
                            Text("Your estimated Freedom age is \(data.freedomAge)")
                        }
                    }
                    .font(.obQuestion)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                            systemImage: "banknote",
                            title: "Your real spending might be higher",
                            body: "Most people underestimate their expenses by 20–30%. Your freedom age could shift by years.",
                            index: 0
                        )
                        blindSpotCard(
                            systemImage: "magnifyingglass",
                            title: "You may have hidden savings potential",
                            body: "Unused subscriptions, duplicate charges, overspending patterns — only visible with real data.",
                            index: 1
                        )
                        blindSpotCard(
                            systemImage: "chart.line.uptrend.xyaxis",
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

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Sticky CTA（与 AgeView 一致）
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                OB_PrimaryButton(title: "Get My Real Numbers", action: onNext)
                .background(Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { startAnimations() }
    }

    @ViewBuilder
    private func blindSpotCard(systemImage: String, title: String, body: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(LinearGradient(
                    colors: [AppColors.accentBlue, AppColors.accentPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                ))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(body)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_AhaMomentView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
