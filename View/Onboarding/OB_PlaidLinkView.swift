//
//  OB_PlaidLinkView.swift
//  Flamora app
//
//  Onboarding Step 12 - 银行账户连接 / Plaid Link
//  用户选择是否连接银行账户以自动追踪交易
//

import SwiftUI

struct OB_PlaidLinkView: View {
    var data: OnboardingData
    var onFinish: () -> Void  // 连接银行后的回调
    var onSkip: () -> Void    // 跳过连接的回调

    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    // MARK: - 状态变量
    @State private var appear = false          // 控制进场动画
    @State private var glowScale: CGFloat = 0  // 控制图标光晕缩放
    @State private var hasTriggeredFinish = false  // 防止 onChange 重复触发 onFinish

    // MARK: - 账户类型列表
    // 展示可以连接的不同类型的金融账户
    private let accountTypes: [(icon: String, label: String)] = [
        ("banknote", "Checking"),                          // 支票账户
        ("building.columns", "Savings"),                   // 储蓄账户
        ("creditcard", "Credit Cards"),                    // 信用卡
        ("chart.line.uptrend.xyaxis", "Investments"),      // 投资账户
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - 带光晕效果的图标
            // 中央的银行图标，带有渐变光晕动画效果
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.gradientStart.opacity(0.2),
                                AppColors.gradientMiddle.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(glowScale)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appear ? 1.0 : 0.5)
                    .opacity(appear ? 1 : 0)
            }

            Spacer().frame(height: AppSpacing.xl)

            // MARK: - 页面标题
            Text("See the full picture\nof your wealth")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: appear)

            Spacer().frame(height: AppSpacing.md)

            Text("Link your accounts once — Flamora automatically\ntracks every dollar moving toward your freedom.")
                .font(.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: appear)

            Spacer().frame(height: AppSpacing.xl)

            // MARK: - 账户类型网格
            // 2x2 网格展示可连接的账户类型
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.md),
                GridItem(.flexible(), spacing: AppSpacing.md)
            ], spacing: AppSpacing.md) {
                ForEach(Array(accountTypes.enumerated()), id: \.offset) { _, type in
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: type.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: AppColors.gradientFire,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(type.label)
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.borderDefault, lineWidth: 1)
                    )
                }
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.5), value: appear)

            Spacer().frame(height: AppSpacing.lg)

            // MARK: - 安全徽章
            // 强调银行级加密，增加用户信任
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.success)

                Text("Bank-level security. We never store your credentials.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.6), value: appear)

            Spacer()

            // MARK: - 底部按钮区域
            // 包含主要的「连接银行」按钮和「跳过」链接
            VStack(spacing: AppSpacing.md) {
                Button(action: {
                    // Onboarding 场景：用户已通过 Paywall 步骤，直接触发 Plaid Link
                    Task { await plaidManager.startLinkFlow() }
                }) {
                    Group {
                        if plaidManager.isConnecting {
                            ProgressView().tint(AppColors.textInverse)
                        } else {
                            Text("Connect & Unlock My Dashboard")
                                .font(.bodyRegular)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textInverse)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .disabled(plaidManager.isConnecting)

                Button(action: {
                    data.plaidConnected = false
                    onSkip()
                }) {
                    Text("I'll connect later")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.7), value: appear)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 1.0)) {
                glowScale = 1.0
            }
        }
        // Plaid Link 成功后自动完成 onboarding（仅触发一次）
        .onChange(of: plaidManager.hasLinkedBank) { _, isLinked in
            guard isLinked, !hasTriggeredFinish else { return }
            hasTriggeredFinish = true
            data.plaidConnected = true
            onFinish()
        }
    }
}

#Preview {
    OB_PlaidLinkView(data: OnboardingData(), onFinish: {}, onSkip: {})
        .background(AppBackgroundView())
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
