//
//  MainTabView.swift
//  Flamora app
//
//  主导航容器 - Home hero + draggable sheet
//

import Foundation
import SwiftUI
internal import Auth

/// Single source of truth for Home shell: sheet vs drag vs full simulator.
private enum HomeState: Equatable {
    /// Sheet visible at rest (default or tall height); `sheetHeight` holds layout.
    case sheet
    /// User is dragging the sheet; `progress` is 0 at default height, 1 when collapsed toward simulator.
    case expanding(progress: CGFloat)
    /// Simulator overlay is visible (sheet removed from hierarchy after transition).
    case simulator
}

/// Home 主列分区：约 1/3 hero + 2/3 白底 sheet（对齐 `home-rebuild-glass-prototype.html`）
private struct HomeLayoutMetrics: Equatable {
    let heroFullHeight: CGFloat
    let sheetDefault: CGFloat
    let sheetTall: CGFloat
    let compactDoneHeight: CGFloat

    /// 固定 pt 回退（首帧 `GeometryReader` 尚未上报高度时与历史布局一致）。
    private init(heroFullHeight: CGFloat, sheetDefault: CGFloat, sheetTall: CGFloat, compactDoneHeight: CGFloat) {
        self.heroFullHeight = heroFullHeight
        self.sheetDefault = sheetDefault
        self.sheetTall = sheetTall
        self.compactDoneHeight = compactDoneHeight
    }

    static let fallback = HomeLayoutMetrics(
        heroFullHeight: AppSpacing.heroFullHeight,
        sheetDefault: 440,
        sheetTall: 620,
        compactDoneHeight: 660
    )

    init(usableHeight: CGFloat) {
        let u = max(400, usableHeight)
        let hero = u * AppSpacing.homeHeroRegionFraction
        let sheet = u * AppSpacing.homeSheetRegionFraction
        let tall = min(sheet * 1.14, u * 0.92)
        self.init(
            heroFullHeight: hero,
            sheetDefault: sheet,
            sheetTall: tall,
            compactDoneHeight: tall + 40
        )
    }
}

private struct HomeViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MainTabView: View {
    @State private var selectedTab: MainTabItem = .home
    @State private var highlightedTab: MainTabItem = .home
    @State private var homeState: HomeState = .sheet
    @State private var simulatorDisplayState: SimulatorDisplayState = .results
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var simulatorTransitionTask: Task<Void, Never>?

    @State private var layoutMetrics = HomeLayoutMetrics.fallback
    @State private var sheetHeight = HomeLayoutMetrics.fallback.sheetDefault
    @State private var sheetDragStartHeight = HomeLayoutMetrics.fallback.sheetDefault
    @State private var isSheetDragging = false

    @State private var heroSnapshot = HomeHeroSnapshot.empty
    @State private var viewportHeight: CGFloat = 0

    /// Shared with `HomeHeroCardHost` for journey strip + hero snapshot (single load path).
    @State private var homeJourneySetupState: HomeSetupStateResponse?
    @State private var homeJourneyHero: HomeHeroModel?

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(PlaidManager.self) private var plaidManager

