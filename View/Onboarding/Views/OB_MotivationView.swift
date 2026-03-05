//
//  OB_MotivationView.swift
//  Flamora app
//
//  Onboarding - Step 5: Motivation Multi-Select
//

import SwiftUI

struct OB_MotivationView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var selectedMotivations: Set<String> = []

    private let options: [(emoji: String, title: String, subtitle: String, key: String)] = [
        ("💼", "Quit the 9-5", "Work because you want to", "quit"),
        ("👨‍👩‍👧", "Family First", "Be there for every moment that matters.", "family"),
        ("🛡", "Security", "No money stress", "security"),
        ("⚔️", "Adventure", "Go anywhere, anytime.", "adventure"),
        ("❤️", "Passion", "Build what you actually care about.", "passion"),
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    OB_BackButton(action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)

                OB_PersonalizeProgress(currentStep: 3, totalSteps: 5)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 24)

                // Title
                Text("Hi \(data.userName)! 👋\nWhat does financial freedom look like to you?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(2)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 8)

                Text("Select all that apply.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 16)

                // Options
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(options, id: \.key) { option in
                            OB_SelectionCard(
                                emoji: option.emoji,
                                title: option.title,
                                subtitle: option.subtitle,
                                isSelected: selectedMotivations.contains(option.key)
                            ) {
                                if selectedMotivations.contains(option.key) {
                                    selectedMotivations.remove(option.key)
                                } else {
                                    selectedMotivations.insert(option.key)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 4)
                    .padding(.bottom, AppSpacing.md)
                }

                // CTA
                OB_PrimaryButton(
                    title: "Continue",
                    disabled: selectedMotivations.isEmpty
                ) {
                    data.motivations = selectedMotivations
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }
}

#Preview {
    OB_MotivationView(data: OnboardingData(), onNext: {}, onBack: {})
        .background(AppBackgroundView())
}
