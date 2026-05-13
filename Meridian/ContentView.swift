//
//  ContentView.swift
//  Meridian
//
//  Created by Frank Li on 2/3/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isOnboardingComplete = false
    @State private var lockedRootSize: CGSize = .zero
    @State private var bridgeOpacity: CGFloat = 0
    @State private var bridgeVisible = false
    @AppStorage("hasCompletedOnboardingV2") private var hasCompletedOnboarding = false  // key 保留兼容已完程用户

    // 观察 SupabaseManager 的 auth 状态
    private let supabase = SupabaseManager.shared
    private var forcesMainTabsForUITests: Bool {
        ProcessInfo.processInfo.environment["FLAMORA_PLAID_UNCONNECTED"] == "1"
    }

    var body: some View {
        GeometryReader { proxy in
            let currentSize = proxy.size
            let displaySize = effectiveDisplaySize(for: currentSize)

            ZStack {
                if forcesMainTabsForUITests || (isOnboardingComplete && hasCompletedOnboarding) {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    OB_ContainerView(isOnboardingComplete: $isOnboardingComplete)
                        .transition(.opacity)
                }

                if bridgeVisible {
                    OB_TransitionBridgeView(progress: bridgeOpacity)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .frame(width: displaySize.width, height: displaySize.height, alignment: .top)
            .onAppear {
                updateLockedRootSize(with: currentSize)
            }
            .onChange(of: currentSize) { _, newSize in
                updateLockedRootSize(with: newSize)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isOnboardingComplete)
        .onChange(of: isOnboardingComplete) { oldValue, newValue in
            if !oldValue && newValue {
                startTransitionBridge()
            } else if oldValue && !newValue {
                bridgeVisible = false
                bridgeOpacity = 0
            }
        }
        .ignoresSafeArea(.keyboard, edges: .all)
        // Plaid Link 通过 PlaidLinkPresenter（UIWindow overlay）呈现，无 SwiftUI sheet。
        // Paywall: 每个触发点（Settings / BudgetSetup）在自己的 view 里挂本地
        // `.fullScreenCover { PaywallScreen(...) }` —— fullScreenCover 能叠在
        // 已展开的 sheet 之上，避免之前 sheet-over-sheet 阻塞导致的"点 Upgrade 没反应"问题。
        // 检查现有 session（已登录 → 直接进主应用）l
        .task { await checkExistingSession() }
        // 持续监听 auth 状态变化（退出登录时回到 onboarding）
        // 使用 .task 让 SwiftUI 自动管理 Task 生命周期
        .task { await listenForAuthChanges() }
        // 监听退出登录：isAuthenticated 变 false → 回到 onboarding
        .onChange(of: supabase.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated && isOnboardingComplete {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isOnboardingComplete = false
                }
                hasCompletedOnboarding = false
            }
        }
    }

    // MARK: - 启动时检查现有 session
    // 必须同时满足：已登录 AND 已完成 Onboarding，才跳过 Onboarding 进入主界面
    // 防止用户在 Step 1 注册后重启 App 时直接跳过剩余 10 个步骤

    private func checkExistingSession() async {
        await supabase.checkSession()
        if supabase.isAuthenticated && hasCompletedOnboarding {
            withAnimation(.easeInOut(duration: 0.5)) {
                isOnboardingComplete = true
            }
            // Warm Home / Cashflow / Investment caches in parallel. By the
            // time the user lands on (or switches into) any tab, the cached
            // values are already populated — eliminating the "blank → fetch
            // → content" flash that made the app feel sluggish.
            AppDataPreloader.warmAllTabs()
        }
    }

    // MARK: - 持续监听 auth 状态（Task 内无限循环）

    private func listenForAuthChanges() async {
        await supabase.listenToAuthChanges()
    }

    // MARK: - Display Size Helpers

    private func effectiveDisplaySize(for currentSize: CGSize) -> CGSize {
        guard lockedRootSize != .zero else { return currentSize }
        let widthChanged = abs(currentSize.width - lockedRootSize.width) > 1
        if widthChanged {
            return currentSize
        }
        return CGSize(width: currentSize.width, height: max(currentSize.height, lockedRootSize.height))
    }

    private func updateLockedRootSize(with newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        if lockedRootSize == .zero {
            lockedRootSize = newSize
            return
        }

        let widthChanged = abs(newSize.width - lockedRootSize.width) > 1
        if widthChanged {
            lockedRootSize = newSize
            return
        }

        if newSize.height > lockedRootSize.height {
            lockedRootSize = newSize
        }
    }

    // MARK: - Welcome -> Home Bridge

    private func startTransitionBridge() {
        bridgeVisible = true
        bridgeOpacity = 0

        withAnimation(.easeInOut(duration: 0.5)) {
            bridgeOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            bridgeVisible = false
            bridgeOpacity = 0
        }
    }
}

#Preview {
    ContentView()
        .environment(SubscriptionManager.shared)
        .environment(PlaidManager.shared)
}

private struct OB_TransitionBridgeView: View {
    let progress: CGFloat

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .opacity(0.22 * Double(1 - progress))

            LinearGradient(
                colors: [AppColors.backgroundPrimary, AppColors.shellBg1, AppColors.shellBg2],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(Double(progress))
        }
        .ignoresSafeArea()
    }
}
