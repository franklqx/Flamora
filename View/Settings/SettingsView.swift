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
                        .foregroundColor(.white)
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
                    iconColor: Color(hex: "#A78BFA"),
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
                            iconColor: Color(hex: "#F97316"),
                            title: "Flamora Pro",
                            trailing: {
                                AnyView(
                                    Text(subscriptionManager.isPremium ? "Active" : "Upgrade")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(
                                            subscriptionManager.isPremium
                                                ? Color(hex: "#34D399")
                                                : Color(hex: "#A78BFA")
                                        )
                                )
                            }
                        )
                    }
                    .buttonStyle(.plain)

                    if subscriptionManager.isPremium {
                        Divider().background(Color(hex: "#2A2A2A")).padding(.leading, 60)

                        Button(action: {
                            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            row(
                                icon: "gear",
                                iconColor: Color(hex: "#6B7280"),
                                title: "Manage Subscription",
                                trailing: {
                                    AnyView(
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(hex: "#6B7280"))
                                    )
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().background(Color(hex: "#2A2A2A")).padding(.leading, 60)

                    Button(action: {
                        Task {
                            isRestoringPurchases = true
                            _ = await subscriptionManager.restorePurchases()
                            isRestoringPurchases = false
                        }
                    }) {
                        row(
                            icon: "arrow.clockwise",
                            iconColor: Color(hex: "#60A5FA"),
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
                        iconColor: Color(hex: "#34D399"),
                        title: plaidManager.connectedInstitutionName ?? "Connected Account",
                        subtitle: "Linked via Plaid",
                        trailing: {
                            AnyView(
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "#34D399"))
                            )
                        }
                    )

                    Divider().background(Color(hex: "#2A2A2A")).padding(.leading, 60)

                    Button(action: { showDisconnectConfirm = true }) {
                        row(
                            icon: "link.badge.minus",
                            iconColor: Color(hex: "#F87171"),
                            title: "Disconnect Bank",
                            trailing: {
                                isDisconnecting
                                    ? AnyView(ProgressView().tint(.white).scaleEffect(0.8))
                                    : AnyView(EmptyView())
                            }
                        )
                        .foregroundColor(Color(hex: "#F87171"))
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#F87171"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "#1A1A1A"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#2A2A2A"), lineWidth: 1)
                )
        }
    }

    var legalSection: some View {
        HStack(spacing: 16) {
            Text("Privacy Policy")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#4B5563"))
            Text("•")
                .foregroundColor(Color(hex: "#4B5563"))
            Text("Terms of Service")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#4B5563"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable UI Helpers

private extension SettingsView {

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "#6B7280"))
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(hex: "#121212"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#6B7280"))
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
