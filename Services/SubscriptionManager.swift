//
//  SubscriptionManager.swift
//  Meridian
//
//  RevenueCat 订阅状态管理
//

import Foundation
import RevenueCat

@MainActor
@Observable
class SubscriptionManager {
    enum RestoreResult {
        case restored
        case noActivePurchase
        case failed(message: String)
    }

    static let shared = SubscriptionManager()

    var isPremium: Bool = false

    private let entitlementIds = ["Meridian Pro"]

    private init() {}

    // MARK: - App 启动时调用
    static func configure() {
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
    }

    // MARK: - 检查订阅状态
    func checkStatus() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = hasActiveEntitlement(in: info)
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
    func restorePurchases() async -> RestoreResult {
        do {
            let info = try await Purchases.shared.restorePurchases()
            let active = hasActiveEntitlement(in: info)
            isPremium = active
            #if DEBUG
            let activeIds = info.entitlements.active.keys.sorted()
            print("🔍 [SubscriptionManager] restorePurchases — activeEntitlements=\(activeIds), isPremium=\(active)")
            #endif
            return active ? .restored : .noActivePurchase
        } catch {
            #if DEBUG
            print("🔍 [SubscriptionManager] restorePurchases error: \(error)")
            #endif
            return .failed(message: error.localizedDescription)
        }
    }

    func hasActiveEntitlement(in customerInfo: CustomerInfo) -> Bool {
        entitlementIds.contains { customerInfo.entitlements[$0]?.isActive == true }
    }
}
