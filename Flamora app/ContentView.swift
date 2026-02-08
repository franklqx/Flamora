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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
    }

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
