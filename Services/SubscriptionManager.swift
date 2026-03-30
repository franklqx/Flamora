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
        Purchases.configure(withAPIKey: "test_CTvrBqscaqNCibGtSMxCUeXbmae")
    }

    // MARK: - 检查订阅状态
    func checkStatus() async {
        print("🔍 [SubscriptionManager] checkStatus() called")
        do {
            let info = try await Purchases.shared.customerInfo()
            print("🔍 [SubscriptionManager] all entitlements: \(info.entitlements.all.keys)")
            print("🔍 [SubscriptionManager] checking entitlement 'Flamora Pro': \(info.entitlements["Flamora Pro"]?.isActive ?? false)")
            isPremium = info.entitlements[entitlementId]?.isActive == true
            print("🔍 [SubscriptionManager] isPremium = \(isPremium)")
        } catch {
            print("🔍 [SubscriptionManager] ❌ checkStatus error: \(error)")
            isPremium = false
        }
    }

    // MARK: - 登录后关联 RevenueCat 用户
    func loginUser(userId: String) async {
        do {
            _ = try await Purchases.shared.logIn(userId)
            await checkStatus()
        } catch {
            print("RevenueCat login error: \(error)")
        }
    }

    // MARK: - 登出时清除 RevenueCat 状态
    func logoutUser() {
        Task {
            do {
                _ = try await Purchases.shared.logOut()
            } catch {
                print("RevenueCat logout error: \(error)")
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
