//
//  BudgetSetupView.swift
//  Meridian
//
//  Budget Setup — Main container with step navigation
//  V3 (Phase E): connect → loading → reality → target → plan → split → confirm
//  See `~/.claude/plans/budget-plan-budget-plan-gentle-blossom.md` § "最终流程"
//

import SwiftUI

struct BudgetSetupView: View {
    let entryMode: PlaidManager.BudgetSetupEntryMode
    @State private var viewModel = BudgetSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            if viewModel.isResumingState {
                BudgetSetupBootstrapView()
            } else {
                switch viewModel.currentStep {
                case .connect:
                    BS_AccountSelectionView(viewModel: viewModel)

                case .loading:
                    BS_LoadingView(viewModel: viewModel) {
                        viewModel.goToStep(viewModel.postLoadingStep)
                    }

                case .reality:
                    BS_DiagnosisView(viewModel: viewModel)

                case .target:
                    BS_TargetView(viewModel: viewModel)

                case .plan:
                    BS_ChoosePathView(viewModel: viewModel)

                case .planSet:
                    BS_PlanSetView(viewModel: viewModel)

                case .split:
                    BS_SplitBudgetView(viewModel: viewModel)

                case .confirm:
                    BS_ConfirmView(viewModel: viewModel, onComplete: {
                        dismiss()
                    })
                }
            }

        }
        .overlay(alignment: .top) {
            BudgetSetupNavigationBar(
                showsBack: showsBack(for: viewModel.currentStep),
                showsClose: showsClose(for: viewModel.currentStep),
                onBack: { viewModel.goBack() },
                onClose: { showDiscardConfirmation = true }
            )
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .task {
            switch entryMode {
            case .fresh:
                await viewModel.beginFreshSetup()
            case .resume:
                await viewModel.resumeFromSetupState()
            case .editPlan:
                await viewModel.beginQuickEditPlan()
            case .editCategories:
                await viewModel.beginQuickEditCategories()
            }
        }
        .alert("Discard this setup?", isPresented: $showDiscardConfirmation) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your current Build Your Plan session will be closed. Saved budgets stay unchanged.")
        }
    }

    /// Back is a navigation tool for revisiting the previous step. Hidden on:
    /// - `.connect`: first page, dismiss via X instead
    /// - `.loading`: in-progress, can't cancel
    /// - `.planSet`: celebration page, forward-only by design
    private func showsBack(for step: BudgetSetupViewModel.Step) -> Bool {
        switch step {
        case .connect, .loading, .planSet: return false
        default: return true
        }
    }

    /// X (discard) is the escape hatch from the entire setup. Only shown on the
    /// first page; once the user is committed to the flow, the only way out is
    /// to either complete or back out step-by-step.
    private func showsClose(for step: BudgetSetupViewModel.Step) -> Bool {
        step == .connect
    }
}

private struct BudgetSetupNavigationBar: View {
    let showsBack: Bool
    let showsClose: Bool
    let onBack: () -> Void
    let onClose: () -> Void

    /// 28pt circular icon-only buttons matches existing 2nd-level page chrome
    /// (e.g. `BudgetEditChooserSheet`, `SavingsTargetDetailView2` year picker).
    private static let buttonSize: CGFloat = 28

    var body: some View {
        HStack {
            if showsBack {
                navButton(icon: "chevron.left", action: onBack)
                    .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: Self.buttonSize, height: Self.buttonSize)
            }

            Spacer()

            if showsClose {
                navButton(icon: "xmark", action: onClose)
                    .accessibilityLabel("Discard setup")
            } else {
                Color.clear.frame(width: Self.buttonSize, height: Self.buttonSize)
            }
        }
    }

    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.footnoteSemibold)
                .foregroundStyle(AppColors.inkPrimary)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .background(AppColors.shellBg2)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BudgetSetupView(entryMode: .fresh)
}

private struct BudgetSetupBootstrapView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.inkPrimary)
            Text("Loading your setup...")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

// MARK: - Glass Card Style (shared across BS_ pages, matches Cashflow BudgetCard)

struct BSGlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.glassCard
    var borderStyle: AnyShapeStyle = AnyShapeStyle(AppColors.glassCardBorder)
    var borderWidth: CGFloat = 1
    var includeShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderStyle, lineWidth: borderWidth)
            )
            .shadow(
                color: includeShadow ? AppColors.glassCardShadow : .clear,
                radius: AppSpacing.md,
                y: AppSpacing.xs
            )
    }
}

extension View {
    /// Standard BS card visual with a solid color border.
    func bsGlassCard(
        cornerRadius: CGFloat = AppRadius.glassCard,
        borderColor: Color = AppColors.glassCardBorder,
        borderWidth: CGFloat = 1,
        includeShadow: Bool = true
    ) -> some View {
        modifier(BSGlassCardStyle(
            cornerRadius: cornerRadius,
            borderStyle: AnyShapeStyle(borderColor),
            borderWidth: borderWidth,
            includeShadow: includeShadow
        ))
    }

    /// BS card visual that accepts any `ShapeStyle` for the border —
    /// e.g. a `LinearGradient` for a selected/highlighted state.
    func bsGlassCard<S: ShapeStyle>(
        cornerRadius: CGFloat = AppRadius.glassCard,
        borderStyle: S,
        borderWidth: CGFloat = 1,
        includeShadow: Bool = true
    ) -> some View {
        modifier(BSGlassCardStyle(
            cornerRadius: cornerRadius,
            borderStyle: AnyShapeStyle(borderStyle),
            borderWidth: borderWidth,
            includeShadow: includeShadow
        ))
    }
}
