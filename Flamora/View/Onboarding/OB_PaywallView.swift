//
//  OB_PaywallView.swift
//  Flamora app
//
//  Onboarding Step 11 - 付费墙 / Paywall
//  用户选择订阅方案（月付或年付）
//

import SwiftUI
import RevenueCat

struct OB_PaywallView: View {
    var data: OnboardingData
    var onNext: () -> Void

    @Environment(SubscriptionManager.self) private var subscriptionManager

    // MARK: - 状态变量
    @State private var selectedPlan: String = "yearly"  // 默认选择年付方案
    @State private var appear = false                   // 控制进场动画
    @State private var isPurchasing = false

    // MARK: - Pro 功能列表
    // 展示订阅后可以解锁的所有高级功能
    private let features: [(icon: String, text: String)] = [
        ("link", "Bank & credit card linking"),              // 银行和信用卡连接
        ("list.bullet.rectangle", "Auto transaction tracking"), // 自动交易跟踪
        ("creditcard", "Debt & liability tracking"),          // 债务和负债跟踪
        ("repeat", "Recurring transaction alerts"),           // 定期交易提醒
        ("flame", "FIRE calculator & simulator"),             // FIRE 计算器和模拟器
        ("chart.pie", "Smart budget tools"),                  // 智能预算工具
        ("chart.line.uptrend.xyaxis", "Investment portfolio tracking"), // 投资组合跟踪
        ("brain.head.profile", "AI-powered FIRE insights"),   // AI 驱动的 FIRE 洞察
        ("building.2", "Enriched merchant data & logos"),     // 丰富的商家数据和 logo
        ("sparkles", "Advanced FIRE scenarios"),              // 高级 FIRE 场景
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 48)

                    // MARK: - 页面顶部
                    // 包含 Flamora Pro 图标、标题和副标题
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: AppColors.gradientFire,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Flamora Pro")
                            .font(.h1)
                            .foregroundColor(AppColors.textPrimary)

                        Text("Unlock your complete FIRE journey")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.textSecondary)

                        Text("Start with a 7-day free trial")
                            .font(.bodySmall)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.success)
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.1), value: appear)

                    Spacer().frame(height: AppSpacing.lg)

                    // MARK: - 功能列表卡片
                    // 垂直排列所有 Pro 功能，每项之间用分割线隔开
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.success)

                                Text(feature.text)
                                    .font(.bodySmall)
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 8)

                            if index < features.count - 1 {
                                Divider()
                                    .background(AppColors.borderDefault)
                            }
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.borderDefault, lineWidth: 1)
                    )
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: appear)

                    Spacer().frame(height: AppSpacing.lg)

                    // MARK: - 订阅方案选择
                    // 展示两个订阅选项：年付（推荐）和月付
                    VStack(spacing: AppSpacing.md) {
                        // 年付方案（推荐，更优惠）
                        PlanCard(
                            title: "Yearly",
                            price: "$69.99",
                            period: "/year",
                            detail: "$5.83/mo",
                            badge: "SAVE 42%",
                            isSelected: selectedPlan == "yearly",
                            isRecommended: true
                        ) {
                            // 用户点击年付方案时，更新选中状态
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPlan = "yearly"
                            }
                        }

                        // 月付方案
                        PlanCard(
                            title: "Monthly",
                            price: "$9.99",
                            period: "/month",
                            detail: nil,
                            badge: nil,
                            isSelected: selectedPlan == "monthly",
                            isRecommended: false
                        ) {
                            // 用户点击月付方案时，更新选中状态
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPlan = "monthly"
                            }
                        }
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: appear)

                    Spacer().frame(height: AppSpacing.xl)
                }
            }

            // MARK: - 底部按钮区域
            // 包含主要的「开始试用」按钮和「恢复购买」链接
            VStack(spacing: AppSpacing.md) {
                Button(action: {
                    data.selectedPlan = selectedPlan
                    Task { await purchase() }
                }) {
                    Group {
                        if isPurchasing {
                            ProgressView().tint(AppColors.textInverse)
                        } else {
                            Text("Start Free Trial")
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
                .disabled(isPurchasing)

                Button(action: {
                    Task {
                        isPurchasing = true
                        _ = await subscriptionManager.restorePurchases()
                        isPurchasing = false
                        onNext()
                    }
                }) {
                    Text("Restore Purchases")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                .disabled(isPurchasing)
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.7), value: appear)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
        .onAppear {
            // 页面出现时随机选择一个订阅方案
            // 50% 概率选择年付，50% 概率选择月付
            selectedPlan = Bool.random() ? "yearly" : "monthly"

            // 触发进场动画
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
    }
}

// MARK: - Purchase Logic

private extension OB_PaywallView {
    func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                onNext()
                return
            }
            // 找到对应方案的 package
            let targetPackage = offering.availablePackages.first {
                $0.storeProduct.productIdentifier.contains(selectedPlan)
            } ?? offering.availablePackages.first

            guard let package = targetPackage else {
                onNext()
                return
            }

            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            if !userCancelled {
                subscriptionManager.isPremium = customerInfo.entitlements["Flamora Pro"]?.isActive == true
            }
        } catch {
            print("Purchase error: \(error)")
        }

        onNext()
    }
}

// MARK: - 订阅方案卡片组件
// 用于展示单个订阅方案的可点击卡片
struct PlanCard: View {
    let title: String           // 方案名称（如 "Yearly"）
    let price: String           // 价格（如 "$69.99"）
    let period: String          // 周期（如 "/year"）
    let detail: String?         // 详细说明（如 "$5.83/mo"）
    let badge: String?          // 徽章文字（如 "SAVE 42%"）
    let isSelected: Bool        // 是否被选中
    let isRecommended: Bool     // 是否为推荐方案
    let onTap: () -> Void       // 点击回调

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // 选择状态指示器（选中时显示勾选图标）
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(AppColors.textTertiary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.h4)
                        .foregroundColor(AppColors.textPrimary)

                    if let detail = detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.h3)
                        .foregroundColor(AppColors.textPrimary)

                    Text(period)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let badge = badge {
                    Text(badge)
                        .font(.label)
                        .foregroundColor(AppColors.textInverse)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppColors.backgroundCard.opacity(isSelected ? 0.8 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSelected && isRecommended
                        ? AnyShapeStyle(LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        : isSelected
                        ? AnyShapeStyle(Color.white.opacity(0.3))
                        : AnyShapeStyle(AppColors.borderDefault),
                        lineWidth: isSelected && isRecommended ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OB_PaywallView(data: OnboardingData(), onNext: {})
        .background(AppBackgroundView())
}
