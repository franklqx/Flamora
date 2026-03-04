//
//  OB_SignInView.swift
//  Flamora app
//
//  Onboarding Step 1 - 账号登录 / 注册
//

import SwiftUI

struct OB_SignInView: View {
    @Bindable var data: OnboardingData
    var onNext: () -> Void
    var onBack: (() -> Void)? = nil

    @FocusState private var focusedField: AuthField?
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var appear = false

    private enum AuthField: Hashable { case email, password }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── 顶部导航 ──────────────────────────────────────
                HStack {
                    Button(action: { onBack?() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }

                    Spacer()

                    Text("FLAMORA")
                        .font(.custom("Montserrat-Bold", size: 15))
                        .foregroundColor(.white)
                        .tracking(3)

                    Spacer()

                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, 16)
                .opacity(appear ? 1 : 0)

                Spacer().frame(height: 44)

                // ── 主标题 ────────────────────────────────────────
                Text(isSignUp ? "Create your account" : "Join The Journey\nTo Freedom")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 16)

                Spacer().frame(height: 40)

                // ── Social 登录按钮 ────────────────────────────────
                VStack(spacing: 12) {
                    socialButton(
                        icon: AnyView(
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                        ),
                        label: "Sign in with Apple",
                        action: {}
                    )

                    socialButton(
                        icon: AnyView(GoogleLogoView()),
                        label: "Sign in with Google",
                        action: {}
                    )
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .opacity(appear ? 1 : 0)

                Spacer().frame(height: 28)

                // ── OR 分隔线 ─────────────────────────────────────
                HStack(spacing: 14) {
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(height: 1)
                    Text(isSignUp ? "OR SIGN IN WITH EMAIL" : "OR SIGN UP WITH EMAIL")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                        .tracking(0.5)
                        .fixedSize()
                    Rectangle()
                        .fill(AppColors.borderDefault)
                        .frame(height: 1)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .opacity(appear ? 1 : 0)

                Spacer().frame(height: 20)

                // ── Email & Password 输入区 ───────────────────────
                VStack(spacing: 12) {
                    emailField
                    passwordField

                    if let error = errorMessage {
                        Text(error)
                            .font(.bodySmall)
                            .foregroundColor(AppColors.error)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .opacity(appear ? 1 : 0)

                Spacer()

                // ── 底部操作区 ────────────────────────────────────
                VStack(spacing: AppSpacing.md) {
                    Button(action: {
                        focusedField = nil
                        Task { await handleAuth() }
                    }) {
                        ZStack {
                            Text("Continue")
                                .font(.bodyRegular)
                                .fontWeight(.semibold)
                                .foregroundColor(isValid ? .black : AppColors.textTertiary)
                                .opacity(isLoading ? 0 : 1)

                            if isLoading {
                                ProgressView().tint(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isValid ? Color.white : AppColors.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }
                    .disabled(!isValid || isLoading)

                    // 切换登录 / 注册
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignUp ? "ALREADY HAVE AN ACCOUNT?" : "NEW HERE?")
                                .foregroundColor(AppColors.textSecondary)
                                .textCase(.uppercase)
                            Text(isSignUp ? "SIGN IN" : "CREATE ACCOUNT")
                                .foregroundColor(.white)
                                .underline()
                        }
                        .font(.bodySmall)
                    }

                    // 条款提示
                    (
                        Text("BY CONTINUING, YOU AGREE TO OUR ")
                            .foregroundColor(AppColors.textMuted)
                        + Text("TERMS")
                            .foregroundColor(.white)
                            .underline()
                        + Text(" & ")
                            .foregroundColor(AppColors.textMuted)
                        + Text("PRIVACY")
                            .foregroundColor(.white)
                            .underline()
                    )
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.4)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, 36)
                .opacity(appear ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .onAppear {
            focusedField = nil
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appear = true
            }
        }
        .onDisappear { focusedField = nil }
        .ignoresSafeArea(.keyboard, edges: .all)
        .animation(.easeInOut(duration: 0.2), value: errorMessage != nil)
    }

    // MARK: - Social Button

    @ViewBuilder
    private func socialButton(icon: AnyView, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                    .frame(width: 22, height: 22)
                Text(label)
                    .font(.bodyRegular)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
    }

    // MARK: - Email Field

    private var emailField: some View {
        HStack {
            TextField("", text: $data.email,
                      prompt: Text("Email address").foregroundColor(AppColors.textTertiary))
                .font(.bodyRegular)
                .foregroundColor(.white)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .email)

            if !data.email.isEmpty {
                Button { data.email = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(
                    focusedField == .email ? Color.white.opacity(0.3) : AppColors.borderDefault,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Password Field

    private var passwordField: some View {
        HStack {
            SecureField("",
                        text: $password,
                        prompt: Text("Password (min. 6 chars)").foregroundColor(AppColors.textTertiary))
                .font(.bodyRegular)
                .foregroundColor(.white)
                .textContentType(isSignUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)

            if !password.isEmpty {
                Button { password = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(
                    focusedField == .password ? Color.white.opacity(0.3) : AppColors.borderDefault,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Validation

    private var isValid: Bool {
        data.email.contains("@") && data.email.contains(".") && password.count >= 6
    }

    // MARK: - Auth Handler

    private func handleAuth() async {
        guard isValid else { return }

        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                let needsEmailConfirmation = try await SupabaseManager.shared.signUp(
                    email: data.email,
                    password: password
                )
                if needsEmailConfirmation {
                    errorMessage = "Almost there! Check your inbox to verify your email, then come back to sign in."
                    isSignUp = false
                } else {
                    data.userId = SupabaseManager.shared.currentUserId ?? ""
                    onNext()
                }
            } else {
                try await SupabaseManager.shared.signIn(
                    email: data.email,
                    password: password
                )
                data.userId = SupabaseManager.shared.currentUserId ?? ""
                onNext()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Google Logo

private struct GoogleLogoView: View {
    var body: some View {
        Canvas { context, size in
            let lw = size.width * 0.22
            let r = (min(size.width, size.height) - lw) / 2
            let cx = size.width / 2
            let cy = size.height / 2

            let segments: [(Color, Double, Double)] = [
                (.init(red: 0.918, green: 0.263, blue: 0.208), -90, 30),   // Red
                (.init(red: 0.988, green: 0.729, blue: 0.012), 30, 150),   // Yellow
                (.init(red: 0.204, green: 0.659, blue: 0.325), 150, 240),  // Green
                (.init(red: 0.259, green: 0.522, blue: 0.957), 240, 270),  // Blue arc
            ]

            for (color, from, to) in segments {
                var path = Path()
                path.addArc(center: .init(x: cx, y: cy), radius: r,
                            startAngle: .degrees(from), endAngle: .degrees(to),
                            clockwise: false)
                context.stroke(path, with: .color(color), lineWidth: lw)
            }

            // Blue 横向托架（G 字的中间横线）
            var shelf = Path()
            shelf.move(to: .init(x: cx, y: cy))
            shelf.addLine(to: .init(x: cx + r + lw / 2, y: cy))
            context.stroke(shelf, with: .color(.init(red: 0.259, green: 0.522, blue: 0.957)),
                           lineWidth: lw)
        }
        .frame(width: 20, height: 20)
    }
}

#Preview {
    OB_SignInView(data: OnboardingData(), onNext: {})
}
