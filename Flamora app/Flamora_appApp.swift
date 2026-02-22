//
//  Flamora_appApp.swift
//  Flamora app
//
//  Created by Frank Li on 2/2/26.
//

import SwiftUI
import SwiftData
import CoreText
import RevenueCat

@main
struct Flamora_appApp: App {

    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var plaidManager = PlaidManager.shared

    init() {
        Self.registerFonts()
        UIWindow.appearance().backgroundColor = .clear
        SubscriptionManager.configure()
    }

    /// 手动注册 bundle 内的自定义字体
    private static func registerFonts() {
        guard let fontURL = Bundle.main.url(forResource: "Montserrat-Bold", withExtension: "ttf", subdirectory: "Fonts") else {
            // 尝试不带子目录
            if let url = Bundle.main.url(forResource: "Montserrat-Bold", withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
            return
        }
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionManager)
                .environment(plaidManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
