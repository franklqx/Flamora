//
//  BudgetSetupView.swift
//  Flamora app
//
//  Budget Setup — Main container with step navigation
//  Presented as full-screen cover after Plaid connection succeeds
//

import SwiftUI

struct BudgetSetupView: View {
    @State private var viewModel = BudgetSetupViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.currentStep {
            case .loading:
                // TODO: Step 1 — Loading animation (placeholder)
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color(hex: "F5D76E"))
                        .scaleEffect(1.5)
                    Text("Analyzing your finances...")
                        .font(.bodySmall)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .onAppear {
                    Task {
                        await viewModel.loadInitialData()
                        // Wait for loading animation
                        try? await Task.sleep(for: .seconds(4.2))
                        if viewModel.allLoadingComplete {
                            viewModel.goToStep(.diagnosis)
                        }
                    }
                }

            case .diagnosis:
                // TODO: Step 2 — Financial Diagnosis (placeholder)
                VStack(spacing: 20) {
                    Text("Financial Diagnosis")
                        .font(.detailTitle)
                        .foregroundStyle(.white)
                    Text("Step 2 — Coming soon")
                        .foregroundStyle(.white.opacity(0.5))

                    // Temporary: show key metrics if loaded
                    if let diagnosis = viewModel.diagnosis {
                        VStack(spacing: 8) {
                            metricRow("Avg Income", "$\(Int(diagnosis.metrics.avgIncome))")
                            metricRow("Avg Spending", "$\(Int(diagnosis.metrics.avgSpending))")
                            metricRow("Savings Rate", "\(Int(diagnosis.metrics.savingsRate))%")
                        }
                        .padding(16)
                        .background(Color(hex: "1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 26)
                    }

                    Button("Set Your FIRE Goal →") {
                        viewModel.goToStep(.fireGoal)
                    }
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "F5D76E"), Color(hex: "E8829B"), Color(hex: "B4A0E5")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 100))
                    .padding(.horizontal, 26)
                }

            case .fireGoal:
                BS_FireGoalView(viewModel: viewModel)

            case .setBudget:
                BS_SetBudgetView(viewModel: viewModel)

            case .confirm:
                BS_ConfirmView(viewModel: viewModel, onComplete: {
                    dismiss()
                })
            }
        }
    }

    @ViewBuilder
    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnoteRegular)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.footnoteBold)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    BudgetSetupView()
}
