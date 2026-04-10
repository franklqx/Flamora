//
//  OB_ContainerView.swift
//  Flamora app
//
//  Onboarding - Main Navigation Container (18 steps)
//

import SwiftUI
internal import Auth

struct OB_ContainerView: View {
    enum ThemeSurface: Equatable {
        case immersiveDark
        case welcomeException
        case lightShell
    }

    struct StepConfig: Equatable {
        let allowsBack: Bool
        let headerProgress: Int?
        let themeSurface: ThemeSurface
    }

    private enum StepID: Int {
        case splash = 0
        case welcome = 1
        case signIn = 2
        case intro = 3
        case name = 4
        case motivation = 5
        case socialProof = 6
        case painPoints = 7
        case valueScreen = 8
        case age = 9
        case income = 10
        case spending = 11
        case investment = 12
        case lifestyle = 13
        case loading = 14
        case roadmap = 15
        case ahaMoment = 16
        case paywall = 17
    }

    private static let stepConfigs: [Int: StepConfig] = [
        StepID.splash.rawValue: StepConfig(allowsBack: false, headerProgress: nil, themeSurface: .immersiveDark),
        StepID.welcome.rawValue: StepConfig(allowsBack: false, headerProgress: nil, themeSurface: .welcomeException),
        StepID.signIn.rawValue: StepConfig(allowsBack: true, headerProgress: nil, themeSurface: .lightShell),
        StepID.intro.rawValue: StepConfig(allowsBack: true, headerProgress: 1, themeSurface: .lightShell),
        StepID.name.rawValue: StepConfig(allowsBack: true, headerProgress: 2, themeSurface: .lightShell),
        StepID.motivation.rawValue: StepConfig(allowsBack: true, headerProgress: 3, themeSurface: .lightShell),
        StepID.socialProof.rawValue: StepConfig(allowsBack: true, headerProgress: nil, themeSurface: .lightShell),
        StepID.painPoints.rawValue: StepConfig(allowsBack: true, headerProgress: 4, themeSurface: .lightShell),
        StepID.valueScreen.rawValue: StepConfig(allowsBack: true, headerProgress: 5, themeSurface: .lightShell),
        StepID.age.rawValue: StepConfig(allowsBack: true, headerProgress: 6, themeSurface: .lightShell),
        StepID.income.rawValue: StepConfig(allowsBack: true, headerProgress: 7, themeSurface: .lightShell),
        StepID.spending.rawValue: StepConfig(allowsBack: true, headerProgress: 8, themeSurface: .lightShell),
        StepID.investment.rawValue: StepConfig(allowsBack: true, headerProgress: 9, themeSurface: .lightShell),
        StepID.lifestyle.rawValue: StepConfig(allowsBack: true, headerProgress: 10, themeSurface: .lightShell),
        StepID.loading.rawValue: StepConfig(allowsBack: false, headerProgress: nil, themeSurface: .lightShell),
        StepID.roadmap.rawValue: StepConfig(allowsBack: true, headerProgress: nil, themeSurface: .immersiveDark),
        StepID.ahaMoment.rawValue: StepConfig(allowsBack: false, headerProgress: nil, themeSurface: .immersiveDark),
        StepID.paywall.rawValue: StepConfig(allowsBack: true, headerProgress: nil, themeSurface: .lightShell),
    ]

    static func config(for step: Int) -> StepConfig {
        stepConfigs[step] ?? StepConfig(allowsBack: false, headerProgress: nil, themeSurface: .immersiveDark)
    }

    static func nextStep(after currentStep: Int) -> Int {
        var nextStep = currentStep + 1
        if nextStep == StepID.ahaMoment.rawValue { nextStep = StepID.paywall.rawValue } // Step 16 已合并到 Roadmap
        return min(nextStep, StepID.paywall.rawValue)
    }

    static func previousStep(before currentStep: Int) -> Int {
        var previousStep = currentStep - 1
        if previousStep == StepID.ahaMoment.rawValue { previousStep = StepID.roadmap.rawValue } // Step 16 已合并到 Roadmap
        return max(previousStep, StepID.splash.rawValue)
    }