    private var supportsSimulatorFullScreenBackground: Bool {
        switch selectedTab {
        case .home, .cashflow, .investment:
            return true
        case .settings:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            let simulatorFullScreenActive = supportsSimulatorFullScreenBackground && homeState == .simulator

            shellUnderlay
                .opacity(simulatorFullScreenActive ? 0 : 1)
                .animation(.easeInOut(duration: 0.18), value: simulatorFullScreenActive)

            BrandHeroBackground(
                isInvestTab: selectedTab == .investment,
                gradientHeight: brandGradientDisplayHeight,
                showsBottomShellLift: !simulatorFullScreenActive,
                fillViewport: simulatorFullScreenActive
            )

            HomeHeroCardSurface(
                snapshot: heroSnapshot,
                heroHeight: currentHeroHeight,
                compactProgress: heroCompactProgress,
                isSimulatorShown: homeState == .simulator,
                sheetExpansionProgress: homeState == .simulator
                    ? 1
                    : sheetDragNormalizedProgress(),
                selectedTab: selectedTab,
                setupState: $homeJourneySetupState,
                homeHero: $homeJourneyHero,
                onHeroUpdated: { heroSnapshot = $0 }
            )
            .zIndex(60)

            TopHeaderBar(
                onNotificationTapped: { showNotifications = true },
                onSettingsTapped: openSettingsFromHeader,
                isVisible: true
            )
            .zIndex(80)

            if homeState != .simulator {
                HomeBottomSheet(
                    height: sheetHeight,
                    selectedTab: selectedTab,
                    sheetDragGesture: sheetDragGesture,
                    dragProgress: sheetDragNormalizedProgress()
                )
                .offset(y: -AppSpacing.homeSheetTopOverlap)
                .zIndex(20)
            }

            if homeState == .simulator {
                simulatorOverlay
                    .zIndex(40)
                    .transition(.opacity)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HomeViewportHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HomeViewportHeightKey.self) { h in
            guard h > 0 else { return }
            viewportHeight = h
            let next = HomeLayoutMetrics(usableHeight: h)
            let oldDefault = layoutMetrics.sheetDefault
            if !isSheetDragging, homeState == .sheet {
                if sheetHeight < oldDefault * 0.98 {
                    let ratio = sheetHeight / max(oldDefault, 1)
                    sheetHeight = next.sheetDefault * ratio
                    sheetDragStartHeight = sheetHeight
                } else {
                    sheetHeight = next.sheetDefault
                    sheetDragStartHeight = next.sheetDefault
                }
            }
            layoutMetrics = next
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainTabBarInset(
                selectedTab: $highlightedTab,
                collapseProgress: tabBarCollapseProgress,
                onTabTapped: handleTabTap,
                onCollapsedChromeTap: collapsedChromeTap
            )
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        .fullScreenCover(isPresented: Binding(
            get: { plaidManager.showBudgetSetup },
            set: { plaidManager.showBudgetSetup = $0 }
        ), onDismiss: {
            plaidManager.lastConnectionTime = Date()
            NotificationCenter.default.post(name: .budgetSetupFlowDidDismiss, object: nil)
        }) {
            BudgetSetupView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isEmbeddedInSheet: false)
        }
        .onDisappear {
            simulatorTransitionTask?.cancel()
        }
    }
}

private extension MainTabView {
    /// Full-viewport height for gradient lerp (fallback before first layout pass).
    var homeGradientFullHeight: CGFloat {
        if viewportHeight > 0 { return viewportHeight }
        return layoutMetrics.heroFullHeight + layoutMetrics.sheetDefault
    }

    /// 与 Home 一致：未下拉时渐变仅覆盖 hero 带；下拉/模拟器时铺满。其它 Tab 不再强制全屏渐变，避免与 Home 顶部分层不一致。
    var verticalFillProgress: CGFloat {
        if homeState == .simulator { return 1 }
        return smoothstepSheetProgress(sheetDragNormalizedProgress())
    }

    func smoothstepSheetProgress(_ t: CGFloat) -> CGFloat {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }

    var brandGradientCollapsedHeight: CGFloat {
        max(72, layoutMetrics.heroFullHeight * AppSpacing.homeHeroGradientCollapsedFraction)
    }

    var brandGradientDisplayHeight: CGFloat {
        let collapsed = brandGradientCollapsedHeight
        let full = homeGradientFullHeight
        let p = verticalFillProgress
        return collapsed + (full - collapsed) * p
    }

