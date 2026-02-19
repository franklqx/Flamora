//
//  ContentView.swift
//  Flamora app
//
//  Created by Frank Li on 2/3/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showSplash = true
    @State private var isOnboardingComplete = false
    @State private var lockedRootSize: CGSize = .zero

    // 观察 SupabaseManager 的 auth 状态
    private let supabase = SupabaseManager.shared

    var body: some View {
        GeometryReader { proxy in
            let currentSize = proxy.size
            let displaySize = effectiveDisplaySize(for: currentSize)

            ZStack {
                if isOnboardingComplete {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    OnboardingContainerView(isOnboardingComplete: $isOnboardingComplete)
                        .transition(.opacity)
                }

                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
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
        .ignoresSafeArea(.keyboard, edges: .all)
        .onAppear {
            // Splash 2 秒后消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
            // 检查现有 session（已登录 → 直接进主应用）
            Task { await checkExistingSession() }
            // 持续监听 auth 状态变化（退出登录时回到 onboarding）
            Task { await listenForAuthChanges() }
        }
        // 监听退出登录：isAuthenticated 变 false → 回到 onboarding
        .onChange(of: supabase.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated && isOnboardingComplete {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isOnboardingComplete = false
                }
            }
        }
    }

    // MARK: - 启动时检查现有 session

    private func checkExistingSession() async {
        await supabase.checkSession()
        if supabase.isAuthenticated {
            withAnimation(.easeInOut(duration: 0.5)) {
                isOnboardingComplete = true
            }
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
}

#Preview {
    ContentView()
}
