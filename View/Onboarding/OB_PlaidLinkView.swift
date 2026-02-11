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

    // MARK: - 状态变量
    @State private var appear = false          // 控制进场动画
    @State private var glowScale: CGFloat = 0  // 控制图标光晕缩放

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
            Text("Connect Your\nAccounts")
                .font(.h1)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: appear)

            Spacer().frame(height: AppSpacing.md)

            Text("Link your bank accounts to automatically\ntrack your path to financial independence.")
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

                Text("Bank-level 256-bit encryption")
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
                    // 标记用户已连接银行账户
                    data.plaidConnected = true
                    // TODO: 未来这里会调用 Plaid Link SDK
                    // 现在只是占位，直接完成 onboarding
                    onFinish()
                }) {
                    Text("Connect Your Bank")
                        .font(.bodyRegular)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }

                Button(action: {
                    // 标记用户跳过了银行连接
                    data.plaidConnected = false
                    // 直接完成 onboarding，稍后可以在设置中连接
                    onSkip()
                }) {
                    Text("Skip for now")
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
            // 触发进场动画
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
            // 启动光晕缩放动画
            withAnimation(.easeOut(duration: 1.0)) {
                glowScale = 1.0
            }
        }
    }
}

#Preview {
    OB_PlaidLinkView(data: OnboardingData(), onFinish: {}, onSkip: {})
        .background(AppBackgroundView())
}
