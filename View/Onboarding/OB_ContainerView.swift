//
//  OB_ContainerView.swift
//  Flamora app
//
//  Onboarding - Main Navigation Container (18 steps)
//

import SwiftUI
internal import Auth

struct OB_ContainerView: View {
    @Binding var isOnboardingComplete: Bool
    @AppStorage("hasCompletedOnboardingV2") private var hasCompletedOnboarding = false  // key 保留兼容已完程用户

    @State private var currentStep = 0
    @State private var data = OnboardingData()
    @State private var isTransitioning = false
    /// Roadmap 内部决定：revealed 时 reverseReveal，否则跳 Lifestyle
    @State private var roadmapBackAction: (() -> Void)?

    private let supabase = SupabaseManager.shared

    private var canGoBack: Bool {
        [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 17].contains(currentStep)
    }

    private var headerProgressCurrent: Int? {
        switch currentStep {
        case 3: return 1   // IntroView
        case 4: return 2
        case 5: return 3
        case 7: return 4
        case 8: return 5
        case 9: return 6
        case 10: return 7
        case 11: return 8
        case 12: return 9
        case 13: return 10
        default: return nil  // step 6 SocialProof 无进度条
        }
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

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
                currentStep = 3
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
            var nextStep = currentStep + 1
            if nextStep == 16 { nextStep = 17 } // Skip step 16 (merged into Roadmap)
            currentStep = min(nextStep, 17)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }

    private func back() {
        isTransitioning = true
        withAnimation(.easeInOut(duration: 0.3)) {
            var prevStep = currentStep - 1
            if prevStep == 16 { prevStep = 15 } // Skip step 16 (merged into Roadmap)
            currentStep = max(prevStep, 0)
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
