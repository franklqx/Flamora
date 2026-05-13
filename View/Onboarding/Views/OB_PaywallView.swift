//
//  OB_PaywallView.swift
//  Meridian
//
//  Onboarding - Step 17: Paywall
//  RevenueCat purchase logic
//

import SwiftUI
import RevenueCat
import UIKit

struct OB_PaywallView: View {
    private struct RestoreAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private struct FeatureItem: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    private struct PlanOption: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let priceLine: String
        let badge: String?
        let package: Package
    }

    let data: OnboardingData
    let onBack: () -> Void
    let onComplete: () -> Void

    @Environment(SubscriptionManager.self) private var subscriptionManager
    
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var appear = false
    @State private var restoreAlert: RestoreAlert?
    @State private var planOptions: [PlanOption] = []
    @State private var selectedPlanId: String?

    private let features = [
        FeatureItem(
            title: "Live Freedom Countdown",
            detail: "See exactly how long remains until you reach financial independence."
        ),
        FeatureItem(
            title: "Automatic Spending Clarity",
            detail: "Transactions are categorized into Needs and Wants for you."
        ),
        FeatureItem(
            title: "Goal-Driven Budgeting",
            detail: "Get a dynamic spending plan tailored to your financial goal."
        ),
        FeatureItem(
            title: "Smart Savings Tracking",
            detail: "Track your savings rate live and see how each dollar moves your Freedom Date closer."
        ),
        FeatureItem(
            title: "The Unified View",
            detail: "See your investments, savings, and daily spending in one place."
        ),
    ]

    var body: some View {
        ZStack {
            paywallBackground

            VStack(spacing: 0) {
                // Header
                HStack {
                    Color.clear.frame(width: 44, height: 44)
                    Spacer()
                    Button {
                        finishOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.bodySmall)
                            .foregroundColor(AppColors.heroTextFaint)
                    }
                }
                .padding(.horizontal, AppSpacing.screenPadding)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)

                    // MARK: - Header
                    VStack(spacing: AppSpacing.sm) {
                        Text("Meridian Pro")
                            .font(.h1)
                            .foregroundStyle(AppColors.heroTextPrimary)

                        Text("Live track your journey to financial freedom.")
                            .font(.bodyRegular)
                            .foregroundColor(AppColors.heroTextSoft)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : AppSpacing.md + AppSpacing.xs)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appear)

                    Spacer().frame(height: AppSpacing.lg)

                    // MARK: - Feature List
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "checkmark.circle")
                                    .font(.bodyRegular)
                                    .foregroundStyle(LinearGradient(
                                        colors: [AppColors.accentBlue, AppColors.accentPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(feature.title)
                                        .font(.bodySmall)
                                        .foregroundStyle(AppColors.inkPrimary)

                                    Text(feature.detail)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 10)

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

                    // MARK: - Plan Cards
                    if planOptions.isEmpty {
                        ProgressView("Loading plans...")
                            .font(.bodySmall)
                            .foregroundStyle(AppColors.inkSoft)
                            .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : AppSpacing.md + AppSpacing.xs)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)
                    } else {
                        VStack(spacing: AppSpacing.sm) {
                            ForEach(planOptions) { option in
                                planCard(option)
                            }

                            Text("7-day free trial, cancel anytime")
                                .font(.supportingText)
                                .foregroundStyle(AppColors.heroTextHint)
                                .padding(.top, 2)
                        }
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : AppSpacing.md + AppSpacing.xs)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: appear)
                    }

                    Spacer().frame(height: AppSpacing.lg)

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
                            Task {
                                isPurchasing = true
                                isRestoring = true
                                let result = await subscriptionManager.restorePurchases()
                                isRestoring = false
                                isPurchasing = false
                                switch result {
                                case .restored:
                                    finishOnboarding()
                                case .noActivePurchase:
                                    restoreAlert = RestoreAlert(
                                        title: "Nothing to Restore",
                                        message: "We couldn't find an active purchase to restore for this Apple ID."
                                    )
                                case .failed(let message):
                                    restoreAlert = RestoreAlert(
                                        title: "Restore Failed",
                                        message: message
                                    )
                                }
                            }
                        } label: {
                            Text(isRestoring ? "Restoring..." : "Already a Pro? Restore")
                                .font(.bodySmall)
                                .foregroundColor(AppColors.heroTextFaint)
                        }
                        .disabled(isPurchasing)
                    }
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
        .task {
            if planOptions.isEmpty {
                await loadOfferings()
            }
        }
        .alert(item: $restoreAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Purchase

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let package: Package
            if let selected = planOptions.first(where: { $0.id == selectedPlanId })?.package {
                package = selected
            } else {
                let offerings = try await Purchases.shared.offerings()
                guard let offering = offerings.current else {
                    finishOnboarding()
                    return
                }
                guard let firstPackage = prioritizePackages(offering.availablePackages).first ?? offering.availablePackages.first else {
                    finishOnboarding()
                    return
                }
                package = firstPackage
            }

            data.selectedPlan = selectedPlanId ?? normalizedPlanId(for: package)

            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)
            if !userCancelled {
                subscriptionManager.isPremium = subscriptionManager.hasActiveEntitlement(in: customerInfo)
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

    private func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else { return }
            let packages = prioritizePackages(offering.availablePackages)
            let options = packages.map(planOption(for:))
            await MainActor.run {
                planOptions = options
                if selectedPlanId == nil {
                    selectedPlanId = options.first?.id
                }
            }
        } catch {
            #if DEBUG
            print("🔍 [OB_PaywallView] loadOfferings error: \(error)")
            #endif
        }
    }

    private var paywallBackground: some View {
        ZStack {
            LinearGradient(
                gradient: AppColors.heroBrandLinearGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.heroGlowPurple1, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: -120, y: -260)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.heroGlowPurple2, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: 130, y: -210)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.heroGlowPink, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: 0, y: 120)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.clear,
                    Color.black.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func prioritizePackages(_ packages: [Package]) -> [Package] {
        packages.sorted { lhs, rhs in
            sortOrder(for: lhs) < sortOrder(for: rhs)
        }
    }

    private func sortOrder(for package: Package) -> Int {
        switch normalizedPlanId(for: package) {
        case "yearly": 0
        case "monthly": 1
        default: 2
        }
    }

    private func normalizedPlanId(for package: Package) -> String {
        if let period = package.storeProduct.subscriptionPeriod {
            switch period.unit {
            case .year: return "yearly"
            case .month: return "monthly"
            case .week: return "weekly"
            case .day: return "daily"
            @unknown default: break
            }
        }

        let identifier = package.storeProduct.productIdentifier.lowercased()
        if identifier.contains("year") { return "yearly" }
        if identifier.contains("month") { return "monthly" }
        return package.identifier
    }

    private func planOption(for package: Package) -> PlanOption {
        let planId = normalizedPlanId(for: package)
        let isYearly = planId == "yearly"
        let title = isYearly ? "Yearly" : "Monthly"
        let subtitle = isYearly ? "Best for long-term tracking" : "Flexible monthly access"
        let unitLabel = isYearly ? "year" : "month"
        return PlanOption(
            id: planId,
            title: title,
            subtitle: subtitle,
            priceLine: "\(package.storeProduct.localizedPriceString)/\(unitLabel)",
            badge: isYearly ? "BEST VALUE" : nil,
            package: package
        )
    }

    @ViewBuilder
    private func planCard(_ option: PlanOption) -> some View {
        let isSelected = selectedPlanId == option.id

        Button {
            guard selectedPlanId != option.id else { return }
            selectedPlanId = option.id
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.detailTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: AppColors.gradientShellAccent,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.h4)
                        .foregroundStyle(AppColors.inkPrimary)

                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.inkSoft)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(option.priceLine)
                        .font(.h4)
                        .foregroundStyle(AppColors.inkPrimary)

                    if let badge = option.badge {
                        Text(badge)
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
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.92), Color.white.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppColors.glassCardShadow.opacity(1.4), radius: 24, x: 0, y: 12)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: AppColors.gradientShellAccent,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(AppColors.inkBorder),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [AppColors.shellBg1, AppColors.shellBg2],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        OB_PaywallView(data: OnboardingData(), onBack: {}, onComplete: {})
            .environment(SubscriptionManager.shared)
    }
}
