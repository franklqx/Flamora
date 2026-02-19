//
//  OB_SignInView.swift
//  Flamora app
//
//  Onboarding Step 0 - Email 登录 / 注册
//

import SwiftUI

struct OB_SignInView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void

    @FocusState private var focusedField: AuthField?
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private enum AuthField: Hashable { case email, password }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 80)

                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.h1)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
                    .frame(height: AppSpacing.lg)

                // Email 输入框
                emailField

                Spacer()
                    .frame(height: AppSpacing.md)

                // 密码输入框
                passwordField

                Spacer()
                    .frame(height: AppSpacing.md)

                // 错误信息
                if let error = errorMessage {
                    Text(error)
                        .font(.bodySmall)
                        .foregroundColor(AppColors.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .offset(y: -4)))
                }

                Spacer()
            }

            // 底部：切换模式 + 主按钮
            VStack(spacing: AppSpacing.md) {
                // 切换 Sign In / Sign Up
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                } label: {
                    Text(isSignUp
                         ? "Already have an account? Sign in"
                         : "New here? Create account")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .underline()
                }

                // 主按钮
                Button(action: {
                    focusedField = nil
                    Task { await handleAuth() }
                }) {
                    ZStack {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.bodyRegular)
                            .fontWeight(.semibold)
                            .foregroundColor(isValid ? AppColors.textInverse : AppColors.textTertiary)
                            .opacity(isLoading ? 0 : 1)

                        if isLoading {
                            ProgressView()
                                .tint(AppColors.textInverse)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isValid ? Color.white : AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .disabled(!isValid || isLoading)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .onAppear { focusedField = nil }
        .onDisappear { focusedField = nil }
        .ignoresSafeArea(.keyboard, edges: .all)
        .animation(.easeInOut(duration: 0.2), value: errorMessage != nil)
    }

    // MARK: - Email Field

    private var emailField: some View {
        HStack {
            TextField("", text: $data.email,
                      prompt: Text("your@email.com").foregroundColor(AppColors.textTertiary))
                .font(.bodyRegular)
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .email)

            if !data.email.isEmpty {
                Button { data.email = "" } label: {
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
                .stroke(focusedField == .email
                        ? AppColors.textTertiary.opacity(0.5)
                        : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Password Field

    private var passwordField: some View {
        HStack {
            SecureField("", text: $password,
                        prompt: Text("Password (min. 6 chars)").foregroundColor(AppColors.textTertiary))
                .font(.bodyRegular)
                .foregroundColor(AppColors.textPrimary)
                .textContentType(isSignUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)

            if !password.isEmpty {
                Button { password = "" } label: {
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
                .stroke(focusedField == .password
                        ? AppColors.textTertiary.opacity(0.5)
                        : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Validation

    private var isValid: Bool {
        data.email.contains("@") && data.email.contains(".") && password.count >= 6
    }

    // MARK: - Auth Handler

    private func handleAuth() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                let needsEmailConfirmation = try await SupabaseManager.shared.signUp(
                    email: data.email,
                    password: password
                )
                if needsEmailConfirmation {
                    // 需要邮箱验证，提示用户后切换回登录模式
                    errorMessage = "Check your email to confirm your account, then sign in."
                    isSignUp = false
                } else {
                    data.userId = SupabaseManager.shared.currentUserId ?? ""
                    print("✅ Sign up success, userId: \(data.userId)")
                    onNext()
                }
            } else {
                try await SupabaseManager.shared.signIn(
                    email: data.email,
                    password: password
                )
                data.userId = SupabaseManager.shared.currentUserId ?? ""
                print("✅ Sign in success, userId: \(data.userId)")
                onNext()
            }
        } catch {
            print("Auth error: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }


}

#Preview {
    OB_SignInView(data: OnboardingData(), onNext: {})
        .background(AppBackgroundView())
}
