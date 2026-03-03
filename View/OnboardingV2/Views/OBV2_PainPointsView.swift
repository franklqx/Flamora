//
//  OBV2_PainPointsView.swift
//  Flamora app
//
//  V2 Onboarding - Step 7: Pain Point Single-Select
//

import SwiftUI

struct OBV2_PainPointsView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selectedPainPoint: String?

    private let options: [(emoji: String, title: String, key: String)] = [
        ("🔮", "I don't know where my money goes", "pain_money_tracking"),
        ("💸", "I'm not saving enough", "pain_saving"),
        ("🌱", "I have too little to invest", "pain_investing"),
        ("🔥", "I want to retire early but don't know how", "pain_fire"),
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    OBV2_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                OBV2_PersonalizeProgress(currentStep: 4, totalSteps: 5)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 32)

                // Title
                Text("What's your biggest\nfinancial challenge\nright now?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(2)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 24)

                // Options
                VStack(spacing: 12) {
                    ForEach(options, id: \.key) { option in
                        OBV2_SelectionCard(
                            emoji: option.emoji,
                            title: option.title,
                            isSelected: selectedPainPoint == option.key
                        ) {
                            selectedPainPoint = option.key
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer()

                // CTA
                OBV2_PrimaryButton(
                    title: "Continue",
                    disabled: selectedPainPoint == nil
                ) {
                    data.painPoint = selectedPainPoint ?? ""
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }
}
