//
//  PaywallSheet.swift
//  Flamora app
//
//  RevenueCat 内置 Paywall 包装 Sheet
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallSheet: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    private let entitlementId = "Flamora Pro"

    var body: some View {
        // No NavigationStack — it blocks RevenueCatUI preference key propagation
        ZStack(alignment: .topTrailing) {
            PaywallView()
                .onPurchaseCompleted { customerInfo in
                    print("🔍 [PaywallSheet] onPurchaseCompleted triggered")
                    let active = customerInfo.entitlements[entitlementId]?.isActive == true
                    print("🔍 [PaywallSheet] entitlement active from customerInfo: \(active)")
                    Task {
                        await subscriptionManager.checkStatus()
                        if subscriptionManager.isPremium { dismiss() }
                    }
                }
                .onPurchaseFailure { error in
                    print("🔍 [PaywallSheet] onPurchaseFailure triggered: \(error.localizedDescription)")
                    Task {
                        await subscriptionManager.checkStatus()
                        if subscriptionManager.isPremium { dismiss() }
                    }
                }
                .onRestoreCompleted { customerInfo in
                    print("🔍 [PaywallSheet] onRestoreCompleted triggered")
                    let active = customerInfo.entitlements[entitlementId]?.isActive == true
                    print("🔍 [PaywallSheet] entitlement active from customerInfo: \(active)")
                    Task {
                        await subscriptionManager.checkStatus()
                        if subscriptionManager.isPremium { dismiss() }
                    }
                }

            // Close button overlay
            Button {
                print("🔍 [PaywallSheet] Close tapped")
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.sheetCloseGlyph)
                    .foregroundStyle(AppColors.overlayWhiteOnGlass)
                    .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            print("🔍 [PaywallSheet] PaywallSheet appeared")
        }
        .onDisappear {
            // Safety net: always re-check on any dismiss
            print("🔍 [PaywallSheet] PaywallSheet disappeared → checkStatus() fallback")
            Task { await subscriptionManager.checkStatus() }
        }
    }
}
