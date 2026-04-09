//
//  JourneyView.swift
//  Flamora app
//
//  Phase 4 Home rebuild shell:
//  - Act 1: official Hero + guided card or action strip
//  - Act 2: sandbox shell
//
//  Data loading is owned by JourneyViewModel.
//  `.task(id:)` + savings check-in generation reloads call viewModel.loadData().
//

import SwiftUI

/// Drives `.task(id:)` so Plaid + notification reloads cancel/restart instead of fire-and-forget `Task {}`.
private struct JourneyReloadTrigger: Equatable {
    var connectionTime: TimeInterval?
    var hasLinkedBank: Bool
    var savingsPersistGeneration: Int
    var budgetSetupDismissGeneration: Int
}

struct JourneyView: View {
    @State private var viewModel = JourneyViewModel(plaidManager: PlaidManager.shared)
    @State private var savingsCheckInGeneration = 0
    @State private var budgetSetupDismissGeneration = 0
    @State private var heroVisible = false
    @State private var sheetVisible = false

    var onFireTapped: (() -> Void)? = nil
    var onInvestmentTapped: (() -> Void)? = nil
    var onOpenCashflowDestination: ((CashflowJourneyDestination) -> Void)? = nil
    let bottomPadding: CGFloat

    @Environment(PlaidManager.self) private var plaidManager

    private var journeyReloadTrigger: JourneyReloadTrigger {
        JourneyReloadTrigger(
            connectionTime: plaidManager.lastConnectionTime?.timeIntervalSince1970,
            hasLinkedBank: plaidManager.hasLinkedBank,
            savingsPersistGeneration: savingsCheckInGeneration,
            budgetSetupDismissGeneration: budgetSetupDismissGeneration
        )
    }

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
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: AppColors.investHeroGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: AppSpacing.heroFullHeight)
                .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        Color.clear.frame(height: AppSpacing.heroFullHeight)

                        if let msg = viewModel.loadErrorMessage {
                            ErrorBanner(
                                message: msg,
                                onRetry: { Task { await viewModel.loadData() } }
                            )
                        }

                        if viewModel.hasCompletedInitialHomeLoad {
                            FIRECountdownCard(
                                hero: viewModel.homeHero,
                                stage: viewModel.homeSetupStage,
                                onPrimaryAction: viewModel.openSetupFlow
                            )
                            .opacity(heroVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.2), value: heroVisible)

                            Group {
                                if viewModel.homeSetupStage.needsGuidedCard {
                                    GuidedSetupCard(
                                        stage: viewModel.homeSetupStage,
                                        onPrimaryAction: viewModel.openSetupFlow
                                    )
                                } else {
                                    HomeActionStrip(
                                        saveStatus: viewModel.saveStatusText,
                                        budgetStatus: viewModel.budgetStatusText,
                                        investStatus: viewModel.investStatusText,
                                        onSaveTapped: { onOpenCashflowDestination?(.savingsOverview) },
                                        onBudgetTapped: { onOpenCashflowDestination?(.totalSpending) },
                                        onInvestTapped: onInvestmentTapped
                                    )
                                }

                                HomeSandboxShell(
                                    stage: viewModel.homeSetupStage,
                                    onOpenSimulator: onFireTapped
                                )
                            }
                            .opacity(sheetVisible ? 1 : 0)
                            .offset(y: sheetVisible ? 0 : (AppSpacing.lg + AppSpacing.md))
                            .animation(.easeOut(duration: 0.32), value: sheetVisible)
                        } else {
                            initialLoadingShell
                        }
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, max(bottomPadding, AppSpacing.lg))
                }
            }
        }
        .animation(nil, value: bottomPadding)
        .task(id: journeyReloadTrigger) {
            await viewModel.loadData()
            if !heroVisible {
                withAnimation(.easeOut(duration: 0.2)) { heroVisible = true }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeOut(duration: 0.32)) { sheetVisible = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            savingsCheckInGeneration += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetSetupFlowDidDismiss)) { _ in
            budgetSetupDismissGeneration += 1
        }
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
                    Text("Sandbox")
                        .font(.cardHeader)
                        .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                        .tracking(AppTypography.Tracking.cardHeader)

                    Text(teaserLine)
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

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

            if let onOpenSimulator {
                Button(action: onOpenSimulator) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "sparkles")
                        Text(stage == .active ? "Open Sandbox" : "Open Demo Simulator")
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

    private var teaserLine: String {
        stage == .active
            ? "The full simulator lives on Home. Drag the sheet up or tap below — your official Hero stays unchanged."
            : "Drag the Home sheet up or tap below to try the demo simulator before your data is ready."
    }
}
