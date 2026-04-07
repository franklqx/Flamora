//
//  JourneyView.swift
//  Flamora app
//
//  Phase 4 Home rebuild shell:
//  - Act 1: official Hero + guided card or action strip
//  - Act 2: sandbox shell
//

import SwiftUI

struct JourneyView: View {
    @State private var setupState: HomeSetupStateResponse?
    @State private var homeHero: HomeHeroModel?
    @State private var netWorthSummary = APINetWorthSummary.empty
    @State private var apiBudget = APIMonthlyBudget.empty
    @State private var currentMonthSummary: APISpendingSummary?
    @State private var loadErrorMessage: String?
    @State private var isLoadingData = false
    @State private var needsReloadAfterCurrentPass = false
    @State private var hasCompletedInitialHomeLoad = false

    var onFireTapped: (() -> Void)? = nil
    var onInvestmentTapped: (() -> Void)? = nil
    var onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    let bottomPadding: CGFloat

    @Environment(PlaidManager.self) private var plaidManager

    init(
        bottomPadding: CGFloat = 0,
        onFireTapped: (() -> Void)? = nil,
        onInvestmentTapped: (() -> Void)? = nil,
        onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    ) {
        self.bottomPadding = bottomPadding
        self.onFireTapped = onFireTapped
        self.onInvestmentTapped = onInvestmentTapped
        self.onOpenCashflowDestination = onOpenCashflowDestination
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    if let loadErrorMessage {
                        ErrorBanner(
                            message: loadErrorMessage,
                            onRetry: { Task { await loadData() } }
                        )
                    }

                    if hasCompletedInitialHomeLoad {
                        FIRECountdownCard(
                            hero: homeHero,
                            stage: homeSetupStage,
                            onPrimaryAction: openSetupFlow
                        )

                        if homeSetupStage.needsGuidedCard {
                            GuidedSetupCard(
                                stage: homeSetupStage,
                                onPrimaryAction: openSetupFlow
                            )
                        } else {
                            HomeActionStrip(
                                saveStatus: saveStatusText,
                                budgetStatus: budgetStatusText,
                                investStatus: investStatusText,
                                onSaveTapped: { onOpenCashflowDestination?(.savingsOverview) },
                                onBudgetTapped: { onOpenCashflowDestination?(.totalSpending) },
                                onInvestTapped: onInvestmentTapped
                            )
                        }

                        HomeSandboxShell(
                            stage: homeSetupStage,
                            hero: homeHero,
                            onOpenSimulator: onFireTapped
                        )
                    } else {
                        initialLoadingShell
                    }
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, max(bottomPadding, AppSpacing.lg))
            }
        }
        .animation(nil, value: bottomPadding)
        .task { await loadData() }
        .onChange(of: plaidManager.lastConnectionTime) { _, _ in
            Task { await loadData() }
        }
        .onChange(of: plaidManager.hasLinkedBank) { _, _ in
            Task { await loadData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            Task { await loadData() }
        }
    }
}

// MARK: - View State

private extension JourneyView {
    var homeSetupStage: HomeSetupStage {
        if let stage = setupState?.setupStage { return stage }
        return plaidManager.hasLinkedBank ? .accountsLinked : .noGoal
    }

    var saveStatusText: String {
        let actual = currentMonthSummary?.savings.actual ?? apiBudget.savingsActual ?? 0
        if let target = homeHero?.savingsTargetMonthly, target > 0 {
            return "\(compactCurrency(actual)) / \(compactCurrency(target))"
        }
        if actual > 0 {
            return "\(compactCurrency(actual)) saved"
        }
        return "Track savings"
    }

    var budgetStatusText: String {
        let planned = apiBudget.needsBudget + apiBudget.wantsBudget
        let actual = (currentMonthSummary?.needs.total ?? 0) + (currentMonthSummary?.wants.total ?? 0)

        guard planned > 0 else { return "Build your plan" }

        let delta = ((actual - planned) / planned) * 100
        if abs(delta) < 1 { return "On plan" }
        if delta > 0 { return "\(Int(delta.rounded()))% over plan" }
        return "\(Int(abs(delta).rounded()))% under plan"
    }

    var investStatusText: String {
        if let growth = netWorthSummary.growthAmount {
            let prefix = growth >= 0 ? "+" : "-"
            return "\(prefix)\(compactCurrency(abs(growth))) this month"
        }
        if let total = netWorthSummary.breakdown.investmentTotal, total > 0 {
            return "\(compactCurrency(total)) invested"
        }
        return "View portfolio"
    }

