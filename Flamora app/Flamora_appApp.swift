//
//  Flamora_appApp.swift
//  Flamora app
//
//  Created by Frank Li on 2/2/26.
//

import SwiftUI
import CoreText
import RevenueCat
import UIKit

@main
struct Flamora_appApp: App {

    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var plaidManager = PlaidManager.shared

    init() {
        Self.registerFonts()
        UIWindow.appearance().backgroundColor = UIColor(AppColors.backgroundPrimary)
        UIScrollView.appearance().delaysContentTouches = false
        Self.configureTabBarAppearance()
        SubscriptionManager.configure()
    }

    /// 手动注册 bundle 内的自定义字体
    private static func registerFonts() {
        let fontNames = [
            "Montserrat-Bold",
            "PlayfairDisplay-Variable",
            "PlayfairDisplay-Italic-Variable",
            "CormorantGaramond-Regular",
            "CormorantGaramond-Bold",
            "CormorantGaramond-Italic",
            "EBGaramond-Variable",
            "EBGaramond-Italic-Variable",
        ]
        for name in fontNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    /// Force a consistent light Liquid Glass tab bar across all tabs.
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.30)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.20)

        let activeColor = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 0.95)
        let inactiveColor = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 0.62)

        let states: [UITabBarItemAppearance] = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ]
        for state in states {
            state.normal.iconColor = inactiveColor
            state.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
            state.selected.iconColor = activeColor
            state.selected.titleTextAttributes = [.foregroundColor: activeColor]
        }

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
        tabBar.tintColor = activeColor
        tabBar.unselectedItemTintColor = inactiveColor
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionManager)
                .environment(plaidManager)
        }
    }
}