    @Binding var isOnboardingComplete: Bool
    @AppStorage("hasCompletedOnboardingV2") private var hasCompletedOnboarding = false  // key 保留兼容已完程用户

    @State private var currentStep = 0
    @State private var data = OnboardingData()
    @State private var isTransitioning = false
    /// Roadmap 内部决定：revealed 时 reverseReveal，否则跳 Lifestyle
    @State private var roadmapBackAction: (() -> Void)?

    private let supabase = SupabaseManager.shared

    private var stepConfig: StepConfig {
        Self.config(for: currentStep)
    }

    private var canGoBack: Bool {
        stepConfig.allowsBack
    }

    private var headerProgressCurrent: Int? {
        stepConfig.headerProgress
    }

    private var containerBackground: some View {
        Group {
            switch stepConfig.themeSurface {
            case .lightShell:
                LinearGradient(
                    colors: [AppColors.shellBg1, AppColors.shellBg2],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .welcomeException, .immersiveDark:
                AppColors.backgroundPrimary
            }
        }
        .ignoresSafeArea()
    }

    var body: some View {
        ZStack {
            containerBackground

            currentStepView
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)

            backButtonOverlay
        }
        .onAppear {
            // Already authenticated but hasn't completed onboarding — skip to step 3
            if supabase.isAuthenticated && !hasCompletedOnboarding {
                data.userId = supabase.currentUserId ?? ""
                data.email = supabase.currentUser?.email ?? ""
                currentStep = StepID.intro.rawValue
            }
        }
    }

    // MARK: - Back Button Overlay (extracted to reduce body type complexity)

    @ViewBuilder
    private var backButtonOverlay: some View {
        if canGoBack && !isTransitioning {
            if let current = headerProgressCurrent {
                VStack {
                    OB_OnboardingHeader(onBack: back, current: current, total: 10)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack {
                    OB_BackButton(action: handleBackButtonTap)
                        .padding(.leading, AppSpacing.screenPadding)
                        .padding(.top, 0)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func handleBackButtonTap() {
        if currentStep == 15 {
            roadmapBackAction?() ?? goToLifestyleFromRoadmap()
        } else {
            back()
        }
    }

    // MARK: - Step Router

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0:  OB_SplashView(onNext: next)
        case 1:  OB_WelcomeView(onNext: next)
        case 2:  OB_SignInView(data: data, onNext: next, onBack: back)
        case 3:  OB_IntroView(onNext: next, onBack: back)
        case 4:  OB_NameView(data: data, onNext: next, onBack: back)
        case 5:  OB_MotivationView(data: data, onNext: next, onBack: back)
        case 6:  OB_SocialProofView(onNext: next, onBack: back)
        case 7:  OB_PainPointsView(data: data, onNext: next, onBack: back)
        case 8:  OB_ValueScreenView(data: data, onNext: next, onBack: back)
        case 9:  OB_AgeView(data: data, onNext: next, onBack: back)
        case 10: OB_IncomeView(data: data, onNext: next, onBack: back)
        case 11: OB_SpendingView(data: data, onNext: next, onBack: back)
        case 12: OB_InvestmentView(data: data, onNext: next, onBack: back)
        case 13: OB_LifestyleView(data: data, onNext: next, onBack: back)
        case 14: OB_LoadingView(onNext: next)
        case 15: OB_RoadmapView(data: data, onNext: next, onBackToLifestyle: goToLifestyleFromRoadmap, backAction: $roadmapBackAction)
        default: OB_PaywallView(data: data, onBack: back, onComplete: completeOnboarding)
        }
    }

    // MARK: - Navigation

    private func next() {
        isTransitioning = true
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = Self.nextStep(after: currentStep)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }

    private func back() {
        isTransitioning = true
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = Self.previousStep(before: currentStep)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }

    /// Roadmap 第一页返回时直接跳到 Lifestyle（跳过 Loading）
    private func goToLifestyleFromRoadmap() {
        isTransitioning = true
        roadmapBackAction = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = 13
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }

    // MARK: - Complete Onboarding

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        withAnimation(.easeInOut(duration: 0.5)) {
            isOnboardingComplete = true
        }
    }
}

#Preview {
    OB_ContainerView(isOnboardingComplete: .constant(false))
        .background(AppBackgroundView())
}
