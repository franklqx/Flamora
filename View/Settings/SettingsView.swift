//
//  SettingsView.swift
//  Flamora app
//
//  设置页面 - 订阅管理、银行连接、账户操作
//

import SwiftUI
import SafariServices
internal import Auth

struct SettingsView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDisconnectConfirm = false
    @State private var isRestoringPurchases = false
    @State private var isDisconnecting = false
    @State private var showPaywall = false
    @State private var showPrivacy = false
    @State private var showTerms   = false

    @AppStorage(FlamoraStorageKey.budgetSetupCompleted) private var budgetSetupCompleted: Bool = false
    @State private var currentBudget: APIMonthlyBudget = .empty
    let isEmbeddedInSheet: Bool
    var tabBarScrollCollapse: Binding<CGFloat> = .constant(0)

    init(isEmbeddedInSheet: Bool = false, tabBarScrollCollapse: Binding<CGFloat> = .constant(0)) {
        self.isEmbeddedInSheet = isEmbeddedInSheet
        self.tabBarScrollCollapse = tabBarScrollCollapse
    }

    var body: some View {
        Group {
            if isEmbeddedInSheet {
                settingsBody
            } else {
                NavigationStack {
                    settingsBody
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { dismiss() }
                                    .foregroundStyle(AppColors.textPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if budgetSetupCompleted {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                let month = formatter.string(from: Date())
                if let b = try? await APIService.shared.getMonthlyBudget(month: month) {
                    currentBudget = b
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
                .environment(subscriptionManager)
        }
        .confirmationDialog(
            "Disconnect Bank",
            isPresented: $showDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                Task {
                    isDisconnecting = true
                    await plaidManager.disconnectBank()
                    isDisconnecting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your bank account will be disconnected and automatic transaction syncing will stop.")
        }
    }
}

private extension SettingsView {
    var settingsBody: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sectionGap) {
                    profileSection
                    subscriptionSection
                    if plaidManager.hasLinkedBank { bankSection }
                    budgetSection
                    signOutSection
                    legalSection
                }
                .padding(AppSpacing.cardPadding)
                .padding(.bottom, isEmbeddedInSheet ? AppSpacing.lg : AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .tracksTabBarScrollCollapse(tabBarScrollCollapse)
        }
    }
}

// MARK: - Sections

private extension SettingsView {

    var profileSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            sectionLabel("Account")
            cardContainer {
                row(
                    icon: "person.fill",
                            iconColor: AppColors.accentPurple,
                    title: SupabaseManager.shared.currentUser?.email ?? "—",
                    subtitle: nil
                )
            }
        }
    }

    var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            sectionLabel("Subscription")
            cardContainer {
                VStack(spacing: 0) {
                    Button(action: {
                        if !subscriptionManager.isPremium { showPaywall = true }
                    }) {
                        row(
                            icon: "flame.fill",
                            iconColor: AppColors.brandPrimary,
                            title: "Flamora Pro",
                            trailing: {
                                AnyView(
                                    Text(subscriptionManager.isPremium ? "Active" : "Upgrade")
                                        .font(.footnoteSemibold)
                                        .foregroundColor(
                                            subscriptionManager.isPremium
                                                ? AppColors.accentGreen
                                                : AppColors.accentPurple
                                        )
                                )
                            }
                        )
                    }
                    .buttonStyle(.plain)

                    if subscriptionManager.isPremium {
                        Divider().background(AppColors.borderLight).padding(.leading, 60)

                        Button(action: {
                            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            row(
                                icon: "gear",
                            iconColor: AppColors.textTertiary,
                            title: "Manage Subscription",
                            trailing: {
                                AnyView(
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                    )
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().background(AppColors.borderLight).padding(.leading, 60)

                    Button(action: {
                        Task {
                            isRestoringPurchases = true
                            _ = await subscriptionManager.restorePurchases()
                            isRestoringPurchases = false
                        }
                    }) {
                        row(
                            icon: "arrow.clockwise",
                            iconColor: AppColors.accentBlueBright,
                            title: "Restore Purchases",
                            trailing: {
                                isRestoringPurchases
                                    ? AnyView(ProgressView().tint(AppColors.textPrimary).scaleEffect(0.8))
                                    : AnyView(EmptyView())
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRestoringPurchases)
                }
            }
        }
    }

    var bankSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            sectionLabel("Connected Bank")
            cardContainer {
                VStack(spacing: 0) {
                    row(
                        icon: "building.columns.fill",
                            iconColor: AppColors.accentGreen,
                            title: plaidManager.connectedInstitutionName ?? "Connected Account",
                            subtitle: "Read-only access via Plaid",
                            trailing: {
                                AnyView(
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(AppColors.accentGreen)
                            )
                        }
                    )

                    Divider().background(AppColors.borderLight).padding(.leading, 60)

                    row(
                        icon: "lock.fill",
                        iconColor: AppColors.accentGreen,
                        title: "Your credentials are never stored in Flamora",
                        subtitle: nil
                    )

                    Divider().background(AppColors.borderLight).padding(.leading, 60)

                    Button(action: { showDisconnectConfirm = true }) {
                        row(
                            icon: "link.badge.minus",
                            iconColor: AppColors.error,
                            title: "Disconnect Bank",
                            trailing: {
                                isDisconnecting
                                    ? AnyView(ProgressView().tint(AppColors.textPrimary).scaleEffect(0.8))
                                    : AnyView(EmptyView())
                            }
                        )
                        .foregroundColor(AppColors.error)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisconnecting)
                }
            }
        }
    }

    var budgetSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            sectionLabel("Budget")
            cardContainer {
                VStack(spacing: 0) {
                    if budgetSetupCompleted {
                        let totalBudget = currentBudget.needsBudget + currentBudget.wantsBudget + currentBudget.savingsBudget
                        let planName = currentBudget.selectedPlan?.capitalized ?? "Custom"
                        let subtitle = totalBudget > 0 ? "\(planName) · $\(formattedBudget(totalBudget))/mo" : planName

                        row(
                            icon: "chart.pie.fill",
                            iconColor: AppColors.accentPurple,
                            title: "Current Budget",
                            subtitle: subtitle
                        )

                        Divider().background(AppColors.borderLight).padding(.leading, 60)
                    }

                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            plaidManager.showBudgetSetup = true
                        }
                    }) {
                        row(
                            icon: "arrow.clockwise.circle.fill",
                            iconColor: AppColors.budgetGold,
                            title: budgetSetupCompleted ? "Rebuild Budget" : "Set Up Budget",
                            trailing: {
                                AnyView(
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                )
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var signOutSection: some View {
        Button(action: {
            Task {
                try? await SupabaseManager.shared.signOut()
                subscriptionManager.logoutUser()
                dismiss()
            }
        }) {
            Text("Sign Out")
                .font(.bodySemibold)
                .foregroundColor(AppColors.error)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.borderLight, lineWidth: 0.75)
                )
        }
    }

    var legalSection: some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                showPrivacy = true
            } label: {
                Text("Privacy Policy")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .underline()
            }
            Text("•")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
            Button {
                showTerms = true
            } label: {
                Text("Terms of Service")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: AppLinks.privacyPolicyURL).ignoresSafeArea()
        }
        .sheet(isPresented: $showTerms) {
            SafariView(url: AppLinks.termsOfServiceURL).ignoresSafeArea()
        }
    }
}

// MARK: - Reusable UI Helpers

private extension SettingsView {

    func formattedBudget(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.smallLabel)
            .foregroundColor(AppColors.textTertiary)
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.surfaceBorder, lineWidth: 0.75)
        )
    }

    func row(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        trailing: (() -> AnyView)? = nil
    ) -> some View {
        HStack(spacing: AppSpacing.rowItem) {
            Image(systemName: icon)
                .font(.figureSecondarySemibold)
                .foregroundColor(iconColor)
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm + 1))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.supportingText)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            trailing?()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.rowItem)
    }
}

#Preview {
    SettingsView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
