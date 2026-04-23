//
//  BS_LoadingView.swift
//  Flamora app
//
//  Budget Setup — Step 1: Loading
//  V3: Onboarding-style loading animation + 3 sequential status lines
//

import SwiftUI

struct BS_LoadingView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    var onComplete: () -> Void

    private enum ChecklistState { case waiting, loading, done }
    private let loadingSteps = [
        "Reviewing your recent cash flow...",
        "Filtering out one-time purchases...",
        "Building your cash flow snapshot...",
    ]

    @State private var step1State: ChecklistState = .waiting
    @State private var step2State: ChecklistState = .waiting
    @State private var step3State: ChecklistState = .waiting
    @State private var showIcon = false
    @State private var rotation: Double = 0
    @State private var barProgress: CGFloat = 0

    // Timeout / error state
    @State private var showError = false
    private let timeoutSeconds: Double = 25
    /// Incremented on every retry. All pending DispatchQueue blocks from earlier attempts
    /// capture the attempt value at scheduling time and bail out if it no longer matches,
    /// preventing stale timers from triggering showError during a newer load cycle.
    @State private var loadAttempt: Int = 0

    var body: some View {
        Group {
            if showError || viewModel.loadingError != nil {
                errorView
            } else {
                loadingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    // MARK: - Normal loading view

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()
            heroSection
            Spacer().frame(height: AppSpacing.xxl)
            checklistSection
            Spacer()
            progressBarSection
        }
        .onAppear {
            startHeroAnimation()
            startChecklistAnimation()
            Task { await viewModel.loadInitialData() }
            scheduleTimeout()
        }
    }

    // MARK: - Error / timeout view

    private var errorView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(AppColors.inkSoft)

            VStack(spacing: AppSpacing.sm) {
                Text("Something went wrong")
                    .font(.h4)
                    .foregroundStyle(AppColors.inkPrimary)

                Text(viewModel.loadingError ?? "This is taking longer than expected.\nPlease check your connection and try again.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Button(action: retryLoading) {
                Text("Try Again")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(AppColors.ctaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.inkPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.lg)

            Spacer()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.accentBlueBright.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 140, height: 140)
                .opacity(showIcon ? 1 : 0)

            Image(systemName: "sparkle")
                .font(.h1)
                .fontWeight(.light)
                .foregroundStyle(
                    LinearGradient(
                        colors: AppColors.gradientShellAccent,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(rotation))
                .opacity(showIcon ? 1 : 0)
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            checklistRow(label: loadingSteps[0], state: step1State)
            checklistRow(label: loadingSteps[1], state: step2State)
            checklistRow(label: loadingSteps[2], state: step3State)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    @ViewBuilder
    private func checklistRow(label: String, state: ChecklistState) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Step indicator
            ZStack {
                switch state {
                case .waiting:
                    Color.clear
                        .frame(width: 20, height: 20)
                case .loading:
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppColors.inkSoft)
                        .frame(width: 20, height: 20)
                case .done:
                    Image(systemName: "checkmark")
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.inkFaint)
                        .frame(width: 20, height: 20)
                }
            }

            Text(label)
                .font(.bodySmall)
                .foregroundStyle(state == .waiting ? .clear : AppColors.inkSoft)
        }
        .animation(.easeOut(duration: 0.3), value: state == .waiting)
    }

    // MARK: - Progress Bar

    private var progressBarSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.progressTrack)
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: AppColors.gradientShellAccent,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * barProgress, height: 3)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Animations

    private func startHeroAnimation() {
        withAnimation(.easeIn(duration: 0.3)) { showIcon = true }
        withAnimation(.linear(duration: 3.0)) { rotation = 360 }
        withAnimation(.linear(duration: 3.0)) { barProgress = 1.0 }
    }

    private func startChecklistAnimation() {
        let attempt = loadAttempt
        // Mirror onboarding timing so the UX feels consistent across flows.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard loadAttempt == attempt else { return }
            step1State = .loading
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard loadAttempt == attempt else { return }
            step1State = .done
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard loadAttempt == attempt else { return }
            step2State = .loading
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            guard loadAttempt == attempt else { return }
            step2State = .done
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            guard loadAttempt == attempt else { return }
            step3State = .loading
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard loadAttempt == attempt else { return }
            step3State = .done
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            guard loadAttempt == attempt else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard loadAttempt == attempt else { return }
                if viewModel.allLoadingComplete {
                    completeAndNavigate()
                } else if viewModel.loadingError != nil {
                    // Body switches to errorView automatically via observation
                } else {
                    pollForCompletion(attempt: attempt)
                }
            }
        }
    }

    private func pollForCompletion(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard loadAttempt == attempt else { return }  // stale poll from a previous attempt
            if viewModel.allLoadingComplete {
                completeAndNavigate()
            } else if viewModel.loadingError != nil {
                // Body switches to errorView automatically via observation
            } else if showError {
                // Timed out; stay on error view
            } else {
                pollForCompletion(attempt: attempt)
            }
        }
    }

    private func scheduleTimeout() {
        let attempt = loadAttempt
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
            guard loadAttempt == attempt else { return }  // stale — a retry already happened
            guard !viewModel.allLoadingComplete, viewModel.loadingError == nil else { return }
            showError = true
        }
    }

    /// Increments loadAttempt BEFORE calling onComplete. This is critical: it invalidates
    /// all pending DispatchQueue blocks (timeout, polls) so they cannot write to @State
    /// after the view has been removed from the hierarchy (freed pointer crash pattern).
    private func completeAndNavigate() {
        loadAttempt += 1
        onComplete()
    }

    private func retryLoading() {
        loadAttempt += 1  // Invalidates ALL pending DispatchQueue blocks from previous attempt
        viewModel.loadingError = nil
        viewModel.isLoadingProfile = true
        viewModel.isLoadingStats = true
        viewModel.isLoadingDiagnosis = true
        step1State = .waiting
        step2State = .waiting
        step3State = .waiting
        showIcon = false
        rotation = 0
        barProgress = 0
        showError = false  // Triggers re-render → loadingView.onAppear fires with new loadAttempt
    }
}

#Preview {
    BS_LoadingView(viewModel: BudgetSetupViewModel(), onComplete: {})
}
