//
//  MainTabView.swift
//  Flamora app
//
//  主导航容器 - Home hero + draggable sheet
//

import SwiftUI
internal import Auth

struct MainTabView: View {
    @State private var selectedTab: MainTabItem = .cashflow
    @State private var highlightedTab: MainTabItem = .cashflow
    @State private var isSimulatorShown = false
    @State private var showsHomeSheet = true
    @State private var simulatorDisplayState: SimulatorDisplayState = .results
    @State private var showNotifications = false
    @State private var simulatorTransitionTask: Task<Void, Never>?

    @State private var sheetHeight = HomeLayout.sheetDefault
    @State private var sheetDragStartHeight = HomeLayout.sheetDefault
    @State private var isSheetDragging = false

    @State private var heroSnapshot = HomeHeroSnapshot.empty

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        ZStack(alignment: .top) {
            AppBackgroundView()

            HomeHeroCardSurface(
                snapshot: heroSnapshot,
                heroHeight: currentHeroHeight,
                compactProgress: heroCompactProgress,
                flipAngle: heroFlipAngle,
                isSimulatorShown: isSimulatorShown,
                onHeroUpdated: { heroSnapshot = $0 }
            )
            .zIndex(60)

            TopHeaderBar(
                onNotificationTapped: { showNotifications = true },
                isVisible: true
            )
            .zIndex(80)

            if showsHomeSheet {
                HomeBottomSheet(
                    height: sheetHeight,
                    selectedTab: selectedTab,
                    sheetDragGesture: sheetDragGesture
                )
                .zIndex(20)
            }

            if isSimulatorShown {
                simulatorOverlay
                    .zIndex(40)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassmorphicTabBar(
                selectedTab: $highlightedTab,
                onTabTapped: handleTabTap
            )
            .ignoresSafeArea(edges: .bottom)
            .opacity(tabBarOpacity)
            .offset(y: tabBarOffsetY)
            .allowsHitTesting(tabBarOpacity > 0.02)
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        .fullScreenCover(isPresented: Binding(
            get: { plaidManager.showBudgetSetup },
            set: { plaidManager.showBudgetSetup = $0 }
        ), onDismiss: {
            plaidManager.lastConnectionTime = Date()
        }) {
            BudgetSetupView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .onDisappear {
            simulatorTransitionTask?.cancel()
        }
    }
}

private extension MainTabView {
    var simulatorOverlay: some View {
        AppColors.backgroundPrimary
            .ignoresSafeArea()
            .overlay {
                SimulatorView(
                    displayState: $simulatorDisplayState,
                    bottomPadding: 0,
                    isFireOn: true,
                    onFireToggle: exitSimulator,
                    showResultCard: false,
                    contentTopPadding: TopHeaderBar.height + AppSpacing.md + HomeLayout.heroFullHeight + AppSpacing.md
                )
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height < -44 {
                            exitSimulator()
                        }
                    }
            )
    }

    var sheetDragGesture: AnyGesture<DragGesture.Value> {
        AnyGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isSheetDragging {
                        isSheetDragging = true
                        sheetDragStartHeight = sheetHeight
                    }
                    let nextHeight = sheetDragStartHeight - value.translation.height
                    sheetHeight = clampSheetHeight(nextHeight)
                }
                .onEnded { value in
                    isSheetDragging = false

                    let draggedDownDistance = value.translation.height
                    let predictedDownDistance = value.predictedEndTranslation.height
                    let shouldSnapToSimulatorByDistance = draggedDownDistance > HomeLayout.sheetSnapDistanceToSimulator
                    let shouldSnapToSimulatorByMomentum = predictedDownDistance > HomeLayout.sheetPredictedSnapDistanceToSimulator

                    if sheetHeight < HomeLayout.sheetDefault * HomeLayout.sheetToSimulatorThreshold
                        || shouldSnapToSimulatorByDistance
                        || shouldSnapToSimulatorByMomentum {
                        enterSimulator()
                        return
                    }
                    if sheetHeight > HomeLayout.sheetDefault * 1.15 {
                        withAnimation(HomeLayout.springAnimation) {
                            sheetHeight = HomeLayout.sheetTall
                        }
                    } else {
                        withAnimation(HomeLayout.springAnimation) {
                            sheetHeight = HomeLayout.sheetDefault
                        }
                    }
                }
        )
    }

    var heroFlipAngle: Double {
        if isSimulatorShown { return -180 }
        let progress = max(0, min(1, 1 - (sheetHeight / HomeLayout.sheetDefault)))
        return -180 * progress
    }

    var currentHeroHeight: CGFloat {
        if isSimulatorShown { return HomeLayout.heroFullHeight }
        let compactProgress = heroCompactProgress
        return HomeLayout.heroFullHeight
            - ((HomeLayout.heroFullHeight - HomeLayout.heroCompactHeight) * compactProgress)
    }

    var heroCompactProgress: CGFloat {
        guard !isSimulatorShown, sheetHeight > HomeLayout.sheetDefault else { return 0 }
        return max(
            0,
            min(
                1,
                (sheetHeight - HomeLayout.sheetDefault)
                    / (HomeLayout.compactDoneHeight - HomeLayout.sheetDefault)
            )
        )
    }

    var tabBarHideProgress: CGFloat {
        guard !isSimulatorShown else { return 1 }
        let distance = HomeLayout.sheetDefault - sheetHeight
        let threshold = HomeLayout.sheetDefault * 0.45
        if distance <= 0 { return 0 }
        return max(0, min(1, distance / threshold))
    }

    var tabBarOpacity: CGFloat {
        if isSimulatorShown { return 0 }
        return 1 - tabBarHideProgress
    }

    var tabBarOffsetY: CGFloat {
        if isSimulatorShown { return 48 }
        return 32 * tabBarHideProgress
    }

    func clampSheetHeight(_ value: CGFloat) -> CGFloat {
        max(0, min(HomeLayout.sheetTall + 30, value))
    }

    func enterSimulator() {
        simulatorTransitionTask?.cancel()
        withAnimation(HomeLayout.springAnimation) {
            sheetHeight = 0
        }

        simulatorTransitionTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                simulatorDisplayState = .results
                withAnimation(.easeInOut(duration: 0.16)) {
                    isSimulatorShown = true
                }
                showsHomeSheet = false
            }
        }
    }

    func exitSimulator() {
        simulatorTransitionTask?.cancel()
        showsHomeSheet = true
        sheetHeight = 0
        withAnimation(.easeInOut(duration: 0.16)) {
            isSimulatorShown = false
        }
        withAnimation(HomeLayout.springAnimation) {
            simulatorDisplayState = .results
            sheetHeight = HomeLayout.sheetDefault
        }
    }

    func handleTabTap(_ tab: MainTabItem) {
        switch tab {
        case .cashflow, .investment, .settings:
            withAnimation(HomeLayout.springAnimation) {
                selectedTab = tab
                highlightedTab = tab
            }
        }
    }
}

