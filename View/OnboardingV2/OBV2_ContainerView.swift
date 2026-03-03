//
//  OBV2_ContainerView.swift
//  Flamora app
//
//  V2 Onboarding - Main Navigation Container (18 steps)
//

import SwiftUI
internal import Auth

struct OBV2_ContainerView: View {
    @Binding var isOnboardingComplete: Bool
    @AppStorage("hasCompletedOnboardingV2") private var hasCompletedOnboardingV2 = false

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
            // Already authenticated but hasn't completed V2 onboarding — skip to step 3
            if supabase.isAuthenticated && !hasCompletedOnboardingV2 {
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
        case 0:  OBV2_SplashView(onNext: next)
        case 1:  OBV2_WelcomeView(onNext: next)
        case 2:  OBV2_SignInView(data: data, onNext: next, onBack: back)
        case 3:  OBV2_IntroView(onNext: next)
        case 4:  OBV2_NameView(data: data, onNext: next, onBack: back)
        case 5:  OBV2_MotivationView(data: data, onNext: next, onBack: back)
        case 6:  OBV2_SocialProofView(onNext: next, onBack: back)
        case 7:  OBV2_PainPointsView(data: data, onNext: next, onBack: back)
        case 8:  OBV2_ValueScreenView(data: data, onNext: next, onBack: back)
        case 9:  OBV2_AgeView(data: data, onNext: next, onBack: back)
        case 10: OBV2_IncomeView(data: data, onNext: next, onBack: back)
        case 11: OBV2_SpendingView(data: data, onNext: next, onBack: back)
        case 12: OBV2_InvestmentView(data: data, onNext: next, onBack: back)
        case 13: OBV2_LifestyleView(data: data, onNext: next, onBack: back)
        case 14: OBV2_LoadingView(onNext: next)
        case 15: OBV2_RoadmapView(data: data, onNext: next, onBack: back)
        case 16: OBV2_AhaMomentView(data: data, onNext: next, onBack: back)
        default: OBV2_PaywallView(data: data, onBack: back, onComplete: completeOnboarding)
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
        hasCompletedOnboardingV2 = true
        withAnimation(.easeInOut(duration: 0.5)) {
            isOnboardingComplete = true
        }
    }
}
