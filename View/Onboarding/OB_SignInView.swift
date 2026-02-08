//
//  OB_SignInView.swift
//  Flamora app
//
//  Onboarding Step 0 - Email 登录
//

import SwiftUI

struct OB_SignInView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 80)

                Text("Email")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
                    .frame(height: AppSpacing.lg)

                // Email 输入框
                HStack {
                    TextField("", text: $data.email, prompt: Text("your@email.com").foregroundColor(AppColors.textTertiary))
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textPrimary)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isFocused)

                    if !data.email.isEmpty {
                        Button {
                            data.email = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                                .font(.system(size: 18))
                        }
                    }
                }
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

            // Continue 按钮固定底部
            Button(action: {
                isFocused = false
                onNext()
            }) {
                Text("Continue")
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
        .onDisappear {
            isFocused = false
        }
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    private var isValid: Bool {
        data.email.contains("@") && data.email.contains(".")
    }
}


