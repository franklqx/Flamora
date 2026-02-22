//
//  OnboardingContainerView.swift
//  Flamora app
//
//  Onboarding 主容器 - 管理 11 步引导流程的页面切换
//  流程: Welcome(0) → Sign In(1) → Name(2) → Motivation(3) → Age/Location(4) →
//        Income(5) → Expenses(6) → NetWorth(7) → Lifestyle(8) → Blueprint(9) →
//        Paywall(10) → 完成
//

import SwiftUI

struct OnboardingContainerView: View {
    @Binding var isOnboardingComplete: Bool  // 绑定到 ContentView，控制是否完成引导
    @State private var currentStep = 0       // 当前步骤 (0-10)
    @State private var data = OnboardingData()  // 收集的用户数据
    @State private var showToast = false     // 是否显示 toast 提示
    @State private var toastText = ""        // Toast 提示文字

    private let totalSteps = 11              // 总共 11 步 (索引 0-10)
    private let contentVerticalOffset: CGFloat = -72  // 整体内容向上偏移量

    var body: some View {
        ZStack {
            // MARK: - 背景渐变
            AppBackgroundView()

            VStack(spacing: 0) {
                // MARK: - 进度条
                // 步骤 2-9 显示（Name 到 Blueprint，共 8 格）
                if currentStep >= 2 && currentStep <= 9 {
                    OnboardingProgressBar(current: currentStep - 1, total: 8)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, 8)
                }

                // MARK: - 页面内容区域
                Group {
                    switch currentStep {
                    case 0:  // 步骤 0: 欢迎页
                        OB_WelcomeView(onNext: next)
                    case 1:  // 步骤 1: 登录/注册
                        OB_SignInView(data: data, onNext: next)
                    case 2:  // 步骤 2: 输入姓名
                        OB_NameView(data: data, onNext: next)
                    case 3:  // 步骤 3: 选择动机
                        OB_MotivationView(data: data, onNext: nextWithToast("Profile Initiated! \u{1F680}"))
                    case 4:  // 步骤 4: 年龄和地区
                        OB_AgeLocationView(data: data, onNext: next)
                    case 5:  // 步骤 5: 月收入
                        OB_IncomeView(data: data, onNext: next)
                    case 6:  // 步骤 6: 月支出
                        OB_ExpensesView(data: data, onNext: next)
                    case 7:  // 步骤 7: 净资产
                        OB_NetWorthView(data: data, onNext: nextWithToast("Foundation Set! \u{1F9F1}"))
                    case 8:  // 步骤 8: 生活方式选择
                        OB_LifestyleView(data: data, onNext: next)
                    case 9:  // 步骤 9: FIRE 蓝图确认
                        OB_BlueprintView(data: data, onNext: next)
                    default: // 步骤 10: 付费墙（最后一步，完成后进入主页面）
                        OB_PaywallView(data: data, onNext: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isOnboardingComplete = true
                            }
                        })
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),  // 新页面从右侧滑入
                    removal: .move(edge: .leading).combined(with: .opacity)      // 旧页面向左侧滑出
                ))
                .id(currentStep)  // 强制 SwiftUI 重新渲染当前步骤
            }
            .offset(y: contentVerticalOffset)

            // MARK: - Toast 提示
            // 在特定步骤完成后显示的底部提示消息
            if showToast {
                VStack {
                    Spacer()
                    Text(toastText)
                        .font(.h4)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
                .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard, edges: .all)  // 键盘弹出时不影响布局
    }

    // MARK: - 前进到下一步
    private func next() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = min(currentStep + 1, totalSteps - 1)
        }
    }

    // MARK: - 带 Toast 提示的前进方法
    // 显示一个临时提示消息，然后自动前进到下一步
    private func nextWithToast(_ text: String) -> () -> Void {
        return {
            toastText = text
            // 显示 toast
            withAnimation(.spring(response: 0.5)) {
                showToast = true
            }
            // 1.5 秒后隐藏 toast 并前进
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showToast = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    next()
                }
            }
        }
    }
}

// MARK: - 进度条组件
// 显示 onboarding 流程的完成进度（步骤 2-9，共 8 格）
struct OnboardingProgressBar: View {
    let current: Int  // 当前步骤
    let total: Int    // 总步骤数

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(AppColors.borderDefault)
                    .frame(height: 3)

                // 进度填充（火焰渐变）
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(current) / CGFloat(total), height: 3)
                    .animation(.easeInOut(duration: 0.4), value: current)  // 进度变化时平滑动画
            }
        }
        .frame(height: 3)
    }
}
