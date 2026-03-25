//
//  SettingsView.swift
//  Flamora app
//
//  设置页面 - 订阅管理、银行连接、账户操作
//

import SwiftUI
internal import Auth

struct SettingsView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDisconnectConfirm = false
    @State private var isRestoringPurchases = false
    @State private var isDisconnecting = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileSection
                        subscriptionSection
                        if plaidManager.hasLinkedBank { bankSection }
                        signOutSection
                        legalSection
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
            .preferredColorScheme(.dark)
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

// MARK: - Sections

private extension SettingsView {

    var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        VStack(alignment: .leading, spacing: 10) {
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
                                    ? AnyView(ProgressView().tint(.white).scaleEffect(0.8))
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
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Connected Bank")
            cardContainer {
                VStack(spacing: 0) {
                    row(
                        icon: "building.columns.fill",
                            iconColor: AppColors.accentGreen,
                            title: plaidManager.connectedInstitutionName ?? "Connected Account",
                            subtitle: "Linked via Plaid",
                            trailing: {
                                AnyView(
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.accentGreen)
                            )
                        }
                    )

                    Divider().background(AppColors.borderLight).padding(.leading, 60)

                    Button(action: { showDisconnectConfirm = true }) {
                        row(
                            icon: "link.badge.minus",
                            iconColor: AppColors.error,
                            title: "Disconnect Bank",
                            trailing: {
                                isDisconnecting
                                    ? AnyView(ProgressView().tint(.white).scaleEffect(0.8))
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
        HStack(spacing: 16) {
            Text("Privacy Policy")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
            Text("•")
                .foregroundColor(AppColors.textMuted)
            Text("Terms of Service")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable UI Helpers

private extension SettingsView {

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
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.figureSecondarySemibold)
                .foregroundColor(iconColor)
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.supportingText)
                    .foregroundStyle(.white)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    SettingsView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
