//
//  OnboardingContainerView.swift
//  Flamora app
//
//  Onboarding 主容器 - 管理页面流转
//

import SwiftUI

struct OnboardingContainerView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentStep = 0
    @State private var data = OnboardingData()
    @State private var showToast = false
    @State private var toastText = ""

    private let totalSteps = 11
    private let contentVerticalOffset: CGFloat = -72

    var body: some View {
        ZStack {
            // 背景
            AppBackgroundView()

            VStack(spacing: 0) {
                // 进度条 (Sign In 后才显示)
                if currentStep > 0 {
                    OnboardingProgressBar(current: currentStep, total: totalSteps - 1)
                        .padding(.horizontal, AppSpacing.screenPadding)
                        .padding(.top, 8)
                }

                // 只渲染当前页面
                Group {
                    switch currentStep {
                    case 0:
                        OB_SignInView(data: data, onNext: next)
                    case 1:
                        OB_WelcomeView(onNext: next)
                    case 2:
                        OB_NameView(data: data, onNext: next)
                    case 3:
                        OB_MotivationView(data: data, onNext: nextWithToast("Profile Initiated! \u{1F680}"))
                    case 4:
                        OB_AgeLocationView(data: data, onNext: next)
                    case 5:
                        OB_IncomeView(data: data, onNext: next)
                    case 6:
                        OB_ExpensesView(data: data, onNext: next)
                    case 7:
                        OB_NetWorthView(data: data, onNext: nextWithToast("Foundation Set! \u{1F9F1}"))
                    case 8:
                        OB_LifestyleView(data: data, onNext: next)
                    case 9:
                        OB_BlueprintView(data: data, onNext: next)
                    default:
                        OB_SuccessView(data: data, onFinish: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isOnboardingComplete = true
                            }
                        })
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)
            }
            .offset(y: contentVerticalOffset)

            // Toast
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
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    private func next() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = min(currentStep + 1, totalSteps - 1)
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

// MARK: - Progress Bar
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
                    .frame(width: geo.size.width * CGFloat(current) / CGFloat(total), height: 3)
                    .animation(.easeInOut(duration: 0.4), value: current)
            }
        }
        .frame(height: 3)
    }
}
