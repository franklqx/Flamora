//
//  PaywallScreen.swift
//  Flamora app
//
//  Native paywall used inside the main app (Settings, Budget Setup).
//  Visual design mirrors OB_PaywallView (the onboarding paywall) so the
//  user only ever sees one paywall design.
//
//  Mount via .fullScreenCover so it can layer over an already-presented
//  sheet (Settings is presented as a .sheet from MainTabView, and SwiftUI
//  blocks .sheet-over-.sheet — fullScreenCover bypasses that limit).
//
//  Purchase / restore logic uses RevenueCat directly. RevenueCatUI is no
//  longer used anywhere — its remote rendering caused the "transparent
//  paywall" flash and is unnecessary for a single-SKU app.
//

import SwiftUI
import RevenueCat

struct PaywallScreen: View {
    /// Called when the user dismisses without purchasing (X button).
    let onClose: () -> Void
    /// Called when a purchase or restore successfully activates the entitlement.
    /// Caller is responsible for any follow-up (e.g. continuing a Plaid flow).
    var onPurchaseSucceeded: (() -> Void)? = nil

    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var isPurchasing = false
    @State private var appear = false

    private let features = [
        "Auto-sync your bank accounts",
        "Transactions categorized for you",
        "Track what you owe, reduce it faster",
        "Never miss a subscription charge",
        "FIRE simulator — see your future, change it",
        "Smart budgets that adapt to your FIRE goal",
        "All your investments in one view",
        "AI tells you exactly what to do next",
        "Beautiful, enriched transaction details",
        "Play with your future: what-if scenarios",
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — X close button (top-right)
                HStack {
                    Color.clear.frame(width: 44, height: 44)
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.sheetCloseGlyph)
                            .foregroundStyle(AppColors.inkFaint)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, AppSpacing.screenPadding)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 40)

                        // MARK: - Header
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "flame")
                                .font(.h1)
                                .foregroundStyle(LinearGradient(
                                    colors: AppColors.gradientShellAccent,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))

                            Text("Flamora Pro")
                                .font(.h1)
                                .foregroundStyle(AppColors.inkPrimary)

                            Text("Your complete toolkit for Financial Independence")
                                .font(.bodyRegular)
                                .foregroundColor(AppColors.inkSoft)
                                .multilineTextAlignment(.center)

                            Text("7-day free trial, cancel anytime")
                                .font(.supportingText)
                                .foregroundColor(AppColors.success)
                        }
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : AppSpacing.md + AppSpacing.xs)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: appear)

                        Spacer().frame(height: AppSpacing.lg)

                        // MARK: - Feature List
                        VStack(spacing: 0) {
                            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                                HStack(spacing: 14) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.bodyRegular)
                                        .foregroundStyle(LinearGradient(
                                            colors: [AppColors.accentBlue, AppColors.accentPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))

                                    Text(feature)
                                        .font(.bodySmall)
                                        .foregroundStyle(AppColors.inkPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)

                                    Spacer()
                                }
                                .padding(.vertical, 8)

                                if index < features.count - 1 {
                                    Divider().overlay(AppColors.inkDivider)
                                }
                            }
                        }
                        .padding(AppSpacing.cardPadding)
                        .background(AppColors.glassCardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(AppColors.inkBorder, lineWidth: 1)
                        )
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : AppSpacing.md + AppSpacing.xs)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)

                        Spacer().frame(height: AppSpacing.lg)

                        // MARK: - Price Card
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "checkmark.circle")
                                .font(.detailTitle)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: AppColors.gradientShellAccent,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yearly")
                                    .font(.h4)
                                    .foregroundStyle(AppColors.inkPrimary)

                                Text("$6.67/mo")
                                    .font(.caption)
                                    .foregroundColor(AppColors.inkSoft)
                            }

                            Spacer()

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("$79.99")
                                    .font(.h3)
                                    .foregroundStyle(AppColors.inkPrimary)
                                Text("/year")
                                    .font(.caption)
                                    .foregroundColor(AppColors.inkSoft)
                            }

                            Text("BEST VALUE")
                                .font(.label)
                                .foregroundStyle(AppColors.ctaWhite)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: AppColors.gradientShellAccent,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(AppColors.glassCardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: AppColors.gradientShellAccent,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : AppSpacing.md + AppSpacing.xs)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)

                        Spacer().frame(height: 200)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                }
            }

            // Sticky CTA
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.clear, AppColors.shellBg2],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 28)

                VStack(spacing: AppSpacing.md) {
                    OB_PrimaryButton(
                        title: isPurchasing ? "Processing..." : "Start My Free Trial",
                        isValid: !isPurchasing,
                        includeContainerPadding: false,
                        action: {
                            Task { await purchase() }
                        }
                    )

                    Button {
                        Task { await restore() }
                    } label: {
                        Text("Already a Pro? Restore")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.inkSoft)
                    }
                    .disabled(isPurchasing)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.bottom, 16)
                .background(AppColors.shellBg2)
                .ignoresSafeArea(edges: .bottom)
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.7), value: appear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
    }

    // MARK: - Purchase

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else { return }

            let targetPackage = offering.availablePackages.first {
                $0.storeProduct.productIdentifier.contains("yearly")
            } ?? offering.availablePackages.first

            guard let package = targetPackage else { return }

            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            guard !userCancelled else { return }

            let active = customerInfo.entitlements["Flamora Pro"]?.isActive == true
            subscriptionManager.isPremium = active
            if active {
                onPurchaseSucceeded?()
                onClose()
            }
        } catch {
            // Stay on paywall — let the user try again or close manually.
        }
    }

    private func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }

        let active = await subscriptionManager.restorePurchases()
        if active {
            onPurchaseSucceeded?()
            onClose()
        }
    }
}

#Preview {
    PaywallScreen(onClose: {}, onPurchaseSucceeded: nil)
        .environment(SubscriptionManager.shared)
}
