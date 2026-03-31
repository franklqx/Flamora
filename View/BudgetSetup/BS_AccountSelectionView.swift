//
//  BS_AccountSelectionView.swift
//  Flamora app
//
//  Budget Setup — Step 0: Account Selection
//  Lets user choose which connected accounts to include in budget analysis.
//  Users can also add new bank connections via Plaid Link.
//

import SwiftUI

struct BS_AccountSelectionView: View {
    @Bindable var viewModel: BudgetSetupViewModel
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 60)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)

                    if viewModel.isLoadingAccounts {
                        loadingState
                    } else if let error = viewModel.accountsError {
                        errorState(error)
                    } else if viewModel.plaidAccounts.isEmpty {
                        emptyState
                    } else {
                        accountsList
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    addAccountButton
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)

                    Spacer().frame(height: 140)
                }
            }

            stickyBottomCTA
        }
        .onAppear {
            Task { await viewModel.loadAccounts() }
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await viewModel.refreshAccountsAfterNewConnection() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Select Accounts")
                .font(.h1)
                .foregroundStyle(AppColors.textPrimary)

            Text("Choose which accounts to include in your budget analysis. We recommend selecting your everyday spending accounts.")
                .font(.inlineLabel)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.textPrimary)
            Text("Loading your accounts...")
                .font(.inlineLabel)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Error

    private func errorState(_ error: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.h3)
                .foregroundStyle(AppColors.warning)
            Text(error)
                .font(.inlineLabel)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadAccounts() }
            }
            .font(.bodySmallSemibold)
            .foregroundStyle(AppColors.warning)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "building.columns")
                .font(.h3)
                .foregroundStyle(AppColors.textSecondary)
            Text("No accounts connected yet.\nAdd a bank account to get started.")
                .font(.inlineLabel)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.plaidAccounts) { account in
                accountRow(account)

                if account.id != viewModel.plaidAccounts.last?.id {
                    Rectangle()
                        .fill(AppColors.surfaceBorder)
                        .frame(height: 1)
                }
            }
        }
        .background(AppColors.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.surfaceBorder, lineWidth: 1)
        )
    }

    private func accountRow(_ account: PlaidAccountItem) -> some View {
        let isSelected = viewModel.selectedAccountIds.contains(account.id)
        let isTransactionAccount = ["depository", "credit"].contains(account.type)

        return Button {
            viewModel.toggleAccount(account.id)
        } label: {
            HStack(spacing: AppSpacing.sm + 6) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(isSelected ? AppColors.accentAmber : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(isSelected ? Color.clear : AppColors.surfaceBorder, lineWidth: 1.5)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.footnoteBold)
                            .foregroundStyle(AppColors.textInverse)
                    }
                }

                // Account info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: AppSpacing.xs + 2) {
                        Text(account.name)
                            .font(.figureSecondarySemibold)
                            .foregroundStyle(AppColors.textPrimary)

                        if let mask = account.mask {
                            Text("••\(mask)")
                                .font(.footnoteRegular)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }

                    HStack(spacing: AppSpacing.xs + 2) {
                        Text(account.type)
                            .font(.caption)
                            .foregroundStyle(isTransactionAccount ? AppColors.accentGreen : AppColors.textSecondary)

                        if let institution = account.institutionName {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)
                            Text(institution)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                // Balance
                if let balance = account.balanceCurrent {
                    Text("$\(formattedBalance(balance))")
                        .font(.inlineLabel)
                        .foregroundStyle(AppColors.textTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Account Button

    private var addAccountButton: some View {
        Button {
            guard subscriptionManager.isPremium else {
                subscriptionManager.showPaywall = true
                return
            }
            Task { await plaidManager.startLinkFlow() }
        } label: {
            HStack(spacing: AppSpacing.sm + 2) {
                Image(systemName: "plus.circle.fill")
                    .font(.h4)
                    .foregroundStyle(AppColors.accentAmber)
                Text("Add Another Account")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.accentAmber)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 6)
            .background(AppColors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.accentAmber.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColors.backgroundPrimary.opacity(0), AppColors.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            VStack(spacing: AppSpacing.sm) {
                Button {
                    viewModel.goToStep(.loading)
                } label: {
                    Text("Continue (\(viewModel.selectedTransactionAccountCount) selected)")
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(AppColors.textInverse)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Group {
                                if viewModel.canProceedFromAccountSelection {
                                    LinearGradient(
                                        colors: AppColors.gradientFire,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [AppColors.textMuted, AppColors.textMuted],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .disabled(!viewModel.canProceedFromAccountSelection)

                if !viewModel.canProceedFromAccountSelection && !viewModel.plaidAccounts.isEmpty {
                    Text("Select at least one checking or credit card account")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.backgroundPrimary)
        }
    }

    // MARK: - Helpers

    private func formattedBalance(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview {
    BS_AccountSelectionView(viewModel: BudgetSetupViewModel())
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}
