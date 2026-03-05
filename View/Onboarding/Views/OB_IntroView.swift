//
//  OB_IntroView.swift
//  Flamora app
//
//  Onboarding - Step 3: "Let's build your freedom plan"
//

import SwiftUI

struct OB_IntroView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Progress
                OB_PersonalizeProgress(currentStep: 1, totalSteps: 5)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)

                Spacer().frame(height: 48)

                // Title
                Text("Let's build your\nfreedom plan")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 12)

                // Subtitle
                Text("Answer a few questions and we'll create your personalized path to financial freedom.")
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 32)

                // Info cards
                VStack(spacing: 12) {
                    infoCard(emoji: "⚡", text: "Takes less than 3 minutes")
                    infoCard(emoji: "🔒", text: "Your data stays private")
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer()

                // CTA
                OB_PrimaryButton(title: "Let's Do This", action: onNext)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private func infoCard(emoji: String, text: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(emoji)
                .font(.system(size: 20))

            Text(text)
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundCard)
        .cornerRadius(AppRadius.md)
    }
}

#Preview {
    OB_IntroView(onNext: {})
        .background(AppBackgroundView())
}
