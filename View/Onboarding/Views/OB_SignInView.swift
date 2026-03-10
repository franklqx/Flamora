//
//  OB_SignInView.swift
//  Flamora app
//
//  Onboarding - Step 2: Sign In / Sign Up
//

import SwiftUI

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
            Color(hex: "#121212").ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Bar
                HStack {
                    Spacer()
                }
                .overlay {
                    Text("FLAMORA")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(3)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.md)

                Spacer().frame(height: 40)

                // MARK: - Title
                Text("Join The Journey\nTo Freedom")
                    .font(Font(UIFont(name: "PlayfairDisplayRoman-SemiBold", size: AppTypography.h1) ?? UIFont.systemFont(ofSize: AppTypography.h1)))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer().frame(height: 40)

                // MARK: - Social Sign-In
                VStack(spacing: 12) {
                    // Apple
                    Button {
                        // TODO: Apple Sign In via Supabase
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                            Text("Sign in with Apple")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(12)
                    }

                    // Google
                    Button {
                        // TODO: Google Sign In via Supabase
                    } label: {
                        HStack(spacing: 12) {
                            Text("G")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#4285F4"))
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)

                // MARK: - Divider
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(height: 1)
                    Text("OR SIGN UP WITH EMAIL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .fixedSize()
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)

                // MARK: - Email & Password
                VStack(spacing: 12) {
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
                .padding(.horizontal, 24)

                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
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
                .padding(.top, 12)

                Spacer()

                // MARK: - Continue
                OB_PrimaryButton(
                    title: isLoading ? "Loading..." : "Continue",
                    isValid: !email.isEmpty && !password.isEmpty && !isLoading,
                    action: handleAuth
                )

                // MARK: - Terms
                VStack(spacing: 2) {
                    Text("BY CONTINUING, YOU AGREE TO OUR")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                    Text("TERMS & PRIVACY")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .underline()
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .onTapGesture { focusedField = nil }
    }

    // MARK: - Auth Handler

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
