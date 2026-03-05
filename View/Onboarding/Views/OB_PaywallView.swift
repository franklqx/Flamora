//
//  OB_PaywallView.swift
//  Flamora app
//
//  Onboarding - Step 17: Paywall
//  RevenueCat purchase logic
//

import SwiftUI
import RevenueCat

struct OB_PaywallView: View {
    let data: OnboardingData
    let onBack: () -> Void
    let onComplete: () -> Void

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
        VStack(spacing: 0) {
            // Header
            HStack {
                OB_BackButton(action: onBack)
                Spacer()
                // Skip button
                Button {
                    finishOnboarding()
                } label: {
                    Text("Skip")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // MARK: - Header
                    VStack(spacing: AppSpacing.sm) {
                        Text("🔥")
                            .font(.system(size: 32))

                        Text("Flamora Pro")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Your complete toolkit for Financial Independence")
                            .font(.bodyRegular)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)

                        Text("7-day free trial, cancel anytime")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.success)
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appear)

                    Spacer().frame(height: AppSpacing.lg)

                    // MARK: - Feature List
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.success)

                                Text(feature)
                                    .font(.bodySmall)
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 8)

                            if index < features.count - 1 {
                                Divider().overlay(AppColors.borderDefault)
                            }
                        }
                    }
                    .padding(AppSpacing.cardPadding)
                    .background(AppColors.backgroundCard)
                    .cornerRadius(16)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)

                    Spacer().frame(height: AppSpacing.lg)

                    // MARK: - Price Card
                    Button {
                        // Already selected — noop
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: AppColors.gradientFire,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yearly")
                                    .font(.h4)
                                    .foregroundColor(AppColors.textPrimary)

                                Text("$6.67/mo")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("$79.99")
                                    .font(.h3)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("/year")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: AppColors.gradientFire,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(6)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(AppColors.backgroundCard)
                        .cornerRadius(AppRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(
                                    LinearGradient(
                                        colors: AppColors.gradientFire,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)

                    Spacer().frame(height: AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // MARK: - Bottom CTA
            VStack(spacing: AppSpacing.md) {
                OB_PrimaryButton(
                    title: isPurchasing ? "Processing..." : "Start My Free Trial",
                    disabled: isPurchasing
                ) {
                    data.selectedPlan = "yearly"
                    Task { await purchase() }
                }

                Button {
                    Task {
                        isPurchasing = true
                        _ = await subscriptionManager.restorePurchases()
                        isPurchasing = false
                        if subscriptionManager.isPremium {
                            finishOnboarding()
                        }
                    }
                } label: {
                    Text("Already a Pro? Restore")
                        .font(.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                .disabled(isPurchasing)
            }
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.7), value: appear)
            .padding(.bottom, AppSpacing.lg)
        }
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
            guard let offering = offerings.current else {
                finishOnboarding()
                return
            }

            let targetPackage = offering.availablePackages.first {
                $0.storeProduct.productIdentifier.contains("yearly")
            } ?? offering.availablePackages.first

            guard let package = targetPackage else {
                finishOnboarding()
                return
            }

            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            if !userCancelled {
                subscriptionManager.isPremium = customerInfo.entitlements["Flamora Pro"]?.isActive == true
            }
        } catch {
            print("Purchase error: \(error)")
        }

        finishOnboarding()
    }

    // MARK: - Finish

    private func finishOnboarding() {
        Task {
            // Save profile to Supabase (best effort)
            do {
                _ = try await APIService.shared.createUserProfile(data: data)
            } catch {
                print("Profile save error: \(error)")
            }

            await MainActor.run {
                onComplete()
            }
        }
    }
}

#Preview {
    OB_PaywallView(data: OnboardingData(), onBack: {}, onComplete: {})
        .environment(SubscriptionManager.shared)
        .background(AppBackgroundView())
}