    func compactCurrency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    func openSetupFlow() {
        plaidManager.showBudgetSetup = true
    }
}

// MARK: - Data Loading

private extension JourneyView {
    @MainActor
    func loadData() async {
        if isLoadingData {
            needsReloadAfterCurrentPass = true
            return
        }

        isLoadingData = true
        needsReloadAfterCurrentPass = false
        let shouldLoadExecution = plaidManager.hasLinkedBank

        defer {
            isLoadingData = false
            if needsReloadAfterCurrentPass {
                needsReloadAfterCurrentPass = false
                Task { await loadData() }
            }
        }

        loadErrorMessage = nil

        let monthStr = currentMonthString
        let state = await fetchSetupState()
        // Only update setupState on success — keeping the last known value on 401/error
        // prevents homeSetupStage from flipping mid-scroll, which freezes the ScrollView.
        if let state { setupState = state }
        if !hasCompletedInitialHomeLoad { hasCompletedInitialHomeLoad = true }

        let shouldLoadHero = (state ?? setupState)?.setupStage == .active
        async let netWorthTask = fetchNetWorth()
        async let executionTask = fetchExecutionData(month: monthStr, shouldLoad: shouldLoadExecution)
        async let heroTask: HomeHeroModel? = shouldLoadHero ? fetchHomeHero() : nil

        let (hero, netWorth, executionData) = await (heroTask, netWorthTask, executionTask)

        homeHero = hero

        if let netWorth {
            netWorthSummary = netWorth
        }

        apiBudget = executionData.budget ?? .empty
        currentMonthSummary = executionData.summary

        // Show error banner only if we have no cached state at all (completely cold start failure).
        // When we have a cached setupState, the UI is still usable — no need to show the banner.
        if state == nil && setupState == nil {
            loadErrorMessage = "Couldn't load your home state."
        }
    }

    func fetchSetupState() async -> HomeSetupStateResponse? {
        do {
            return try await APIService.shared.getSetupState()
        } catch {
            print("❌ [Journey] getSetupState failed: \(error)")
            return nil
        }
    }

    func fetchHomeHero() async -> HomeHeroModel? {
        do {
            return try await APIService.shared.getHomeHero()
        } catch {
            print("⚠️ [Journey] getHomeHero failed: \(error)")
            return nil
        }
    }

    func fetchNetWorth() async -> APINetWorthSummary? {
        do {
            return try await APIService.shared.getNetWorthSummary()
        } catch {
            print("⚠️ [Journey] getNetWorthSummary failed: \(error)")
            return nil
        }
    }

    func fetchExecutionData(month: String, shouldLoad: Bool) async -> (budget: APIMonthlyBudget?, summary: APISpendingSummary?) {
        guard shouldLoad else { return (nil, nil) }

        async let budgetTask = fetchBudget(month: month)
        async let summaryTask = fetchCurrentMonthSummary(month: month)
        return await (budgetTask, summaryTask)
    }

    func fetchBudget(month: String) async -> APIMonthlyBudget? {
        try? await APIService.shared.getMonthlyBudget(month: month)
    }

    func fetchCurrentMonthSummary(month: String) async -> APISpendingSummary? {
        try? await APIService.shared.getSpendingSummary(month: month)
    }

    var currentMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}

private extension JourneyView {
    var initialLoadingShell: some View {
        VStack(spacing: AppSpacing.lg) {
            FIRECountdownCard(hero: nil, stage: .accountsLinked, onPrimaryAction: nil)

            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColors.surfaceElevated)
                .frame(height: 132)
                .overlay(
                    ProgressView()
                        .tint(AppColors.textPrimary)
                )
                .padding(.horizontal, AppSpacing.screenPadding)
        }
    }
}

#Preview {
    JourneyView(onFireTapped: {})
        .environment(PlaidManager.shared)
        .environment(SubscriptionManager.shared)
}

// MARK: - Supporting Blocks

private struct GuidedSetupCard: View {
    let stage: HomeSetupStage
    var onPrimaryAction: (() -> Void)? = nil

    var body: some View {
        let content = GuidedSetupCardContent.content(for: stage)

        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Text("NEXT STEP")
                    .font(.cardHeader)
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(AppTypography.Tracking.cardHeader)

                Capsule()
                    .fill(AppColors.overlayWhiteStroke)
                    .frame(width: 1, height: 10)

                Text(stageBadge)
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(content.title)
                    .font(.h4)
                    .foregroundStyle(AppColors.textPrimary)

                Text(content.body)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }

