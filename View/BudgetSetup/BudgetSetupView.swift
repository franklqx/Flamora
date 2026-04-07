//
//  BudgetSetupView.swift
//  Flamora app
//
//  Budget Setup — Main container with step navigation
//  V3: goalSetup → accountSelection → loading → accountsReview → diagnosis → choosePath → confirm
//

import SwiftUI

struct BudgetSetupView: View {
    @State private var viewModel = BudgetSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if viewModel.isResumingState {
                BudgetSetupBootstrapView()
            } else {
                switch viewModel.currentStep {
                case .goalSetup:
                    BS_GoalSetupView(viewModel: viewModel)

                case .accountSelection:
                    BS_AccountSelectionView(viewModel: viewModel)

                case .loading:
                    BS_LoadingView(viewModel: viewModel) {
                        viewModel.goToStep(viewModel.postLoadingStep)
                    }

                case .accountsReview:
                    BS_AccountsReviewView(viewModel: viewModel)

                case .diagnosis:
                    BS_DiagnosisView(viewModel: viewModel)

                case .choosePath:
                    BS_ChoosePathView(viewModel: viewModel)

                case .confirm:
                    BS_ConfirmView(viewModel: viewModel, onComplete: {
                        dismiss()
                    })
                }
            }

        }
        .overlay(alignment: .top) {
            BudgetSetupNavigationBar(
                showsBack: viewModel.currentStep != .goalSetup && viewModel.currentStep != .loading,
                onBack: { viewModel.goBack() },
                onClose: { showDiscardConfirmation = true }
            )
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .task {
            await viewModel.resumeFromSetupState()
        }
        .alert("Discard this setup?", isPresented: $showDiscardConfirmation) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your current Build Your Plan session will be closed. Saved budgets stay unchanged.")
        }
    }
}

private struct BudgetSetupNavigationBar: View {
    let showsBack: Bool
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            if showsBack {
                Button(action: onBack) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 56, height: 32)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.overlayWhiteWash)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    BudgetSetupView()
}

private struct BudgetSetupBootstrapView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.textPrimary)
            Text("Loading your setup...")
                .font(.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
    }
}
