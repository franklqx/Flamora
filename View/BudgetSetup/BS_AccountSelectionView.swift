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
    @State private var showTrustBridge = false
    @State private var showZeroPortfolioAssumptionAlert = false

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [AppColors.shellBg1, AppColors.shellBg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: AppSpacing.navBarTopSpace)

                    headerSection
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)

                    if viewModel.isManualMode {
                        manualEntrySection
                            .padding(.horizontal, AppSpacing.lg)
                    } else if viewModel.isLoadingAccounts {
                        loadingState
                    } else if let error = viewModel.accountsError {
                        errorState(error)
                    } else if !plaidManager.hasLinkedBank {
                        VStack(spacing: AppSpacing.md) {
                            connectAccountsCTA
                            manualAlternateCard
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    } else if viewModel.plaidAccounts.isEmpty {
                        emptyState
                    } else {
                        accountsList
                            .padding(.horizontal, AppSpacing.lg)

                        addAccountButton
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.md)

                        manualAlternateCard
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.md)
                    }

                    Spacer().frame(height: AppSpacing.tabBarReserve + AppSpacing.xxl + AppSpacing.lg)
                }
            }

            stickyBottomCTA
        }
        .alert("Bank Connection Failed", isPresented: Binding(
            get: { plaidManager.linkError != nil },
            set: { if !$0 { plaidManager.linkError = nil } }
        )) {
            Button("Try Again") { Task { await plaidManager.startLinkFlow() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(plaidManager.linkError ?? "")
        }
        .alert("No investment account added", isPresented: $showZeroPortfolioAssumptionAlert) {
            Button("Add Investment Account") {
                startPlaidLinkFlow()
            }
            Button("Continue with $0") {
                Task {
                    if await viewModel.chooseZeroStartingPortfolio() {
                        await viewModel.continueFromConnect()
                    }
                }
            }
        } message: {
            Text("We'll start your FIRE progress from $0 for now. You can add investment accounts later and your progress will update automatically.")
        }
        .onAppear {
            Task { await viewModel.loadAccountSelectionData() }
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await viewModel.refreshAccountsAfterNewConnection() }
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
        .sheet(isPresented: Binding(
            get: { subscriptionManager.showPaywall },
            set: { subscriptionManager.showPaywall = $0 }
        )) {
            PaywallSheet()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(viewModel.isManualMode ? "Add Your Numbers" : plaidManager.hasLinkedBank ? "Select Accounts" : "Connect Your Bank")
                .font(.h1)
                .foregroundStyle(AppColors.inkPrimary)

            if viewModel.isManualMode {
                Text("No bank link is required. Add four simple numbers and we'll build the same budget plan flow from there.")
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(3)
            } else if plaidManager.hasLinkedBank {
                Text("Add your checking, savings, credit, and investment accounts so your budget and FIRE progress start from the right numbers.")
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(3)
            } else {
                Text("Link your bank to build a personalized budget based on real spending data.")
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.inkPrimary)
            Text("Loading your accounts...")
                .font(.inlineLabel)
                .foregroundStyle(AppColors.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.navBarTopSpace)
    }

    // MARK: - Error

    private func errorState(_ error: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.h3)
                .foregroundStyle(AppColors.warning)
            Text(error)
                .font(.inlineLabel)
                .foregroundStyle(AppColors.inkSoft)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadAccounts() }
            }
            .font(.bodySmallSemibold)
            .foregroundStyle(AppColors.warning)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.navBarTopSpace)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Connect CTA (no bank linked)

    private var connectAccountsCTA: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.columns.fill")
                    .font(.h2)
                    .foregroundStyle(AppColors.inkPrimary)
                Text("Link your first account")
                    .font(.h4)
                    .foregroundStyle(AppColors.inkPrimary)
                    .multilineTextAlignment(.center)
                Text("We'll analyze your last 6 months of transactions to build a personalized budget.")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                guard subscriptionManager.isPremium else {
                    subscriptionManager.showPaywall = true
                    return
                }
                if plaidManager.shouldShowTrustBridge() {
                    showTrustBridge = true
                } else {
                    Task { await plaidManager.startLinkFlow() }
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.h4)
                    Text("Connect Bank Account")
                        .font(.sheetPrimaryButton)
                }
                .foregroundStyle(AppColors.ctaWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppColors.inkPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, AppSpacing.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "building.columns")
                .font(.h3)
                .foregroundStyle(AppColors.inkSoft)
            Text("No accounts connected yet.\nAdd a bank account to get started.")
                .font(.inlineLabel)
                .foregroundStyle(AppColors.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.navBarTopSpace)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.plaidAccounts) { account in
                accountRow(account)

                if account.id != viewModel.plaidAccounts.last?.id {
                    Divider()
                        .background(AppColors.inkDivider)
                }
            }
        }
        .bsGlassCard()
    }

    private func accountRow(_ account: PlaidAccountItem) -> some View {
        let isSelected = viewModel.selectedAccountIds.contains(account.id)
        let isTransactionAccount = ["depository", "credit"].contains(account.type)

        let rowContent = HStack(spacing: AppSpacing.rowItem) {
            accountCheckbox(isSelected: isSelected, isEnabled: isTransactionAccount)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.sm) {
                    Text(account.name)
                        .font(.figureSecondarySemibold)
                        .foregroundStyle(AppColors.inkPrimary)

                    if let mask = account.mask {
                        Text("••\(mask)")
                            .font(.footnoteRegular)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                }

                HStack(spacing: AppSpacing.sm) {
                    Text(account.type)
                        .font(.caption)
                        .foregroundStyle(isTransactionAccount ? AppColors.accentGreen : AppColors.inkSoft)

                    if let institution = account.institutionName {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(AppColors.inkFaint)
                        Text(institution)
                            .font(.caption)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                }
            }

            Spacer()

            if let balance = account.balanceCurrent {
                Text("$\(formattedBalance(balance))")
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.inkFaint)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.rowItem)

        if isTransactionAccount {
            return AnyView(
                Button {
                    viewModel.toggleAccount(account.id)
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            )
        } else {
            return AnyView(rowContent)
        }
    }

    private func accountCheckbox(isSelected: Bool, isEnabled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(isSelected ? AppColors.inkPrimary : Color.clear)
                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(
                            isEnabled
                                ? (isSelected ? Color.clear : AppColors.inkBorder)
                                : AppColors.inkBorder.opacity(0.55),
                            lineWidth: 1.5
                        )
                )

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.footnoteBold)
                    .foregroundStyle(AppColors.ctaWhite)
            } else if !isEnabled {
                Image(systemName: "minus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.inkFaint)
            }
        }
    }

    // MARK: - Add Account Button

    private var addAccountButton: some View {
        Button {
            startPlaidLinkFlow()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.h4)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(viewModel.hasInvestmentAccount ? "Add Another Account" : "Add Investment Account")
                    .font(.figureSecondarySemibold)
                    .foregroundStyle(AppColors.inkPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.rowItem)
            .bsGlassCard(borderColor: AppColors.inkPrimary.opacity(0.2))
        }
        .buttonStyle(.plain)
    }

    private var manualAlternateCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Prefer to start manually?")
                .font(.bodySemibold)
                .foregroundStyle(AppColors.inkPrimary)
            Text("You can enter income, spending, and a starting portfolio estimate now, then connect accounts later if you want a richer picture.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.inkSoft)
                .lineSpacing(3)

            Button {
                viewModel.enterManualMode()
            } label: {
                Text("Enter Numbers Instead")
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.xxl)
                    .background(AppColors.glassBlockBg)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .stroke(AppColors.inkPrimary.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding)
        .bsGlassCard()
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Manual Snapshot")
                        .font(.h4)
                        .foregroundStyle(AppColors.inkPrimary)
                    Text("These numbers create your starting reality. You can refine the details later.")
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.inkSoft)
                        .lineSpacing(3)
                }
                Spacer()
                if plaidManager.hasLinkedBank {
                    Button("Use linked accounts") {
                        viewModel.exitManualMode()
                    }
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary)
                }
            }

            manualAgeField
            manualField(
                title: "Monthly income",
                subtitle: "Take-home pay in a typical month",
                value: $viewModel.manualIncome
            )
            manualField(
                title: "Essential spending",
                subtitle: "Rent, groceries, bills, transport, healthcare",
                value: $viewModel.manualEssentialSpending
            )
            manualField(
                title: "Other spending",
                subtitle: "Eating out, shopping, travel, subscriptions",
                value: $viewModel.manualOtherSpending
            )
            manualField(
                title: "Starting portfolio",
                subtitle: "Brokerage, retirement, and investment balances",
                value: $viewModel.manualNetWorth
            )

            if !viewModel.canProceedFromManualInput {
                Text(manualValidationHint)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkSoft)
            }
        }
        .padding(AppSpacing.cardPadding)
        .bsGlassCard()
    }

    /// Manual-mode age input. Pre-filled from `user_profiles.age` when
    /// onboarding already supplied one (silent for the common case);
    /// blank for fresh-signup users so they're prompted before the CTA
    /// will activate. Without this, downstream `generate-plans` would
    /// silently 400 with `MISSING_CURRENT_AGE`.
    private var manualAgeField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Current age")
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.inkPrimary)
            Text("Used to project your FIRE timeline")
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)

            HStack(spacing: AppSpacing.sm) {
                TextField(
                    "0",
                    value: $viewModel.manualAge,
                    formatter: Self.ageFormatter
                )
                .font(.bodySmall)
                .foregroundStyle(AppColors.inkPrimary)
                .keyboardType(.numberPad)
                Text("yrs")
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkFaint)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: AppSpacing.xxl)
            .background(AppColors.shellBg2.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            )
        }
    }

    private static let ageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.minimum = 0
        formatter.maximum = 120
        return formatter
    }()

    /// Tailored hint that points at whichever required field is missing.
    /// Keeps the user from having to guess why the CTA is disabled.
    private var manualValidationHint: String {
        if viewModel.effectiveManualAge <= 0 {
            return "Add your age so we can project your FIRE timeline."
        }
        if viewModel.manualIncome <= 0 {
            return "Add your monthly income so we can build a realistic plan."
        }
        return "Add at least your essential or other spending so we can build a realistic plan."
    }

    private func manualField(title: String, subtitle: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.bodySmallSemibold)
                .foregroundStyle(AppColors.inkPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)

            HStack(spacing: AppSpacing.sm) {
                Text("$")
                    .font(.bodySemibold)
                    .foregroundStyle(AppColors.inkFaint)
                TextField("0", value: value, formatter: Self.currencyFormatter)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.inkPrimary)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: AppSpacing.xxl)
            .background(AppColors.shellBg2.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.inkBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Sticky CTA

    private var stickyBottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: AppSpacing.lg)

            VStack(spacing: AppSpacing.sm) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if shouldPromptForZeroPortfolio {
                        showZeroPortfolioAssumptionAlert = true
                    } else {
                        Task { await viewModel.continueFromConnect() }
                    }
                } label: {
                    Text(primaryButtonTitle)
                        .font(.sheetPrimaryButton)
                        .foregroundStyle(AppColors.ctaWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            canContinue
                                ? AppColors.inkPrimary
                                : AppColors.inkFaint
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .disabled(!canContinue)

                if viewModel.isManualMode && !viewModel.canProceedFromManualInput {
                    Text(manualValidationHint)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                } else if plaidManager.hasLinkedBank && !viewModel.canProceedFromAccountSelection && !viewModel.plaidAccounts.isEmpty {
                    Text(accountSelectionValidationHint)
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                } else if !plaidManager.hasLinkedBank && !viewModel.isManualMode {
                    Text("Connect at least one account or switch to manual entry")
                        .font(.caption)
                        .foregroundStyle(AppColors.inkSoft)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .background(AppColors.shellBg2)
        }
    }

    private var canContinue: Bool {
        let base = viewModel.isManualMode ? viewModel.canProceedFromManualInput : viewModel.canProceedFromAccountSelection
        return base && !viewModel.isSavingStartingPortfolioDecision
    }

    private var accountSelectionValidationHint: String {
        if viewModel.selectedTransactionAccountCount <= 0 {
            return "Select at least one checking or credit card account"
        }
        return "Review your account selection"
    }

    private var shouldPromptForZeroPortfolio: Bool {
        !viewModel.isManualMode
            && viewModel.selectedTransactionAccountCount > 0
            && !viewModel.hasStartingPortfolioDecision
    }

    private var primaryButtonTitle: String {
        if viewModel.isManualMode {
            return "Continue with manual numbers"
        }
        if viewModel.selectedTransactionAccountCount > 0 {
            return "Continue (\(viewModel.selectedTransactionAccountCount) selected)"
        }
        return "Continue"
    }

    // MARK: - Helpers

    private func startPlaidLinkFlow() {
        guard subscriptionManager.isPremium else {
            subscriptionManager.showPaywall = true
            return
        }
        if plaidManager.shouldShowTrustBridge() {
            showTrustBridge = true
        } else {
            Task { await plaidManager.startLinkFlow() }
        }
    }

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
