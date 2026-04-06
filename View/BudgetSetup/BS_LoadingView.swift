//
//  BS_LoadingView.swift
//  Flamora app
//
//  Budget Setup — Step 1: Loading
//  V2: Dual-ring spinner + 3 sequential checklist items (Labor Illusion, 4.2s min)
//

import SwiftUI

struct BS_LoadingView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    var onComplete: () -> Void

    // Each checklist item has 3 states: pending → active → done
    @State private var step1State: ChecklistState = .pending
    @State private var step2State: ChecklistState = .pending
    @State private var step3State: ChecklistState = .pending

    // Spinner rotation
    @State private var outerRotation: Double = 0
    @State private var innerRotation: Double = 0

    // Timeout / error state
    @State private var showError = false
    private let timeoutSeconds: Double = 25
    /// Incremented on every retry. All pending DispatchQueue blocks from earlier attempts
    /// capture the attempt value at scheduling time and bail out if it no longer matches,
    /// preventing stale timers from triggering showError during a newer load cycle.
    @State private var loadAttempt: Int = 0

    private enum ChecklistState {
        case pending, active, done
    }

    var body: some View {
        Group {
            if showError || viewModel.loadingError != nil {
                errorView
            } else {
                loadingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Normal loading view

    private var loadingView: some View {
        VStack(spacing: AppSpacing.xxl) {
            Spacer()
            spinnerSection
            checklistSection
            Spacer()
        }
        .onAppear {
            startSpinnerAnimation()
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
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: AppSpacing.sm) {
                Text("Something went wrong")
                    .font(.h4)
                    .foregroundStyle(AppColors.textPrimary)

                Text(viewModel.loadingError ?? "This is taking longer than expected.\nPlease check your connection and try again.")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Button(action: retryLoading) {
                Text("Try Again")
                    .font(.sheetPrimaryButton)
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.lg)

            Spacer()
        }
    }

    // MARK: - Dual-Ring Spinner

    private var spinnerSection: some View {
        ZStack {
            // Outer ring (gold arc)
            Circle()
                .stroke(AppColors.budgetGold.opacity(0.1), lineWidth: 3)
                .frame(width: 72, height: 72)

            Circle()
                .trim(from: 0, to: 0.35)
                .stroke(AppColors.budgetGold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(outerRotation))

            // Inner ring (pink accent, counter-rotating)
            Circle()
                .stroke(AppColors.budgetPink.opacity(0.1), lineWidth: 2)
                .frame(width: 52, height: 52)

            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(AppColors.budgetPink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(innerRotation))
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            checklistRow(number: 1, label: "Understanding your cashflow", state: step1State)
            checklistRow(number: 2, label: "Refining spending patterns", state: step2State)
            checklistRow(number: 3, label: "Synthesizing AI insights", state: step3State)
        }
        .padding(.horizontal, AppSpacing.xl + AppSpacing.lg)
    }

    @ViewBuilder
    private func checklistRow(number: Int, label: String, state: ChecklistState) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Step indicator
            ZStack {
                switch state {
                case .pending:
                    Circle()
                        .stroke(AppColors.overlayWhiteAt25, lineWidth: 1.5)
                        .frame(width: AppRadius.button, height: AppRadius.button)
                    Text("\(number)")
                        .font(.smallLabel)
                        .foregroundStyle(AppColors.overlayWhiteAt25)

                case .active:
                    Circle()
                        .stroke(AppColors.budgetGold.opacity(0.6), lineWidth: 1.5)
                        .frame(width: AppRadius.button, height: AppRadius.button)
                    // Pulsing gold dot
                    Circle()
                        .fill(AppColors.budgetGold)
                        .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                        .modifier(PulseModifier())

                case .done:
                    Circle()
                        .fill(AppColors.budgetTeal)
                        .frame(width: AppRadius.button, height: AppRadius.button)
                    Image(systemName: "checkmark")
                        .font(.smallLabel)
                        .foregroundStyle(AppColors.textInverse)
                }
            }
            .animation(.easeOut(duration: 0.3), value: state == .done)

            Text(label)
                .font(state == .active ? .bodySmallSemibold : .bodySmall)
                .foregroundStyle(
                    state == .pending ? AppColors.overlayWhiteAt25 :
                    state == .active ? AppColors.overlayWhiteOnGlass :
                    AppColors.overlayWhiteOnPhoto
                )
                .animation(.easeOut(duration: 0.3), value: state == .active)
        }
    }

    // MARK: - Animations

    private func startSpinnerAnimation() {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            outerRotation = 360
        }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            innerRotation = -360
        }
    }

    private func startChecklistAnimation() {
        let attempt = loadAttempt
        // Step 1: 0–1.4s
        withAnimation(.easeOut(duration: 0.3)) { step1State = .active }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard loadAttempt == attempt else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step1State = .done }
            // Step 2: 1.4–2.8s
            withAnimation(.easeOut(duration: 0.3)) { step2State = .active }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard loadAttempt == attempt else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step2State = .done }
            // Step 3: 2.8–4.2s
            withAnimation(.easeOut(duration: 0.3)) { step3State = .active }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            guard loadAttempt == attempt else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step3State = .done }
            // Auto-navigate after all complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard loadAttempt == attempt else { return }
                if viewModel.allLoadingComplete {
                    onComplete()
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
                onComplete()
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

    private func retryLoading() {
        loadAttempt += 1  // Invalidates ALL pending DispatchQueue blocks from previous attempt
        viewModel.loadingError = nil
        viewModel.isLoadingProfile = true
        viewModel.isLoadingStats = true
        viewModel.isLoadingDiagnosis = true
        step1State = .pending
        step2State = .pending
        step3State = .pending
        outerRotation = 0
        innerRotation = 0
        showError = false  // Triggers re-render → loadingView.onAppear fires with new loadAttempt
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

#Preview {
    BS_LoadingView(viewModel: BudgetSetupViewModel(), onComplete: {})
}