    var shellUnderlay: some View {
        LinearGradient(
            colors: [AppColors.shellBg1, AppColors.shellBg2],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var simulatorOverlay: some View {
        ZStack(alignment: .top) {
            switch selectedTab {
            case .home:
                HomeExpandedOverlayView(
                    displayState: $simulatorDisplayState,
                    topPadding: TopHeaderBar.height + AppSpacing.lg,
                    onClose: exitSimulator
                )
            case .cashflow:
                CashflowExpandedOverlayView(
                    topPadding: TopHeaderBar.height + AppSpacing.lg,
                    onClose: exitSimulator
                )
            default:
                SimulatorView(
                    displayState: $simulatorDisplayState,
                    bottomPadding: 0,
                    isFireOn: true,
                    onFireToggle: exitSimulator,
                    showResultCard: false,
                    contentTopPadding: TopHeaderBar.height + AppSpacing.lg,
                    useHTMLPrototypeLayout: true,
                    fillsBackground: false
                )
            }
        }
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
                    homeState = .expanding(progress: sheetDragNormalizedProgress())
                }
                .onEnded { value in
                    isSheetDragging = false

                    let draggedDownDistance = value.translation.height
                    let predictedDownDistance = value.predictedEndTranslation.height
                    let shouldSnapToSimulatorByDistance = draggedDownDistance > HomeLayoutConstants.sheetSnapDistanceToSimulator
                    let shouldSnapToSimulatorByMomentum = predictedDownDistance > HomeLayoutConstants.sheetPredictedSnapDistanceToSimulator

                    if sheetHeight < layoutMetrics.sheetDefault * HomeLayoutConstants.sheetToSimulatorThreshold
                        || shouldSnapToSimulatorByDistance
                        || shouldSnapToSimulatorByMomentum {
                        enterSimulator()
                        return
                    }
                    // Sheet 低于默认：收起态不自动回满高，仅吸附到稳定区间（需点左下圆恢复）
                    if sheetHeight < layoutMetrics.sheetDefault * 0.98 {
                        let lo = layoutMetrics.sheetDefault * HomeLayoutConstants.sheetCollapsedMinFraction
                        let hi = layoutMetrics.sheetDefault * HomeLayoutConstants.sheetCollapsedMaxFraction
                        let target = min(max(sheetHeight, lo), hi)
                        withAnimation(HomeLayoutConstants.springAnimation) {
                            sheetHeight = target
                        }
                        homeState = .sheet
                        return
                    }
                    if sheetHeight > layoutMetrics.sheetDefault * 1.15 {
                        withAnimation(HomeLayoutConstants.springAnimation) {
                            sheetHeight = layoutMetrics.sheetTall
                        }
                    } else {
                        withAnimation(HomeLayoutConstants.springAnimation) {
                            sheetHeight = layoutMetrics.sheetDefault
                        }
                    }
                    homeState = .sheet
                }
        )
    }

    /// 0 = sheet at default height, 1 = fully collapsed toward simulator (height 0).
    func sheetDragNormalizedProgress() -> CGFloat {
        guard layoutMetrics.sheetDefault > 0 else { return 0 }
        return max(0, min(1, 1 - (sheetHeight / layoutMetrics.sheetDefault)))
    }

    var currentHeroHeight: CGFloat {
        if homeState == .simulator { return layoutMetrics.heroFullHeight }
        let compactProgress = heroCompactProgress
        return layoutMetrics.heroFullHeight
            - ((layoutMetrics.heroFullHeight - HomeLayoutConstants.heroCompactHeight) * compactProgress)
    }

    var heroCompactProgress: CGFloat {
        guard homeState != .simulator, sheetHeight > layoutMetrics.sheetDefault else { return 0 }
        let denom = layoutMetrics.compactDoneHeight - layoutMetrics.sheetDefault
        guard denom > 0 else { return 0 }
        return max(
            0,
            min(
                1,
                (sheetHeight - layoutMetrics.sheetDefault) / denom
            )
        )
    }

