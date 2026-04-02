//
//  BudgetSetupView.swift
//  Flamora app
//
//  Budget Setup — Main container with step navigation
//  V2: loading → diagnosis → spendingBreakdown → choosePath → confirm
//

import SwiftUI

struct BudgetSetupView: View {
    @State private var viewModel = BudgetSetupViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardConfirmation = false

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            switch viewModel.currentStep {
            case .accountSelection:
                BS_AccountSelectionView(viewModel: viewModel)

            case .loading:
                BS_LoadingView(viewModel: viewModel) {
                    viewModel.goToStep(.diagnosis)
                }
                
            case .diagnosis:
                BS_DiagnosisView(viewModel: viewModel)

            case .spendingBreakdown:
                BS_SpendingBreakdownView(viewModel: viewModel)

            case .choosePath:
                BS_ChoosePathView(viewModel: viewModel)
                
            case .spendingPlan:
                // Removed from flow — redirect to confirm
                BS_ConfirmView(viewModel: viewModel, onComplete: { dismiss() })

            case .confirm:
                BS_ConfirmView(viewModel: viewModel, onComplete: {
                    dismiss()
                })
            }

            BudgetSetupNavigationBar(
                showsBack: viewModel.currentStep != .accountSelection && viewModel.currentStep != .loading,
                onBack: { viewModel.goBack() },
                onClose: { showDiscardConfirmation = true }
            )
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
