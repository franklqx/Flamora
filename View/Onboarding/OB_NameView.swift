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

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 48)

                Text("What should we call you?")
                    .font(.obQuestion)
                    .foregroundColor(.white)

                Spacer().frame(height: 10)

                Text("Your plan will be personalized just for you.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer().frame(height: AppSpacing.xl)

                TextField("", text: $data.userName,
                          prompt: Text("Your name").foregroundColor(AppColors.textTertiary))
                    .font(.bodyRegular)
                    .foregroundColor(.white)
                    .textContentType(.givenName)
                    .focused($isFocused)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(
                                isFocused ? Color.white.opacity(0.3) : AppColors.borderDefault,
                                lineWidth: 1
                            )
                    )

                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // CTA
            Button(action: {
                isFocused = false
                onNext()
            }) {
                Text("Continue")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(isValid ? .black : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? Color.white : AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(!isValid)
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.bottom, AppSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = false }
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
        OB_NameView(data: OnboardingData(), onNext: {})
    }
}
