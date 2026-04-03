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

    /// 由 `get-investment-holdings` 的 `accounts[]` 项映射。
    /// 保留 name（账户名）和 mask（末四位）以供 AccountRow 显示。
    static func fromInvestmentAccount(_ a: APIInvestmentAccount) -> Account {
        Account(
            id: a.id,
            institution: a.institutionName ?? "",
            accountType: .brokerage,
            balance: a.balanceCurrent,
            connected: true,
            logoUrl: nil,
            name: a.name.isEmpty ? nil : a.name,
            mask: a.mask
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