    /// 0 = 三键展开；1 = 仅右侧单圆。仅形态动画，不扩张 Sheet 绘制区；与 `HomeBottomSheet` 不侵入底部安全区配合使用。
    var tabBarCollapseProgress: CGFloat {
        guard homeState != .simulator else { return 1 }
        let distance = layoutMetrics.sheetDefault - sheetHeight
        let threshold = layoutMetrics.sheetDefault * 0.45
        if distance <= 0 { return 0 }
        return max(0, min(1, distance / threshold))
    }

    func clampSheetHeight(_ value: CGFloat) -> CGFloat {
        let absoluteMax = layoutMetrics.sheetTall + 30
        var v = max(0, min(absoluteMax, value))
        if v < layoutMetrics.sheetDefault {
            v = min(v, layoutMetrics.sheetDefault - 1)
        }
        return v
    }

    func restoreSheetFromCollapsed() {
        withAnimation(HomeLayoutConstants.springAnimation) {
            sheetHeight = layoutMetrics.sheetDefault
            sheetDragStartHeight = layoutMetrics.sheetDefault
        }
        homeState = .sheet
    }

    func collapsedChromeTap() {
        if homeState == .simulator {
            exitSimulator()
        } else {
            restoreSheetFromCollapsed()
        }
    }

    func enterSimulator() {
        simulatorTransitionTask?.cancel()
        homeState = .sheet
        withAnimation(HomeLayoutConstants.springAnimation) {
            sheetHeight = 0
        }

        simulatorTransitionTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                simulatorDisplayState = .results
                withAnimation(.easeInOut(duration: 0.16)) {
                    homeState = .simulator
                }
            }
        }
    }

    func exitSimulator() {
        simulatorTransitionTask?.cancel()
        sheetHeight = 0
        withAnimation(.easeInOut(duration: 0.16)) {
            homeState = .sheet
        }
        withAnimation(HomeLayoutConstants.springAnimation) {
            simulatorDisplayState = .results
            sheetHeight = layoutMetrics.sheetDefault
        }
    }

    func handleTabTap(_ tab: MainTabItem) {
        withAnimation(HomeLayoutConstants.springAnimation) {
            selectedTab = tab
            highlightedTab = tab
        }
    }

    func openSettingsFromHeader() {
        if homeState == .simulator {
            exitSimulator()
        } else if sheetHeight < layoutMetrics.sheetDefault * 0.98 {
            restoreSheetFromCollapsed()
        }
        showSettings = true
    }
}

private enum HomeLayoutConstants {
    static let heroCompactHeight: CGFloat = 34
    static let sheetToSimulatorThreshold: CGFloat = 0.72
    static let sheetSnapDistanceToSimulator: CGFloat = 96
    static let sheetPredictedSnapDistanceToSimulator: CGFloat = 150
    static let springAnimation = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// 收起态松手时 sheet 高度吸附区间（相对 `sheetDefault`）
    static let sheetCollapsedMinFraction: CGFloat = 0.32
    static let sheetCollapsedMaxFraction: CGFloat = 0.96
}

private struct HomeBottomSheet: View {
    let height: CGFloat
    let selectedTab: MainTabItem
    let sheetDragGesture: AnyGesture<DragGesture.Value>
    let dragProgress: CGFloat

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
            .overlay(alignment: .center) {
                let labelOpacity = max(0, min(1, (dragProgress - 0.72) / 0.28))
                if labelOpacity > 0 {
                    Text(backLabelText)
                        .font(.footnoteRegular)
                        .foregroundStyle(AppColors.textSecondary)
                        .opacity(labelOpacity)
                        .allowsHitTesting(false)
                }
            }

            Group {
                switch selectedTab {
                case .home:
                    HomeRoadmapContent()
                case .cashflow:
                    CashUnconnectedContent()
                case .investment:
                    InvestUnconnectedContent()
                case .settings:
                    SettingsView(isEmbeddedInSheet: true)
                }
            }
            .id(selectedTab)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [AppColors.shellBg1, AppColors.shellBg2],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .clipShape(
            RoundedRectangle(cornerRadius: AppRadius.xl)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.glassCardBorder, lineWidth: 0.5)
        )
        .shadow(color: AppColors.glassCardShadow, radius: 18, y: -4)
        .frame(maxHeight: .infinity, alignment: .bottom)
        // 不使用 ignoresSafeArea(.bottom)，避免白底 Sheet 绘制到 Tab 栏区域、盖住或「带动」底部栏观感。
    }

    private var backLabelText: String {
        switch selectedTab {
        case .cashflow: return "Back to Cash Flow"
        case .investment: return "Back to Investment"
        default: return "Back to Home"
        }
    }
}