private enum HomeLayout {
    static let heroFullHeight: CGFloat = 212
    static let heroCompactHeight: CGFloat = 34
    static let sheetDefault: CGFloat = 520
    static let sheetTall: CGFloat = 702
    static let compactDoneHeight: CGFloat = 660
    static let sheetToSimulatorThreshold: CGFloat = 0.72
    static let sheetSnapDistanceToSimulator: CGFloat = 96
    static let sheetPredictedSnapDistanceToSimulator: CGFloat = 150
    static let springAnimation = Animation.spring(response: 0.42, dampingFraction: 0.82)
}

private struct HomeBottomSheet: View {
    let height: CGFloat
    let selectedTab: MainTabItem
    let sheetDragGesture: AnyGesture<DragGesture.Value>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Capsule()
                    .fill(AppColors.surfaceBorder)
                    .frame(width: 36, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .highPriorityGesture(sheetDragGesture)

            Group {
                switch selectedTab {
                case .cashflow:
                    CashflowView()
                case .investment:
                    InvestmentView()
                case .settings:
                    SettingsView(isEmbeddedInSheet: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(AppColors.textPrimary)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: AppRadius.xl)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 0.5)
        )
        .shadow(color: AppColors.cardShadow, radius: 14, y: -2)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct HomeHeroCardSurface: View {
    let snapshot: HomeHeroSnapshot
    let heroHeight: CGFloat
    let compactProgress: CGFloat
    let flipAngle: Double
    let isSimulatorShown: Bool
    let onHeroUpdated: (HomeHeroSnapshot) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                HomeHeroCardHost(onHeroUpdated: onHeroUpdated)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .scaleEffect(
                        x: 1,
                        y: max(0.42, 1 - (compactProgress * 0.58)),
                        anchor: .top
                    )
                    .opacity(frontFaceOpacity)

                HeroBackFaceCard(snapshot: snapshot)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .rotation3DEffect(
                        .degrees(180),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.75
                    )
                    .opacity(backFaceOpacity)
            }
            .rotation3DEffect(
                .degrees(flipAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.75
            )
            .animation(HomeLayout.springAnimation, value: flipAngle)

            if compactProgress > 0.01 && !isSimulatorShown {
                HeroCompactStrip(snapshot: snapshot)
                    .opacity(pow(compactProgress, 1.25))
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.top, 2)
            }
        }
        .frame(height: heroHeight, alignment: .top)
        .clipped()
        .padding(.top, TopHeaderBar.height + AppSpacing.md)
    }

    var flipProgress: Double {
        max(0, min(1, -flipAngle / 180))
    }

    var frontFaceOpacity: Double {
        if isSimulatorShown { return 0 }
        return flipProgress < 0.5 ? max(0.2, 1 - (compactProgress * 0.5)) : 0
    }

    var backFaceOpacity: Double {
        if isSimulatorShown { return 1 }
        return flipProgress >= 0.5 ? 1 : 0
    }
}

