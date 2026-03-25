//
//  OB_NameView.swift
//  Flamora app
//
//  Onboarding Step 2 - 名字输入
//

import SwiftUI

struct OB_NameView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void
    var onBack: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
                .onTapGesture { isFocused = false }

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: OB_OnboardingHeader.height)
                    .allowsHitTesting(false)

                Spacer().frame(height: AppSpacing.sm)
                    .allowsHitTesting(false)

                HStack(alignment: .center, spacing: 16) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.borderDefault, lineWidth: 1)
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .font(.h4)
                                .foregroundStyle(.white)
                        )
                    Spacer()
                }
                .allowsHitTesting(false)

                Spacer().frame(height: 20)
                    .allowsHitTesting(false)

                Text("What should we call you?")
                    .font(.obQuestion)
                    .foregroundStyle(.white)
                    .allowsHitTesting(false)

                Spacer().frame(height: 10)
                    .allowsHitTesting(false)

                Text("Your plan will be personalized just for you.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
                    .allowsHitTesting(false)

                Spacer().frame(height: AppSpacing.xl)
                    .allowsHitTesting(false)

                TextField("", text: $data.userName,
                          prompt: Text("Your name").foregroundColor(AppColors.textTertiary))
                    .font(.bodyRegular)
                    .foregroundStyle(.white)
                    .textContentType(.givenName)
                    .focused($isFocused)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(
                                isFocused ? AppColors.overlayWhiteForegroundSoft : AppColors.borderDefault,
                                lineWidth: 1
                            )
                    )

                Spacer()
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // CTA
            OB_PrimaryButton(isValid: isValid, action: {
                isFocused = false
                onNext()
            })
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { isFocused = false }
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    private var isValid: Bool {
        data.userName.trimmingCharacters(in: .whitespaces).count >= 1
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OB_NameView(data: OnboardingData(), onNext: {}, onBack: {})
    }
}
