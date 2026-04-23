//
//  MainTabView.swift
//  Flamora app
//
//  主导航容器 - Home hero + draggable sheet
//

import Foundation
import SwiftUI
internal import Auth

/// Single source of truth for Home shell: sheet vs full simulator.
private enum HomeState: Equatable {
    /// Sheet visible (default, or being dragged — `sheetHeight` holds layout).
    case sheet
    /// Simulator overlay is visible (sheet removed from hierarchy after transition).
    case simulator
}

/// Home 主列分区：约 1/3 hero + 2/3 白底 sheet（对齐 `home-rebuild-glass-prototype.html`）
private struct HomeLayoutMetrics: Equatable {
    let heroFullHeight: CGFloat
    let sheetDefault: CGFloat
    let sheetTall: CGFloat
    let compactDoneHeight: CGFloat
    private static let unifiedSheetDefaultHeight: CGFloat = 555

    /// 固定 pt 回退（首帧 `GeometryReader` 尚未上报高度时与历史布局一致）。
    private init(heroFullHeight: CGFloat, sheetDefault: CGFloat, sheetTall: CGFloat, compactDoneHeight: CGFloat) {
        self.heroFullHeight = heroFullHeight
        self.sheetDefault = sheetDefault
        self.sheetTall = sheetTall
        self.compactDoneHeight = compactDoneHeight
    }

    static let fallback = HomeLayoutMetrics(
        heroFullHeight: AppSpacing.heroFullHeight,
        sheetDefault: unifiedSheetDefaultHeight,
        sheetTall: 620,
        compactDoneHeight: 660
    )

    init(usableHeight: CGFloat) {
        let u = max(400, usableHeight)
        let hero = u * AppSpacing.homeHeroRegionFraction
        let sheet = Self.unifiedSheetDefaultHeight
        let tall = min(sheet * 1.14, u * 0.92)
        self.init(
            heroFullHeight: hero,
            sheetDefault: sheet,
            sheetTall: tall,
            compactDoneHeight: tall + 40
        )
    }
}

private struct HomeViewportMetrics: Equatable {
    let height: CGFloat
    let safeAreaBottom: CGFloat
}

private struct HomeViewportHeightKey: PreferenceKey {
    static var defaultValue: HomeViewportMetrics = .init(height: 0, safeAreaBottom: 0)
    static func reduce(value: inout HomeViewportMetrics, nextValue: () -> HomeViewportMetrics) {
        value = nextValue()
    }
}

struct MainTabView: View {
    @State private var selectedTab: MainTabItem = .home
    @State private var homeState: HomeState = .sheet
    @State private var simulatorDisplayState: SimulatorDisplayState = .results
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var simulatorTransitionTask: Task<Void, Never>?

    @State private var layoutMetrics = HomeLayoutMetrics.fallback
    @State private var sheetHeight = HomeLayoutMetrics.fallback.sheetDefault
    @State private var sheetDragStartHeight = HomeLayoutMetrics.fallback.sheetDefault
    @State private var isSheetDragging = false
    /// 仅用于「点收拢圆钮恢复 sheet」：先整体偏下，再与高度动画同步归零，观感为自下而上托起。
    @State private var sheetRestoreRiseOffset: CGFloat = 0