private struct HeroCompactStrip: View {
    let snapshot: HomeHeroSnapshot

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(snapshot.progressLabel)
                .font(.footnoteBold)
                .foregroundStyle(AppColors.textPrimary)

            Capsule()
                .fill(AppColors.overlayWhiteStroke)
                .frame(width: 1, height: 12)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.overlayWhiteStroke)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: AppColors.gradientFire,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * snapshot.progressFraction, height: 3)
                }
            }
            .frame(height: 3)

            Capsule()
                .fill(AppColors.overlayWhiteStroke)
                .frame(width: 1, height: 12)

            Text(snapshot.fireDateLabel)
                .font(.caption)
                .foregroundStyle(AppColors.overlayWhiteOnGlass)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: HomeLayout.heroCompactHeight)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }
}

private struct HeroBackFaceCard: View {
    let snapshot: HomeHeroSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text("ADJUSTED SCENARIO")
                    .font(.miniLabel)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                Spacer(minLength: 0)
                Text(snapshot.progressLabel)
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.accentAmber)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 5)
                    .background(AppColors.warning.opacity(0.14))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Projected FIRE date")
                    .font(.caption)
                    .foregroundStyle(AppColors.overlayWhiteForegroundMuted)
                Text(snapshot.fireDateLabel)
                    .font(.h2)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Rectangle()
                .fill(AppColors.overlayWhiteStroke)
                .frame(height: 1)

            HStack(alignment: .top, spacing: AppSpacing.sm) {
                metricTile(
                    title: "Official path",
                    value: snapshot.fireDateLabel,
                    caption: "locked",
                    tint: AppColors.accentBlueBright
                )
                metricTile(
                    title: "Preview progress",
                    value: snapshot.progressLabel,
                    caption: "sandbox only",
                    tint: AppColors.accentAmber
                )
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    AppColors.backgroundSecondary,
                    AppColors.surface,
                    AppColors.backgroundSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppColors.overlayWhiteStroke,
                            AppColors.accentBlue.opacity(0.35),
                            AppColors.accentAmber.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [AppColors.overlayWhiteMid, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .allowsHitTesting(false)
        }
        .padding(.horizontal, AppSpacing.screenPadding)
    }

    private func metricTile(title: String, value: String, caption: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            Text(value)
                .font(.footnoteSemibold)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.88)

            Text(caption)
                .font(.caption)
                .foregroundStyle(AppColors.overlayWhiteOnGlass)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .padding(AppSpacing.sm)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(0.16),
                    AppColors.overlayWhiteWash
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct HomeHeroSnapshot: Equatable {
    let progressFraction: CGFloat
    let progressLabel: String
    let fireDateLabel: String

    static let empty = HomeHeroSnapshot(
        progressFraction: 0.28,
        progressLabel: "28%",
        fireDateLabel: "Mar 2042"
    )
}