private struct HomeHeroCardSurface: View {
    let snapshot: HomeHeroSnapshot
    let heroHeight: CGFloat
    let compactProgress: CGFloat
    let isSimulatorShown: Bool
    /// 0 = sheet at default; 1 = pulled toward simulator (HTML `.hero-layer` bottom radius eases to 0).
    let sheetExpansionProgress: CGFloat
    let selectedTab: MainTabItem
    @Binding var setupState: HomeSetupStateResponse?
    @Binding var homeHero: HomeHeroModel?
    let onHeroUpdated: (HomeHeroSnapshot) -> Void

    private var heroLayerBottomCornerRadius: CGFloat {
        let p = max(0, min(1, sheetExpansionProgress))
        return max(0, 22 * (1 - p))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // No 3D flip (aligned with HTML: `.hero-summary` stays readable while sheet moves).
            HomeHeroCardHost(
                setupState: $setupState,
                homeHero: $homeHero,
                selectedTab: selectedTab,
                onHeroUpdated: onHeroUpdated
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scaleEffect(
                    x: 1,
                    y: max(0.5, 1 - (compactProgress * 0.5)),
                    anchor: .top
                )
                .opacity(heroContentOpacity)

            if selectedTab == .home, compactProgress > 0.01 && !isSimulatorShown {
                HeroCompactStrip(snapshot: snapshot)
                    .opacity(pow(compactProgress, 1.25))
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.top, 2)
            }
        }
        .frame(height: heroHeight, alignment: .top)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: heroLayerBottomCornerRadius,
                bottomTrailingRadius: heroLayerBottomCornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .padding(.top, TopHeaderBar.height + AppSpacing.md)
    }

    /// Fades only when the full-screen simulator is shown; sheet drag no longer drives a flip that zeroes the front face.
    private var heroContentOpacity: Double {
        if isSimulatorShown { return 0 }
        return max(0.72, 1 - (Double(compactProgress) * 0.22))
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
        .frame(height: HomeLayoutConstants.heroCompactHeight)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.overlayWhiteStroke, lineWidth: 1)
        )
    }
}

/// Drives `.task(id:)` for hero data reloads (same inputs as JourneyView’s trigger).
private struct HeroCardReloadTrigger: Equatable {
    var connectionTime: TimeInterval?
    var hasLinkedBank: Bool
    var savingsPersistGeneration: Int
    var budgetSetupDismissGeneration: Int
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
    @Binding var setupState: HomeSetupStateResponse?
    @Binding var homeHero: HomeHeroModel?

    @State private var isLoadingData = false
    @State private var needsReloadAfterCurrentPass = false
    @State private var savingsCheckInGeneration = 0
    @State private var budgetSetupDismissGeneration = 0

    let selectedTab: MainTabItem
    let onHeroUpdated: (HomeHeroSnapshot) -> Void

    @Environment(PlaidManager.self) private var plaidManager