    @State private var heroSnapshot = HomeHeroSnapshot.empty
    @State private var viewportHeight: CGFloat = 0
    @State private var viewportSafeAreaBottom: CGFloat = 0

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
        ZStack(alignment: .bottom) {
            shellContent

            // 悬浮 Liquid Glass Tab Bar — 永远在最顶层（底部间距见 tabBarBottomPadding）
            LiquidGlassTabBar(
                selectedTab: $selectedTab,
                collapseProgress: sheetDragNormalizedProgress(),
                onTabTapped: { selectedTab = $0 },
                onCollapsedChromeTap: restoreSheetFromCollapsed
            )
            .padding(.bottom, tabBarBottomPadding)
            .zIndex(200)
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        .ignoresSafeArea(edges: .bottom)
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

    private var shellContent: some View {
        ZStack(alignment: .top) {
            let simulatorFullScreenActive = supportsSimulatorFullScreenBackground && homeState == .simulator

            // 全屏壳渐变：只作最底层背景（zIndex 低于 sheet），叠在 sheet「后面」，不盖在 sheet 上面。
            shellUnderlay
                .opacity(simulatorFullScreenActive ? 0 : 1)
                .animation(.easeInOut(duration: 0.18), value: simulatorFullScreenActive)
                .zIndex(-1)

            BrandHeroBackground(
                isInvestTab: selectedTab == .investment && !simulatorFullScreenActive,
                gradientHeight: brandGradientDisplayHeight,
                fillViewport: simulatorFullScreenActive
            )
            .zIndex(0)

            // 勿在此处再叠一层实色底（例如整块 `shellBg2` Rectangle + 高 zIndex）：
            // `GlassmorphicTabBar` 的 `glassEffect` 会采样其后方内容；若 Tab 与 Home Indicator
            // 之间只有均一亮灰，液态玻璃会看起来像整块发白。底部视觉由 `shellUnderlay` + `BrandHeroBackground`（及 Sheet）承担即可。

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
                let sheetBottomExtension = max(0, AppSpacing.homeSheetTopOverlap - AppSpacing.md - 2)
                // 固定 sheet 帧高为 default，靠 `.offset` 下移来模拟「收起」。
                // 好处：拖动时不触发布局重算、阴影不必随帧重绘 → 1:1 跟手，不会再慢半拍。
                let sheetDragDown = max(0, layoutMetrics.sheetDefault - sheetHeight)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HomeBottomSheet(
                        contentHeight: layoutMetrics.sheetDefault + HomeLayoutConstants.sheetTopCoverLift,
                        bottomInset: viewportSafeAreaBottom + 2 + sheetBottomExtension,
                        selectedTab: selectedTab,
                        sheetDragGesture: sheetDragGesture,
                        dragProgress: sheetDragNormalizedProgress()
                    )
                    .offset(y: sheetDragDown + sheetRestoreRiseOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
                .zIndex(20)
            }

            // 保持 overlay 常驻（仅切换可见性），避免每次下拉进入时因重建视图而重复加载数据。
            simulatorOverlay
                .opacity(homeState == .simulator ? 1 : 0)
                .allowsHitTesting(homeState == .simulator)
                .zIndex(40)
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HomeViewportHeightKey.self,
                    value: .init(height: geo.size.height, safeAreaBottom: geo.safeAreaInsets.bottom)
                )
            }
        )
        .onPreferenceChange(HomeViewportHeightKey.self) { metrics in
            guard metrics.height > 0 else { return }
            viewportHeight = metrics.height
            viewportSafeAreaBottom = metrics.safeAreaBottom
            let next = HomeLayoutMetrics(usableHeight: metrics.height)
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
        .ignoresSafeArea(edges: .bottom)
    }

}

private extension MainTabView {
    /// 浮动 Tab bar 与物理底边距离：略贴近系统 Liquid Glass；sheet 收起（collapse 大）时再略下移。
    var tabBarBottomPadding: CGFloat {
        let p = sheetDragNormalizedProgress()
        let safe = viewportSafeAreaBottom
        let base = max(20, safe - 6)
        return max(16, base - 10 * p)
    }

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

