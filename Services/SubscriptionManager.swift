//
//  SubscriptionManager.swift
//  Flamora app
//
//  RevenueCat 订阅状态管理
//

import Foundation
import RevenueCat

@Observable
class SubscriptionManager {
    static let shared = SubscriptionManager()

    var isPremium: Bool = false
    var showPaywall: Bool = false

    private let entitlementId = "Flamora Pro"

    private init() {}

    // MARK: - App 启动时调用
    static func configure() {
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
    }

    // MARK: - 检查订阅状态
    func checkStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements[entitlementId]?.isActive == true
            #if DEBUG
            print("🔍 [SubscriptionManager] checkStatus — isPremium=\(isPremium)")
            #endif
        } catch {
            #if DEBUG
            print("🔍 [SubscriptionManager] checkStatus error: \(error)")
            #endif
            isPremium = false
        }
    }

    // MARK: - 登录后关联 RevenueCat 用户
    func loginUser(userId: String) async {
        do {
            _ = try await Purchases.shared.logIn(userId)
            await checkStatus()
        } catch {
            #if DEBUG
            print("🔍 [SubscriptionManager] loginUser error: \(error)")
            #endif
        }
    }

    // MARK: - 登出时清除 RevenueCat 状态
    func logoutUser() {
        Task {
            do {
                _ = try await Purchases.shared.logOut()
            } catch {
                #if DEBUG
                print("🔍 [SubscriptionManager] logoutUser error: \(error)")
                #endif
            }
            isPremium = false
        }
    }

    // MARK: - 恢复购买
    func restorePurchases() async -> Bool {
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = info.entitlements[entitlementId]?.isActive == true
            isPremium = active
            return active
        } catch {
            return false
        }
    }
}
