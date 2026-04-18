//
//  BS_AccountsReviewView.swift
//  Flamora app
//
//  Budget Setup — Step 3: Connected Accounts Review
//  Shows linked accounts grouped by type.
//  On Continue: marks accounts_reviewed, then either goes straight to diagnosis
//  or enters loading first if stats haven't been loaded yet.
//

import SwiftUI

struct BS_AccountsReviewView: View {
    @Bindable var viewModel: BudgetSetupViewModel

    @State private var showContent = false
    @State private var isProceeding = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.xxl + AppSpacing.sm + AppSpacing.xs)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)

                    if viewModel.isLoadingAccounts {
                        loadingSection
                    } else if viewModel.plaidAccounts.isEmpty {
                        emptySection
                            .padding(.horizontal, AppSpacing.lg)
                    } else {
                        accountGroups
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.md + AppSpacing.md + AppSpacing.sm)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : AppSpacing.md)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { showContent = true }
            }

            stickyBottomCTA
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your Connected Accounts")
                .font(.cardFigurePrimary)
                .foregroundStyle(AppColors.inkPrimary)

            Text("These are the accounts we'll analyze for your financial snapshot. Make sure the right ones are included.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.inkPrimary)
            Text("Loading your accounts...")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xxl)
    }

    // MARK: - Empty

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("No accounts found")
                .font(.bodySemibold)
                .foregroundStyle(AppColors.inkPrimary)
            Text("Go back and connect at least one checking or credit account to continue.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    // MARK: - Account Groups

    private var accountGroups: some View {
        let grouped = Dictionary(grouping: viewModel.plaidAccounts, by: { normalizedType($0.type) })
        let order = ["Checking & Savings", "Credit Cards", "Investment", "Other"]

        return VStack(spacing: AppSpacing.md) {
            ForEach(order, id: \.self) { groupName in
                if let accounts = grouped[groupName], !accounts.isEmpty {
                    accountGroupCard(title: groupName, accounts: accounts)
                }
            }
        }
    }

    @ViewBuilder
    private func accountGroupCard(title: String, accounts: [PlaidAccountItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.footnoteSemibold)
                .foregroundStyle(AppColors.inkFaint)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                if index > 0 {
                    Divider()
                        .background(AppColors.inkBorder)
                        .padding(.horizontal, AppSpacing.md)
                }
                accountRow(account: account)
            }
            .padding(.bottom, AppSpacing.sm)
        }
        .background(AppColors.glassCardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.inkBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func accountRow(account: PlaidAccountItem) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Type icon
            ZStack {
                Circle()
                    .fill(AppColors.glassCardBg)
                    .frame(width: AppSpacing.xl, height: AppSpacing.xl)
                Image(systemName: iconName(for: account.type))
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkSoft)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)
                if let mask = account.mask {
                    Text("••••\(mask)")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkFaint)
                }
            }

            Spacer()

            if let balance = account.balanceCurrent {
                Text("$\(formattedInt(balance))")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, AppColors.shellBg2],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: AppRadius.button)

            Button {
                isProceeding = true
                Task {
                    await viewModel.continueFromAccountsReview()
                    // Do NOT reset isProceeding here: continueFromAccountsReview calls goToStep,
                    // which navigates away and deallocates this view. Writing to @State after
                    // deallocation causes "freed pointer" crash (same pattern as TransactionDetailSheet).
                }
            } label: {
                Group {
                    if isProceeding {
                        ProgressView().tint(AppColors.ctaWhite)
                    } else {
                        Text("Looks Good, Continue")
                            .font(.sheetPrimaryButton)
                    }
                }
                .foregroundStyle(AppColors.ctaWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    AppColors.inkPrimary
                        .opacity(!viewModel.plaidAccounts.isEmpty && !isProceeding ? 1 : 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .disabled(viewModel.plaidAccounts.isEmpty || isProceeding)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    // MARK: - Helpers

    private func normalizedType(_ raw: String) -> String {
        switch raw.lowercased() {
        case "depository": return "Checking & Savings"
        case "credit":     return "Credit Cards"
        case "investment", "brokerage": return "Investment"
        default:           return "Other"
        }
    }

    private func iconName(for type: String) -> String {
        switch type.lowercased() {
        case "depository": return "building.columns"
        case "credit":     return "creditcard"
        case "investment", "brokerage": return "chart.line.uptrend.xyaxis"
        default:           return "banknote"
        }
    }

    private func formattedInt(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview {
    BS_AccountsReviewView(viewModel: BudgetSetupViewModel())
}