    /// 主壳全屏浅色底，始终画在 `HomeBottomSheet` / Hero 等下层（见 `shellContent` 内 `.zIndex(-1)`）。
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
            case .investment:
                InvestmentExpandedOverlayView(
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
            // minimumDistance: 0 → 手指落下即跟随，1:1 跟手。纯 tap 因为 translation = 0 不会改高度，也不会闪动。
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isSheetDragging {
                        isSheetDragging = true
                        sheetDragStartHeight = sheetHeight
                        sheetRestoreRiseOffset = 0
                    }
                    let translation = max(0, value.translation.height)
                    // 只写 sheetHeight；homeState 不在每帧更新（避免 enum associated value 每帧触发全树 diff）。
                    sheetHeight = clampSheetHeight(sheetDragStartHeight - translation)
                }
                .onEnded { value in
                    isSheetDragging = false

                    // 任何下拉（>4pt 忽略手指落下瞬间的抖动）即 commit 到 simulator，不设位置阈值。
                    if value.translation.height > 4 {
                        enterSimulator()
                    } else {
                        // 上拉或原地松手 → 橡皮筋弹回默认。
                        homeState = .sheet
                        withAnimation(HomeLayoutConstants.springAnimation) {
                            sheetHeight = layoutMetrics.sheetDefault
                            sheetDragStartHeight = layoutMetrics.sheetDefault
                            sheetRestoreRiseOffset = 0
                        }
                    }
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

    func clampSheetHeight(_ value: CGFloat) -> CGFloat {
        let absoluteMax = layoutMetrics.sheetDefault
        var v = max(0, min(absoluteMax, value))
        if v < layoutMetrics.sheetDefault {
            v = min(v, layoutMetrics.sheetDefault - 1)
        }
        return v
    }

    func restoreSheetFromCollapsed() {
        homeState = .sheet
        let rise = HomeLayoutConstants.sheetRestoreRiseDistance
        let needsRiseMotion = sheetHeight < layoutMetrics.sheetDefault * 0.98
        if needsRiseMotion {
            // 先摆到略偏下（同一帧不带动画），下一帧再与高度一起弹回，形成「自下而上」升起。
            sheetRestoreRiseOffset = rise
            DispatchQueue.main.async {
                withAnimation(HomeLayoutConstants.springRestoreExpand) {
                    sheetHeight = layoutMetrics.sheetDefault
                    sheetDragStartHeight = layoutMetrics.sheetDefault
                    sheetRestoreRiseOffset = 0
                }
            }
        } else {
            withAnimation(HomeLayoutConstants.springRestoreExpand) {
                sheetHeight = layoutMetrics.sheetDefault
                sheetDragStartHeight = layoutMetrics.sheetDefault
                sheetRestoreRiseOffset = 0
            }
        }
    }

    func enterSimulator() {
        simulatorTransitionTask?.cancel()
        homeState = .sheet
        sheetRestoreRiseOffset = 0
        withAnimation(HomeLayoutConstants.sheetCollapseAnimation) {
            sheetHeight = 0
        }

        simulatorTransitionTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                simulatorDisplayState = .results
                withAnimation(.easeInOut(duration: 0.14)) {
                    homeState = .simulator
                }
            }
        }
    }

    func exitSimulator() {
        simulatorTransitionTask?.cancel()
        sheetHeight = 0
        sheetRestoreRiseOffset = 0
        withAnimation(.easeInOut(duration: 0.16)) {
            homeState = .sheet
        }
        withAnimation(HomeLayoutConstants.springAnimation) {
            simulatorDisplayState = .results
            sheetHeight = layoutMetrics.sheetDefault
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
    static let springAnimation = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Sheet 下滑进 simulator 的动画：更快、更干脆，避免「卡」感。
    static let sheetCollapseAnimation = Animation.spring(response: 0.28, dampingFraction: 0.88)
    /// 点击收拢圆钮恢复 sheet：略慢、略阻尼，观感上像从下往上托起 + Tab 自右向左展开（与下拉收拢相反）。
    static let springRestoreExpand = Animation.spring(response: 0.52, dampingFraction: 0.86)
    /// 点收拢圆钮恢复时 sheet 先下移的 pt，再弹回 0，与高度动画叠加成自下而上托起。
    static let sheetRestoreRiseDistance: CGFloat = 120
    /// 白底 sheet 向上多盖一截，避免壳底在 sheet 顶缘露出一条线。
    static let sheetTopCoverLift: CGFloat = 18
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
            }
            .frame(width: w, height: targetHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .frame(maxHeight: fillViewport ? .infinity : gradientHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
        // 与最底层 `shellUnderlay` 的浅色顶区分开：让品牌渐变铺满状态栏/灵动岛区域，避免顶部一条「白边」
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

private struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recentReports: [ReportFeedItem] = []
    @State private var selectedReport: ReportSnapshot? = nil
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.shellBg1, AppColors.shellBg2],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                        if isLoading && recentReports.isEmpty {
                            loadingCard
                        } else if recentReports.isEmpty {
                            emptyCard
                        } else {
                            unreadSection
                            recentSection
                        }
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
                        .foregroundStyle(AppColors.inkPrimary)
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            await loadRecentReports()
        }
        .fullScreenCover(item: $selectedReport, onDismiss: {
            Task { await loadRecentReports() }
        }) { report in
            reportDestination(for: report)
        }
    }

    private var unreadSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            Text("NEW REPORTS")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            cardContainer {
                let unread = recentReports.filter(\.isUnread)
                if unread.isEmpty {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.figureSecondarySemibold)
                            .foregroundStyle(AppColors.success)

                        Text("You're caught up. New reports will land here first.")
                            .font(.footnoteRegular)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPadding)
                } else {
                    ForEach(Array(unread.enumerated()), id: \.element.id) { index, item in
                        ReportFeedRow(item: item) {
                            Task { await openReport(id: item.reportId) }
                        }

                        if index < unread.count - 1 {
                            divider
                        }
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionLabelGap) {
            Text("RECENT")
                .font(.cardHeader)
                .foregroundStyle(AppColors.inkPrimary)
                .tracking(AppTypography.Tracking.cardHeader)

            cardContainer {
                let recent = recentReports.filter { !$0.isUnread }
                if recent.isEmpty {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "clock")
                            .font(.figureSecondarySemibold)
                            .foregroundStyle(AppColors.inkSoft)

                        Text("Viewed reports will stay here for quick access.")
                            .font(.footnoteRegular)
                            .foregroundStyle(AppColors.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.cardPadding)
                } else {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                        ReportFeedRow(item: item) {
                            Task { await openReport(id: item.reportId) }
                        }

                        if index < recent.count - 1 {
                            divider
                        }
                    }
                }
            }
        }
    }

    private var loadingCard: some View {
        cardContainer {
            HStack(spacing: AppSpacing.md) {
                ProgressView()
                    .tint(AppColors.inkPrimary)
                Text("Loading recent reports...")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
        }
    }

    private var emptyCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("No reports yet")
                    .font(.inlineLabel)
                    .foregroundStyle(AppColors.inkPrimary)

                Text("Your latest weekly, monthly, and annual stories will appear here once they are generated.")
                    .font(.footnoteRegular)
                    .foregroundStyle(AppColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.inkDivider)
            .frame(height: 0.5)
            .padding(.leading, 58)
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.glassCardBorder, lineWidth: 1)
        )
    }

    private func loadRecentReports() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            recentReports = try await APIService.shared.getRecentReports()
        } catch {
            recentReports = []
        }
    }

    private func openReport(id: String) async {
        do {
            selectedReport = try await APIService.shared.getReportDetail(id: id)
            await loadRecentReports()
        } catch {
            #if DEBUG
            print("❌ [NotificationsView] failed to open report: \(error)")
            #endif
        }
    }

    @ViewBuilder
    private func reportDestination(for report: ReportSnapshot) -> some View {
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

// MARK: - Cash Unconnected Content (HTML: .cash-view unconnected state)

struct CashUnconnectedContent: View {
    @Environment(PlaidManager.self) private var plaidManager
    @State private var showTrustBridge = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.cardGap) {
                CashflowSpendingOverviewPrototypeCard()
                SheetPrimaryCTAButton(label: "Connect accounts") {
                    if plaidManager.shouldShowTrustBridge() {
                        showTrustBridge = true
                    } else {
                        Task { await plaidManager.startLinkFlow() }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.top, AppSpacing.cardGap)
            .padding(.bottom, AppSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showTrustBridge, onDismiss: {
            if UserDefaults.standard.bool(forKey: AppLinks.plaidTrustBridgeSeen) {
                Task { await plaidManager.startLinkFlow() }
            }
        }) {
            PlaidTrustBridgeView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}
