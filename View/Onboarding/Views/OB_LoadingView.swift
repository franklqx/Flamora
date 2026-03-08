//
//  OB_LoadingView.swift
//  Flamora app
//
//  Onboarding - Step 14: Animated Loading / Calculation
//

import SwiftUI

struct OB_LoadingView: View {
    let onNext: () -> Void

    private enum StepState { case waiting, loading, done }

    @State private var step1: StepState = .waiting
    @State private var step2: StepState = .waiting
    @State private var step3: StepState = .waiting
    @State private var showIcon = false
    @State private var rotation: Double = 0
    @State private var barProgress: CGFloat = 0

    private let steps = [
        "Analyzing your income structure...",
        "Calculating your savings potential...",
        "Building your personalized roadmap...",
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Sparkle icon with glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColors.gradientStart.opacity(0.15), Color.clear],
                                center: .center, startRadius: 0, endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)
                        .opacity(showIcon ? 1 : 0)

                    Image(systemName: "sparkle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(AppColors.textPrimary)
                        .rotationEffect(.degrees(rotation))
                        .opacity(showIcon ? 1 : 0)
                }

                Spacer().frame(height: 48)

                // Steps
                VStack(alignment: .leading, spacing: 20) {
                    stepRow(text: steps[0], state: step1)
                    stepRow(text: steps[1], state: step2)
                    stepRow(text: steps[2], state: step3)
                }
                .padding(.horizontal, AppSpacing.lg)

                Spacer()

                // Bottom progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.progressTrack)
                            .frame(height: 3)

                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * barProgress, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, 0)
            }
        }
        .onAppear { startSequence() }
    }

    @ViewBuilder
    private func stepRow(text: String, state: StepState) -> some View {
        HStack(spacing: 14) {
            Group {
                switch state {
                case .waiting:
                    Color.clear.frame(width: 20, height: 20)
                case .loading:
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppColors.textSecondary)
                        .frame(width: 20, height: 20)
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 20, height: 20)
                }
            }

            Text(text)
                .font(.bodySmall)
                .foregroundColor(state == .waiting ? .clear : AppColors.textSecondary)
        }
        .animation(.easeOut(duration: 0.3), value: state == .waiting)
    }

    private func startSequence() {
        // 0ms: icon + rotation + progress bar
        withAnimation(.easeIn(duration: 0.3)) { showIcon = true }
        withAnimation(.linear(duration: 3.0)) { rotation = 360 }
        withAnimation(.linear(duration: 3.0)) { barProgress = 1.0 }

        // 300ms: step 1 loading
        after(0.3) { step1 = .loading }
        // 1000ms: step 1 done
        after(1.0) { step1 = .done }
        // 1200ms: step 2 loading
        after(1.2) { step2 = .loading }
        // 1900ms: step 2 done
        after(1.9) { step2 = .done }
        // 2100ms: step 3 loading
        after(2.1) { step3 = .loading }
        // 2800ms: step 3 done
        after(2.8) { step3 = .done }
        // 3200ms: advance
        after(3.2) { onNext() }
    }

    private func after(_ seconds: Double, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
    }
}

#Preview {
    OB_LoadingView(onNext: {})
        .background(AppBackgroundView())
}
