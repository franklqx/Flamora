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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionManager)
                .environment(plaidManager)
        }
    }
}