    private var heroReloadTrigger: HeroCardReloadTrigger {
        HeroCardReloadTrigger(
            connectionTime: plaidManager.lastConnectionTime?.timeIntervalSince1970,
            hasLinkedBank: plaidManager.hasLinkedBank,
            savingsPersistGeneration: savingsCheckInGeneration,
            budgetSetupDismissGeneration: budgetSetupDismissGeneration
        )
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .cashflow:
                TabHeroTitleContent(title: "Cash Flow")
            case .investment:
                TabHeroTitleContent(title: "Investment")
            case .settings:
                TabHeroTitleContent(title: "Settings")
            case .home:
                HomeJourneyProgressStrip.heroEmbedded(stage: homeSetupStage, homeHero: homeHero)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .task(id: heroReloadTrigger) {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .savingsCheckInDidPersist)) { _ in
            savingsCheckInGeneration += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .budgetSetupFlowDidDismiss)) { _ in
            budgetSetupDismissGeneration += 1
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
        await APIService.shared.getSetupStatePersistingCache()
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

// MARK: - Brand Hero Background (HTML: --brand-purple-surface)

private struct BrandHeroBackground: View {
    var isInvestTab: Bool = false
    /// Drawn height; 与 `MainTabView.brandGradientDisplayHeight` 一致（各 Tab 均随 sheet 拖拽渐变，不再单独全屏）。
    var gradientHeight: CGFloat
    /// When false, disable the old shell-lift at the bottom to avoid double white bands during handoff.
    var showsBottomShellLift: Bool = true
    /// When true, use one full-screen background source for simulator expanded state.
    var fillViewport: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let targetHeight = fillViewport
                ? geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                : gradientHeight
            let radialBox = min(w, targetHeight)
            ZStack {
                if isInvestTab {
                    LinearGradient(
                        gradient: AppColors.investBrandLinearGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    // Home + Cash Flow: HTML `.hero-layer` / `.cash-view` (`--brand-purple-surface`)
                    LinearGradient(
                        gradient: AppColors.heroBrandLinearGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                if isInvestTab {
                    // HTML `.invest-view` radial stack (slightly shifted vs Home/Cash)
                    RadialGradient(
                        gradient: Gradient(colors: [AppColors.heroGlowPurple1, .clear]),
                        center: UnitPoint(x: 0.16, y: 0.05),
                        startRadius: 0,
                        endRadius: radialBox * 0.24
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [AppColors.investHeroGlowPurple2, .clear]),
                        center: UnitPoint(x: 0.84, y: 0.12),
                        startRadius: 0,
                        endRadius: radialBox * 0.26
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [AppColors.heroGlowPink, .clear]),
                        center: UnitPoint(x: 0.58, y: 0.56),
                        startRadius: 0,
                        endRadius: radialBox * 0.28
                    )
                } else {
                    // Home + Cash Flow: HTML `--brand-purple-surface` radials
                    RadialGradient(
                        gradient: Gradient(colors: [AppColors.heroGlowPurple1, .clear]),
                        center: UnitPoint(x: 0.18, y: 0.06),
                        startRadius: 0,
                        endRadius: radialBox * 0.24
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [AppColors.heroGlowPurple2, .clear]),
                        center: UnitPoint(x: 0.82, y: 0.14),
                        startRadius: 0,
                        endRadius: radialBox * 0.26
                    )
                    RadialGradient(
                        gradient: Gradient(colors: [AppColors.heroGlowPink, .clear]),
                        center: UnitPoint(x: 0.56, y: 0.58),
                        startRadius: 0,
                        endRadius: radialBox * 0.28
                    )
                }

                if showsBottomShellLift {
                    VStack {
                        Spacer(minLength: 0)
                        LinearGradient(
                            colors: [Color.clear, AppColors.shellBg1.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: min(AppSpacing.xs, targetHeight * 0.022))
                    }
                    .frame(height: targetHeight)
                }
            }
            .frame(width: w, height: targetHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .frame(maxHeight: fillViewport ? .infinity : gradientHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
        // 与 `shellUnderlay` 的浅色顶区分开：让品牌渐变铺满状态栏/灵动岛区域，避免顶部一条「白边」
        .ignoresSafeArea(edges: fillViewport ? .all : .top)
    }
}

// MARK: - Tab hero title (HTML: `.cash-hero-copy h1` / `.invest-hero-copy h1`)

private struct TabHeroTitleContent: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.h1)
            .foregroundStyle(AppColors.heroTextPrimary)
            .tracking(-0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.heroTabTitleTopOffset)
    }
}

