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

    private let supabase = SupabaseManager.shared

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            currentStepView
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)
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

    // MARK: - Step Router

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0:  OB_SplashView(onNext: next)
        case 1:  OB_WelcomeView(onNext: next)
        case 2:  OB_SignInView(data: data, onNext: next, onBack: back)
        case 3:  OB_IntroView(onNext: next)
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
        case 15: OB_RoadmapView(data: data, onNext: next, onBack: back)
        case 16: OB_AhaMomentView(data: data, onNext: next, onBack: back)
        default: OB_PaywallView(data: data, onBack: back, onComplete: completeOnboarding)
        }
    }

    // MARK: - Navigation

    private func next() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = min(currentStep + 1, 17)
        }
    }

    private func back() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = max(currentStep - 1, 0)
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
