//
//  InvestmentSheetContent.swift
//  Meridian
//

import SwiftUI

struct InvestmentSheetContent: View {
    @Environment(PlaidManager.self) private var plaidManager
    @StateObject private var store = InvestmentDataStore()
    @State private var showTrustBridge = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.cardGap) {
                if store.loadError, plaidManager.hasLinkedBank {
                    ErrorBanner(
                        message: "Couldn't load investment data.",
                        onRetry: { Task { await store.load(plaidManager: plaidManager, force: true) } }
                    )
                    .padding(.horizontal, AppSpacing.screenPadding)
                }

                AssetAllocationCard(
                    allocation: store.displayAllocation,
                    isConnected: plaidManager.hasLinkedBank,
                    holdingsPayload: store.apiHoldingsPayload,
                    cashBankAccounts: store.cashBankAccounts
                )
                .padding(.horizontal, AppSpacing.screenPadding)

                AccountsCard(
                    accounts: store.computedAccounts,
                    isConnected: plaidManager.hasLinkedBank,
                    onAddAccount: openConnectFlow,
                    lastSyncedAt: store.apiNetWorth?.lastSyncedAt
                )
                .padding(.horizontal, AppSpacing.screenPadding)
            }
            .padding(.top, AppSpacing.cardGap)
            .padding(.bottom, AppSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            store.restoreFromCache()
        }
        .task {
            await store.load(plaidManager: plaidManager)
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await store.load(plaidManager: plaidManager, force: true) }
        }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await store.load(plaidManager: plaidManager, force: true) }
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
    }

    private func openConnectFlow() {
        if plaidManager.shouldShowTrustBridge() {
            showTrustBridge = true
        } else {
            Task { await plaidManager.startLinkFlow() }
        }
    }
}
