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

    private enum ChecklistState {
        case pending, active, done
    }

    var body: some View {
        VStack(spacing: 48) {
            Spacer()

            // Dual-ring spinner
            spinnerSection

            // Checklist items
            checklistSection

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0A0A0C").ignoresSafeArea())
        .onAppear {
            startSpinnerAnimation()
            startChecklistAnimation()
            Task { await viewModel.loadInitialData() }
        }
    }

    // MARK: - Dual-Ring Spinner

    private var spinnerSection: some View {
        ZStack {
            // Outer ring (gold arc)
            Circle()
                .stroke(Color(hex: "F5C842").opacity(0.1), lineWidth: 3)
                .frame(width: 72, height: 72)

            Circle()
                .trim(from: 0, to: 0.35)
                .stroke(Color(hex: "F5C842"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(outerRotation))

            // Inner ring (pink accent, counter-rotating)
            Circle()
                .stroke(Color(hex: "E88BC4").opacity(0.1), lineWidth: 2)
                .frame(width: 52, height: 52)

            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Color(hex: "E88BC4"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(innerRotation))
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            checklistRow(number: 1, label: "Understanding your cashflow", state: step1State)
            checklistRow(number: 2, label: "Refining spending patterns", state: step2State)
            checklistRow(number: 3, label: "Synthesizing AI insights", state: step3State)
        }
        .padding(.horizontal, 50)
    }

    @ViewBuilder
    private func checklistRow(number: Int, label: String, state: ChecklistState) -> some View {
        HStack(spacing: 14) {
            // Step indicator
            ZStack {
                switch state {
                case .pending:
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                    Text("\(number)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.2))

                case .active:
                    Circle()
                        .stroke(Color(hex: "F5C842").opacity(0.6), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                    // Pulsing gold dot
                    Circle()
                        .fill(Color(hex: "F5C842"))
                        .frame(width: 8, height: 8)
                        .modifier(PulseModifier())

                case .done:
                    Circle()
                        .fill(Color(hex: "5DDEC0"))
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .animation(.easeOut(duration: 0.3), value: state == .done)

            Text(label)
                .font(.system(size: 14, weight: state == .active ? .semibold : .regular))
                .foregroundStyle(
                    state == .pending ? .white.opacity(0.25) :
                    state == .active ? .white.opacity(0.9) :
                    .white.opacity(0.5)
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
        // Step 1: 0–1.4s
        withAnimation(.easeOut(duration: 0.3)) { step1State = .active }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step1State = .done }
            // Step 2: 1.4–2.8s
            withAnimation(.easeOut(duration: 0.3)) { step2State = .active }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step2State = .done }
            // Step 3: 2.8–4.2s
            withAnimation(.easeOut(duration: 0.3)) { step3State = .active }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step3State = .done }
            // Auto-navigate after all complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if viewModel.allLoadingComplete {
                    onComplete()
                } else {
                    pollForCompletion()
                }
            }
        }
    }

    private func pollForCompletion() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if viewModel.allLoadingComplete {
                onComplete()
            } else if viewModel.loadingError != nil {
                onComplete()
            } else {
                pollForCompletion()
            }
        }
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
