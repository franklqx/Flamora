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
        }
    }
}

#Preview {
    BudgetSetupView()
}
