//
//  OBV2_NameView.swift
//  Flamora app
//
//  V2 Onboarding - Step 4: Name Input
//

import SwiftUI

struct OBV2_NameView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var name = ""
    @FocusState private var isFocused: Bool

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

                OBV2_PersonalizeProgress(currentStep: 2, totalSteps: 5)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)

                Spacer().frame(height: 48)

                // Title
                Text("What should we call\nyou?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 40)

                // Name input with underline
                VStack(spacing: 0) {
                    TextField("", text: $name, prompt: Text("Your name")
                        .foregroundColor(AppColors.textTertiary))
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(AppColors.textPrimary)
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)

                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 1)
                        .padding(.top, 12)
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer()

                // CTA
                OBV2_PrimaryButton(
                    title: "Continue",
                    disabled: name.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    data.userName = name.trimmingCharacters(in: .whitespaces)
                    onNext()
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .onTapGesture { isFocused = false }
        .onAppear { isFocused = true }
    }
}
