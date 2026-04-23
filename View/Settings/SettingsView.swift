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
    @State private var archivedReports: [ReportArchiveItem] = []
    @State private var selectedReport: ReportSnapshot? = nil
    @State private var isLoadingArchive = false

    @AppStorage(FlamoraStorageKey.budgetSetupCompleted) private var budgetSetupCompleted: Bool = false
    @State private var currentBudget: APIMonthlyBudget = .empty
    let isEmbeddedInSheet: Bool

    init(isEmbeddedInSheet: Bool = false) {
        self.isEmbeddedInSheet = isEmbeddedInSheet
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
                                    .foregroundStyle(AppColors.inkPrimary)
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
        .task {
            if budgetSetupCompleted {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM"
                let month = formatter.string(from: Date())
                if let b = try? await APIService.shared.getMonthlyBudget(month: month) {
                    currentBudget = b
                }
            }
            await loadArchivedReports()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
                .environment(subscriptionManager)
        }
        .fullScreenCover(item: $selectedReport, onDismiss: {
            Task { await loadArchivedReports() }
        }) { report in
            reportDestination(for: report)
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
            LinearGradient(
                colors: [AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sectionGap) {
                    profileSection
                    subscriptionSection
                    if plaidManager.hasLinkedBank { bankSection }
                    budgetSection
                    archiveSection
                    signOutSection
                    legalSection
                }
                .padding(AppSpacing.cardPadding)
                .padding(.bottom, isEmbeddedInSheet ? AppSpacing.lg : AppSpacing.xl)
            }
            .scrollContentBackground(.hidden)
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
                        divider

                        Button(action: {
                            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            row(
                                icon: "gear",
                            iconColor: AppColors.inkFaint,
                            title: "Manage Subscription",
                            trailing: {
                                AnyView(
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.inkFaint)
                                    )
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    divider

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
                                    ? AnyView(ProgressView().tint(AppColors.inkPrimary).scaleEffect(0.8))
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

                    divider

                    row(
                        icon: "lock.fill",
                        iconColor: AppColors.accentGreen,
                        title: "Your credentials are never stored in Flamora",
                        subtitle: nil
                    )

                    divider

                    Button(action: { showDisconnectConfirm = true }) {
                        row(
                            icon: "link.badge.minus",
                            iconColor: AppColors.error,
                            title: "Disconnect Bank",
                            trailing: {
                                isDisconnecting
                                    ? AnyView(ProgressView().tint(AppColors.inkPrimary).scaleEffect(0.8))
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

                        divider
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
                                        .foregroundColor(AppColors.inkFaint)
                                )
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var archiveSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            sectionLabel("Report Archive")
            cardContainer {
                if isLoadingArchive && archivedReports.isEmpty {
                    HStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .tint(AppColors.inkPrimary)
                        Text("Loading archived reports...")
                            .font(.footnoteRegular)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPadding)
                } else if archivedReports.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("No archived reports yet")
                            .font(.inlineLabel)
                            .foregroundStyle(AppColors.inkPrimary)
                        Text("Viewed and older weekly, monthly, annual, and Issue Zero stories will live here.")
                            .font(.footnoteRegular)
                            .foregroundStyle(AppColors.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPadding)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(archivedReports.prefix(8).enumerated()), id: \.element.id) { index, item in
                            ReportFeedRow(item: item) {
                                Task { await openArchivedReport(id: item.reportId) }
                            }

                            if index < min(archivedReports.count, 8) - 1 {
                                divider
                            }
                        }
                    }
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
                .foregroundColor(AppColors.ctaWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColors.ctaBlack)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.ctaBlack.opacity(0.12), lineWidth: 0.75)
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
                    .foregroundColor(AppColors.inkFaint)
                    .underline()
            }
            Text("•")
                .font(.caption)
                .foregroundColor(AppColors.inkFaint)
            Button {
                showTerms = true
            } label: {
                Text("Terms of Service")
                    .font(.caption)
                    .foregroundColor(AppColors.inkFaint)
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
            .font(.cardHeader)
            .foregroundColor(AppColors.inkPrimary)
            .textCase(.uppercase)
            .tracking(AppTypography.Tracking.cardHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [AppColors.glassCardBg, AppColors.glassCardBg2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    var divider: some View {
        Rectangle()
            .fill(AppColors.inkDivider)
            .frame(height: 0.5)
            .padding(.leading, 60)
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
                    .foregroundStyle(AppColors.inkPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.inkFaint)
                }
            }

            Spacer()

            trailing?()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.rowItem)
    }

    func loadArchivedReports() async {
        guard !isLoadingArchive else { return }
        isLoadingArchive = true
        defer { isLoadingArchive = false }

        do {
            archivedReports = try await APIService.shared.getArchivedReports()
        } catch {
            archivedReports = []
        }
    }

    func openArchivedReport(id: String) async {
        do {
            selectedReport = try await APIService.shared.getReportDetail(id: id)
            await loadArchivedReports()
        } catch {
            #if DEBUG
            print("❌ [SettingsView] failed to open archived report: \(error)")
            #endif
        }
    }

    @ViewBuilder
    func reportDestination(for report: ReportSnapshot) -> some View {
        switch report.kind {
        case .weekly:
            WeeklyReportView(report: report)
        case .monthly:
            MonthlyReportView(report: report)
        case .annual:
            AnnualReportView(report: report)
        case .issueZero:
            IssueZeroView(report: report)
        }
    }
}

#Preview {
    SettingsView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
