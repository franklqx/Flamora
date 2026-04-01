//
//  OB_SignInView.swift
//  Flamora app
//
//  Onboarding - Step 2: Sign In / Sign Up
//

import SwiftUI
import Supabase

struct OB_SignInView: View {
    let data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var isLoading = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    private let supabase = SupabaseManager.shared

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Bar
                HStack {
                    Spacer()
                }
                .overlay {
                    Text("FLAMORA")
                        .font(.caption)
                        .tracking(3)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.md)

                Spacer().frame(height: AppSpacing.xl + AppSpacing.sm)

                // MARK: - Title
                Text("Join The Journey\nTo Freedom")
                    .font(Font(UIFont(name: "PlayfairDisplayRoman-SemiBold", size: AppTypography.h1) ?? UIFont.systemFont(ofSize: AppTypography.h1)))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: AppSpacing.xl + AppSpacing.sm)

                // MARK: - Social Sign-In
                VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                    // Apple（OAuth；需在 Supabase Auth 启用 Apple 并在 Dashboard 配置 redirect）
                    Button {
                        Task { await signInWithOAuth(provider: .apple) }
                    } label: {
                        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                            Image(systemName: "apple.logo")
                                .font(.h3)
                                .foregroundColor(AppColors.textInverse)
                            Text("Sign in with Apple")
                                .font(.bodyRegular)
                                .foregroundColor(AppColors.textInverse)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }

                    // Google（OAuth；需在 Supabase Auth 启用 Google）
                    Button {
                        Task { await signInWithOAuth(provider: .google) }
                    } label: {
                        HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                            Text("G")
                                .font(.h3)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#4285F4"))
                            Text("Sign in with Google")
                                .font(.bodyRegular)
                                .foregroundColor(AppColors.textInverse)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                // MARK: - Divider
                HStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(height: 1)
                    Text("OR SIGN UP WITH EMAIL")
                        .font(.cardRowMeta)
                        .foregroundColor(AppColors.textTertiary)
                        .fixedSize()
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(height: 1)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.lg)

                // MARK: - Email & Password
                VStack(spacing: AppSpacing.sm + AppSpacing.xs) {
                    TextField("",
                        text: $email,
                        prompt: Text("Email address").foregroundColor(AppColors.textTertiary))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .padding()
                        .background(AppColors.backgroundCard)
                        .cornerRadius(AppRadius.md)
                        .foregroundColor(AppColors.textPrimary)

                    SecureField("",
                        text: $password,
                        prompt: Text("Password (min. 6 chars)").foregroundColor(AppColors.textTertiary))
                        .textContentType(.oneTimeCode)
                        .focused($focusedField, equals: .password)
                        .padding()
                        .background(AppColors.backgroundCard)
                        .cornerRadius(AppRadius.md)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, AppSpacing.lg)

                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.sm)
                }

                // Toggle sign up / sign in
                Button {
                    isSignUp.toggle()
                    errorMessage = ""
                } label: {
                    Text(isSignUp
                         ? "Already have an account? Sign In"
                         : "Don't have an account? Sign Up")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, AppSpacing.sm + AppSpacing.xs)

                Spacer()

                // MARK: - Continue
                VStack(spacing: 0) {
                    OB_PrimaryButton(
                        title: isLoading ? "Loading..." : "Continue",
                        isValid: !email.isEmpty && !password.isEmpty && !isLoading,
                        action: handleAuth
                    )

                    // MARK: - Terms
                    VStack(spacing: 2) {
                        Text("BY CONTINUING, YOU AGREE TO OUR")
                            .font(.label)
                            .foregroundColor(AppColors.textTertiary)
                        Text("TERMS & PRIVACY")
                            .font(.label)
                            .foregroundColor(AppColors.textTertiary)
                            .underline()
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl + AppSpacing.sm)
                    .padding(.bottom, AppSpacing.lg)
                }
                .padding(.bottom, AppSpacing.md)
            }
        }
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Auth Handler

    private func signInWithOAuth(provider: Provider) async {
        isLoading = true
        errorMessage = ""
        do {
            _ = try await supabase.signInWithOAuth(provider: provider)
            await MainActor.run {
                data.email = supabase.currentUser?.email ?? data.email
                data.userId = supabase.currentUserId ?? ""
                onNext()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        await MainActor.run { isLoading = false }
    }

    private func handleAuth() {
        isLoading = true
        errorMessage = ""
        focusedField = nil

        Task {
            do {
                if isSignUp {
                    let needsVerification = try await supabase.signUp(email: email, password: password)
                    if needsVerification {
                        errorMessage = "Check your email to verify, then sign in."
                        isSignUp = false
                        isLoading = false
                        return
                    }
                } else {
                    try await supabase.signIn(email: email, password: password)
                }

                data.email = email
                data.userId = supabase.currentUserId ?? ""
                onNext()
            } catch {
                // If sign up fails (user exists), try sign in
                if isSignUp {
                    do {
                        try await supabase.signIn(email: email, password: password)
                        data.email = email
                        data.userId = supabase.currentUserId ?? ""
                        onNext()
                        return
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
}

#Preview {
    OB_SignInView(data: OnboardingData(), onNext: {}, onBack: {})
        .background(AppBackgroundView())
}
