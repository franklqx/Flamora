//
//  OnboardingContainerView.swift
//  Flamora app
//
//  Onboarding 主容器 - 管理引导流程的页面切换
//
//  当前流程:
//  Welcome(0) → SignIn(1) →
//  FreedomIntro(2) → Name(3) → Motivation(4) → TrackingBenefits(5) → FinancialChallenge(6) →
//  ChallengeFlow(7, 按 primaryChallenge 分流) →
//  Age/Location(8) → Income(9) → Expenses(10) → NetWorth(11) → Lifestyle(12) →
//  LoadingAnalysis(13) → Roadmap(14) → AhaMoment(15) →
//  Paywall(16) → PlaidLink(17) → 完成
//

import SwiftUI

struct OnboardingContainerView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentStep = 0
    @State private var data = OnboardingData()
    @State private var showToast = false
    @State private var toastText = ""

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let totalSteps = 18

    // 欢迎轮播：使用天空背景
    private var isWelcomeStep: Bool { currentStep == 0 }
    // 需要进度头部的步骤（前 5 个问题页）
    private var showProgressHeader: Bool { currentStep >= 2 && currentStep <= 6 }

    var body: some View {
        ZStack {
            // ── 背景 ───────────────────────────────────────────────
            // Step 0 (Welcome) 的背景在 OB_WelcomeView 内部自管理
            if !isWelcomeStep {
                Color.black.ignoresSafeArea()
            }

            // ── 内容 ───────────────────────────────────────────────
            VStack(spacing: 0) {
                // 步骤进度头部（问题段 step 2-6）
                if showProgressHeader {
                    OBStepHeader(currentStep: currentStep)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }

                // 页面主体
                Group {
                    switch currentStep {
                    case 0:
                        OB_WelcomeView(onNext: next)
                    case 1:
                        OB_SignInView(data: data, onNext: next, onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) { currentStep = 0 }
                        })
                    case 2:
                        OB_FreedomIntroView(onNext: next)
                    case 3:
                        OB_NameView(data: data, onNext: next)
                    case 4:
                        OB_MotivationView(data: data, onNext: next)
                    case 5:
                        OB_TrackingBenefitsView(onNext: next)
                    case 6:
                        OB_FinancialChallengeView(data: data, onNext: next)
                    case 7:
                        // Personalized reveal page based on selected challenge
                        Group {
                            switch data.challengeFlow {
                            case .noVisibility:
                                OB_ChallengeNoVisibilityView(onNext: next)
                            case .notSaving:
                                OB_ChallengeNotSavingView(onNext: next)
                            case .tooLittleToInvest:
                                OB_ChallengeTooLittleToInvestView(onNext: next)
                            case .retireEarly:
                                OB_ChallengeRetireEarlyView(onNext: next)
                            }
                        }
                    case 8:
                        OB_AgeLocationView(data: data, onNext: next)
                    case 9:
                        OB_IncomeView(data: data, onNext: next)
                    case 10:
                        OB_ExpensesView(data: data, onNext: next)
                    case 11:
                        OB_NetWorthView(data: data, onNext: next)
                    case 12:
                        OB_LifestyleView(data: data, onNext: next)
                    case 13:
                        OB_LoadingAnalysisView(data: data, onNext: next)
                    case 14:
                        OB_RoadmapView(data: data, onNext: next)
                    case 15:
                        OB_AhaMomentView(onNext: next)
                    case 16:
                        OB_PaywallView(data: data, onNext: next)
                    default:
                        OB_PlaidLinkView(
                            data: data,
                            onFinish: {
                                hasCompletedOnboarding = true
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isOnboardingComplete = true
                                }
                            },
                            onSkip: {
                                hasCompletedOnboarding = true
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isOnboardingComplete = true
                                }
                            }
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // 左侧空白区域点击返回上一页（仅当存在上一页时）
            if currentStep >= 1 {
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: 56)
                        .frame(maxHeight: .infinity)
                        .onTapGesture { back() }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
            }

            // Toast 提示
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
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    // MARK: - Navigation Helpers

    private func next() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = min(currentStep + 1, totalSteps - 1)
        }
    }

    private func back() {
        guard currentStep >= 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = currentStep - 1
        }
    }

    private func nextWithToast(_ text: String) -> () -> Void {
        return {
            toastText = text
            withAnimation(.spring(response: 0.5)) {
                showToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showToast = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    next()
                }
            }
        }
    }
}

// MARK: - Step Header (问卷进度头部)

struct OBStepHeader: View {
    let currentStep: Int

    // 前 5 个问题页：STEP x OF 5
    private var stepIndex: Int { max(1, currentStep - 1) }
    private var sectionLabel: String { "STEP \(stepIndex) OF 5" }

    // 进度条宽度比例
    private var progressFraction: CGFloat {
        return CGFloat(stepIndex) / 5.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标签行
            HStack {
                Text(sectionLabel)
                    .font(.obStepLabel)
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(0.8)

                Spacer()
            }

            // 进度轨道
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.surfaceInput)
                        .frame(height: 2)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressFraction, height: 2)
                        .animation(.easeInOut(duration: 0.4), value: progressFraction)
                }
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Legacy Progress Bar (kept for reference)

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.borderDefault)
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: AppColors.gradientFire,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * CGFloat(current) / CGFloat(total),
                        height: 3
                    )
                    .animation(.easeInOut(duration: 0.4), value: current)
            }
        }
        .frame(height: 3)
    }
}