// MARK: - Home Roadmap Content (HTML: .roadmap with 3 steps)

private struct HomeRoadmapContent: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                roadmapCard
                    .padding(.horizontal, AppSpacing.screenPadding)

                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.top, AppSpacing.cardGap)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What happens next")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkFaint)
                .tracking(AppTypography.Tracking.cardHeader)
                .textCase(.uppercase)
                .padding(.bottom, AppSpacing.sm)

            Text("Three steps to unlock Home.")
                .font(.h3)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(-0.5)
                .padding(.bottom, AppSpacing.md)

            VStack(spacing: 0) {
                roadmapStep(
                    index: 1,
                    isCurrent: true,
                    title: "Set your FIRE goal",
                    detail: "Tell Flamora what future you're aiming for."
                )
                roadmapStep(
                    index: 2,
                    isCurrent: false,
                    title: "Connect your accounts",
                    detail: "Bring in your real numbers when you're ready."
                )
                roadmapStep(
                    index: 3,
                    isCurrent: false,
                    title: "Choose your path",
                    detail: "Apply the version of FIRE that fits your life.",
                    isLast: true
                )
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .fill(AppColors.glassCardBg)
                .shadow(color: AppColors.glassCardShadow, radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassPanel)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .frame(minHeight: AppSpacing.homeSheetPrimaryCardMinHeight, alignment: .top)
    }

    private func roadmapStep(index: Int, isCurrent: Bool, title: String, detail: String, isLast: Bool = false) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(isCurrent ? AppColors.inkPrimary : AppColors.inkPrimary.opacity(0.06))
                    .frame(width: 32, height: 32)
                Text("\(index)")
                    .font(.smallLabel)
                    .foregroundStyle(isCurrent ? AppColors.ctaWhite : AppColors.inkSoft)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.inkSoft)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .strokeBorder(AppColors.inkBorder, lineWidth: 1)
                    .background(Circle().fill(AppColors.ctaWhite))
                    .frame(width: 34, height: 34)
                Image(systemName: "chevron.right")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.inkPrimary.opacity(0.54))
            }
        }
        .padding(.vertical, AppSpacing.rowItem)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AppColors.inkDivider)
                    .frame(height: 1)
            }
        }
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

// MARK: - Cash Unconnected Content (HTML: .cash-view unconnected state)

private struct CashUnconnectedContent: View {
    @Environment(PlaidManager.self) private var plaidManager
    @State private var showTrustBridge = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.cardGap) {
                CashflowSpendingOverviewPrototypeCard()
                connectCTAButton(label: "Connect accounts") {
                    if plaidManager.shouldShowTrustBridge() {
                        showTrustBridge = true
                    } else {
                        Task { await plaidManager.startLinkFlow() }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.cardGap)
            .padding(.bottom, AppSpacing.xl)
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
    }
}

// MARK: - Invest Unconnected Content (HTML: .invest-view unconnected state)

private enum InvestTimeRange: String, CaseIterable, Hashable {
    case w1 = "1W"
    case m1 = "1M"
    case m3 = "3M"
    case ytd = "YTD"
    case all = "ALL"
}

/// HTML prototype: total net worth, line trend, range pills, count-up on appear / tap.
private struct InvestNetWorthPrototypeCard: View {
    @State private var selectedRange: InvestTimeRange = .m1
    @State private var displayedNetWorth: Double = 0