private struct HomeHeroCardHost: View {
    @State private var setupState: HomeSetupStateResponse?
    @State private var homeHero: HomeHeroModel?
    @State private var isLoadingData = false
    @State private var needsReloadAfterCurrentPass = false

    let onHeroUpdated: (HomeHeroSnapshot) -> Void

    @Environment(PlaidManager.self) private var plaidManager

    var body: some View {
        FIRECountdownCard(
            hero: homeHero,
            stage: homeSetupStage,
            onPrimaryAction: { plaidManager.showBudgetSetup = true },
            fixedHeight: HomeLayout.heroFullHeight
        )
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
        .onAppear {
            syncSnapshot(hero: homeHero)
        }
    }
}

private extension HomeHeroCardHost {
    var homeSetupStage: HomeSetupStage {
        if let stage = setupState?.setupStage { return stage }
        return plaidManager.hasLinkedBank ? .accountsLinked : .noGoal
    }

    @MainActor
    func loadData() async {
        if isLoadingData {
            needsReloadAfterCurrentPass = true
            return
        }

        isLoadingData = true
        needsReloadAfterCurrentPass = false

        defer {
            isLoadingData = false
            if needsReloadAfterCurrentPass {
                needsReloadAfterCurrentPass = false
                Task { await loadData() }
            }
        }

        let state = await fetchSetupState()
        if let state {
            setupState = state
        }

        let shouldLoadHero = (state ?? setupState)?.setupStage == .active
        let nextHero = shouldLoadHero ? await fetchHomeHero() : nil
        homeHero = nextHero
        syncSnapshot(hero: nextHero)
    }

    func fetchSetupState() async -> HomeSetupStateResponse? {
        do {
            return try await APIService.shared.getSetupState()
        } catch {
            return nil
        }
    }

    func fetchHomeHero() async -> HomeHeroModel? {
        do {
            return try await APIService.shared.getHomeHero()
        } catch {
            return nil
        }
    }

    func syncSnapshot(hero: HomeHeroModel?) {
        guard let hero else {
            onHeroUpdated(.empty)
            return
        }
        let percent = max(0, min(100, hero.progressPercentage))
        onHeroUpdated(
            HomeHeroSnapshot(
                progressFraction: CGFloat(percent / 100),
                progressLabel: "\(Int(percent.rounded()))%",
                fireDateLabel: hero.displayFireDate ?? "Estimating"
            )
        )
    }
}

private struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                        reportSection(
                            title: "Monthly Reports",
                            icon: "calendar",
                            message: "Your monthly summaries will appear here."
                        )

                        reportSection(
                            title: "Annual Reports",
                            icon: "chart.bar.doc.horizontal",
                            message: "Your annual reviews will appear here."
                        )
                    }
                    .padding(AppSpacing.cardPadding)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.textPrimary)
                        .fontWeight(.semibold)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func reportSection(title: String, icon: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            Text(title.uppercased())
                .font(.miniLabel)
                .foregroundStyle(AppColors.overlayWhiteForegroundMuted)

            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.h4)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(AppColors.overlayWhiteWash)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                Text(message)
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
            )
        }
    }
}

#Preview {
    MainTabView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