            if let onPrimaryAction {
                Button(action: onPrimaryAction) {
                    Text(content.ctaLabel)
                        .font(.bodySmallSemibold)
                        .foregroundStyle(AppColors.textInverse)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private var stageBadge: String {
        switch stage {
        case .noGoal: return "GOAL"
        case .goalSet: return "CONNECT"
        case .accountsLinked: return "REVIEW"
        case .snapshotPending: return "SNAPSHOT"
        case .planPending: return "PLAN"
        case .active: return "READY"
        }
    }
}

private struct HomeActionStrip: View {
    let saveStatus: String
    let budgetStatus: String
    let investStatus: String
    var onSaveTapped: (() -> Void)? = nil
    var onBudgetTapped: (() -> Void)? = nil
    var onInvestTapped: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            actionItem(title: "Save", value: saveStatus, action: onSaveTapped)
            actionItem(title: "Budget", value: budgetStatus, action: onBudgetTapped)
            actionItem(title: "Invest", value: investStatus, action: onInvestTapped)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    @ViewBuilder
    private func actionItem(title: String, value: String, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title.uppercased())
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

                Text(value)
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeSandboxShell: View {
    let stage: HomeSetupStage
    let hero: HomeHeroModel?
    var onOpenSimulator: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Capsule()
                .fill(AppColors.overlayWhiteStroke)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.sm)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(stage == .active ? "SANDBOX" : "DEMO SIMULATOR")
                        .font(.cardHeader)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                        .tracking(AppTypography.Tracking.cardHeader)

                    Text(stage == .active ? "Test your future without changing your official path." : "Try the FIRE simulator before finishing setup.")
                        .font(.h4)
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                if stage != .active {
                    Text("DEMO")
                        .font(.miniLabel)
                        .foregroundStyle(AppColors.textInverse)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColors.accentAmber)
                        .clipShape(Capsule())
                }
            }

            Text(stage == .active ? "Your Hero stays official. This second act is where you test what changes could move your FIRE date." : "Use sample data and quick what-if controls to feel the product magic before your real data is ready.")
                .font(.bodySmall)
                .foregroundStyle(AppColors.overlayWhiteOnGlass)
                .lineSpacing(3)

            sandboxResultCard
            sandboxChartPlaceholder

            if let onOpenSimulator {
                Button(action: onOpenSimulator) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "sparkles")
                        Text(stage == .active ? "Open Sandbox" : "Try Demo Simulator")
                    }
                    .font(.bodySmallSemibold)
                    .foregroundStyle(AppColors.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: stage == .active ? AppColors.gradientFire : [AppColors.accentBlue, AppColors.accentPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.cardPadding)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.cardPadding)
        .background(
            LinearGradient(
                colors: [AppColors.backgroundSecondary, AppColors.surface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private var sandboxResultCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(stage == .active ? "OFFICIAL PATH" : "SAMPLE PATH")
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            Text(hero?.displayFireDate ?? "Mar 2042")
                .font(.h3)
                .foregroundStyle(AppColors.textPrimary)

            Text(stage == .active ? "Your simulator changes stay here until you explicitly apply them." : "This preview uses sample data and does not change your official progress.")
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.overlayWhiteWash)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }

    private var sandboxChartPlaceholder: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("CURRENT VS ADJUSTED")
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.overlayWhiteWash)
                    .frame(height: 132)

                Path { path in
                    path.move(to: CGPoint(x: 16, y: 100))
                    path.addCurve(
                        to: CGPoint(x: 260, y: 40),
                        control1: CGPoint(x: 80, y: 80),
                        control2: CGPoint(x: 190, y: 55)
                    )
                }
                .stroke(AppColors.overlayWhiteForegroundMuted, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))

                Path { path in
                    path.move(to: CGPoint(x: 16, y: 108))
                    path.addCurve(
                        to: CGPoint(x: 280, y: 24),
                        control1: CGPoint(x: 90, y: 92),
                        control2: CGPoint(x: 210, y: 36)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: stage == .active ? AppColors.gradientFire : [AppColors.accentBlue, AppColors.accentPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )
                .padding(.bottom, AppSpacing.xs)
            }

            HStack(spacing: AppSpacing.md) {
                legendDot(color: AppColors.overlayWhiteForegroundMuted, label: "Current")
                legendDot(color: stage == .active ? AppColors.budgetOrange : AppColors.accentBlue, label: "Adjusted")
            }
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.footnoteRegular)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