    private let targetNetWorth: Double = 210_150
    private let changePercent: Double = 13.8
    private let linePoints: [CGFloat] = [0.22, 0.28, 0.25, 0.35, 0.42, 0.48, 0.55, 0.62, 0.68, 0.75, 0.82, 0.88, 0.95]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("TOTAL NET WORTH")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkMeta)
                .tracking(AppTypography.Tracking.cardHeader)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(NumberFormatter.appCurrency(displayedNetWorth))
                    .font(.currencyHero)
                    .foregroundStyle(AppColors.inkPrimary)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                Text("+\(String(format: "%.1f", changePercent))%")
                    .font(.footnoteSemibold)
                    .foregroundStyle(AppColors.success)
            }

            investLineChart(points: linePoints)
                .frame(height: 72)

            investRangePills

            Text("Track all your investments in one place.")
                .font(.caption)
                .foregroundStyle(AppColors.inkSoft)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.glassCard)
                .fill(AppColors.glassCardBg)
                .shadow(color: AppColors.glassCardShadow, radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.glassCard)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
        .frame(minHeight: AppSpacing.homeSheetPrimaryCardMinHeight, alignment: .top)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.glassCard))
        .onTapGesture { replayCountUp() }
        .onAppear { runInitialCountUp() }
    }

    private var investRangePills: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(InvestTimeRange.allCases, id: \.self) { range in
                Text(range.rawValue)
                    .font(.smallLabel)
                    .foregroundStyle(selectedRange == range ? AppColors.inkPrimary : AppColors.inkSoft)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .fill(selectedRange == range ? AppColors.inkPrimary.opacity(0.08) : AppColors.overlayWhiteWash)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(selectedRange == range ? AppColors.inkBorder : AppColors.inkDivider, lineWidth: 0.75)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedRange = range
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func investLineChart(points: [CGFloat]) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = points.count
            ZStack {
                Path { path in
                    guard count > 1 else { return }
                    for (i, p) in points.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(count - 1)
                        let y = h - p * h * 0.9 - 4
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    AppColors.inkPrimary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                if let last = points.last, count > 0 {
                    let x = w
                    let y = h - last * h * 0.9 - 4
                    Circle()
                        .fill(AppColors.inkPrimary)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private func runInitialCountUp() {
        displayedNetWorth = 0
        withAnimation(.easeOut(duration: 0.85)) {
            displayedNetWorth = targetNetWorth
        }
    }

    private func replayCountUp() {
        if displayedNetWorth >= targetNetWorth - 1 {
            displayedNetWorth = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.easeOut(duration: 0.85)) {
                    displayedNetWorth = targetNetWorth
                }
            }
        } else {
            withAnimation(.easeOut(duration: 0.85)) {
                displayedNetWorth = targetNetWorth
            }
        }
    }
}

private struct InvestUnconnectedContent: View {
    @Environment(PlaidManager.self) private var plaidManager
    @State private var showTrustBridge = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.cardGap) {
                InvestNetWorthPrototypeCard()
                connectCTAButton(label: "Connect accounts") {
                    if plaidManager.shouldShowTrustBridge() {
                        showTrustBridge = true
                    } else {
                        Task { await plaidManager.startLinkFlow() }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.cardGap)
            .padding(.bottom, AppSpacing.xl)
        }
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
    }
}

// MARK: - Shared Unconnected Helpers

private func connectCTAButton(label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.sheetPrimaryButton)
            .foregroundStyle(AppColors.ctaWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(AppColors.ctaBlack)
                    .shadow(color: AppColors.glassCardShadow, radius: 16, y: 8)
            )
    }
    .buttonStyle(.plain)
}

// MARK: - Bottom tab (safeAreaInset slot)

/// 贴在底部安全区；`collapseProgress` 仅驱动 `GlassmorphicTabBar` 形态，Sheet 不得 ignoresSafeArea(.bottom) 以免盖住 Tab。
private struct MainTabBarInset: View {
    @Binding var selectedTab: MainTabItem
    var collapseProgress: CGFloat
    let onTabTapped: (MainTabItem) -> Void
    let onCollapsedChromeTap: () -> Void

    var body: some View {
        GlassmorphicTabBar(
            selectedTab: $selectedTab,
            collapseProgress: collapseProgress,
            onTabTapped: onTabTapped,
            onCollapsedChromeTap: onCollapsedChromeTap
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    MainTabView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
