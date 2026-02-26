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
                Spacer()
                    .frame(height: 80)

                Text("First, what should\nwe call you?")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)

                Spacer().frame(height: 8)

                Text("Your plan will be personalized just for you.")
                    .font(.bodySmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()
                    .frame(height: AppSpacing.lg)

                TextField("", text: $data.userName, prompt: Text("Your first name").foregroundColor(AppColors.textTertiary))
                    .font(.bodyRegular)
                    .foregroundColor(AppColors.textPrimary)
                    .textContentType(.givenName)
                    .focused($isFocused)
                    .padding(.horizontal, 20)
                    .frame(height: 56)
                    .background(AppColors.backgroundCard.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(isFocused ? AppColors.textTertiary.opacity(0.5) : Color.clear, lineWidth: 1)
                    )

                Spacer()
            }

            Button(action: {
                isFocused = false
                onNext()
            }) {
                Text("That's Me →")
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(isValid ? AppColors.textInverse : AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? Color.white : AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(!isValid)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
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
    OB_NameView(data: OnboardingData(), onNext: {})
        .background(AppBackgroundView())
}
