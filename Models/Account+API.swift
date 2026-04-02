//
//  Account+API.swift
//  Flamora app
//

import Foundation

/// Allow APIAccount to be used as SwiftUI sheet/fullScreenCover item.
extension APIAccount: Identifiable {}

extension Account {
    /// 由 `get-net-worth-summary` 的 `accounts` 项映射。
    static func fromNetWorthAccount(_ a: APIAccount) -> Account {
        Account(
            id: a.id,
            institution: a.institution ?? "",
            accountType: mapPlaidAccountType(a.type),
            balance: a.balance ?? 0,
            connected: true,
            logoUrl: a.logoUrl
        )
    }

    private static func mapPlaidAccountType(_ type: String) -> AccountType {
        let t = type.lowercased()
        if t.contains("crypto") { return .crypto }
        if t.contains("cash") || t.contains("checking") || t.contains("savings") || t == "bank" || t == "depository" {
            return .bank
        }
        return .brokerage
    }
}
