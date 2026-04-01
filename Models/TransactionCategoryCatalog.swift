//
//  TransactionCategoryCatalog.swift
//  Flamora app
//
//  交易子分类与 Needs/Wants 的静态清单（与后端 `flamora_subcategory` 展示名对齐；后续可换为远端配置）。
//

import Foundation

enum TransactionCategoryCatalog {
    static let all: [TransactionCategory] = [
        TransactionCategory(id: "rent", name: "Rent & Housing", icon: "house.fill", parent: "needs"),
        TransactionCategory(id: "grocery", name: "Groceries", icon: "cart.fill", parent: "needs"),
        TransactionCategory(id: "utility", name: "Utilities", icon: "bolt.fill", parent: "needs"),
        TransactionCategory(id: "transit", name: "Transportation", icon: "car.fill", parent: "needs"),
        TransactionCategory(id: "health", name: "Health & Fitness", icon: "cross.case.fill", parent: "needs"),
        TransactionCategory(id: "dining", name: "Dining & Social", icon: "fork.knife", parent: "wants"),
        TransactionCategory(id: "shopping", name: "Shopping", icon: "bag.fill", parent: "wants"),
        TransactionCategory(id: "subs", name: "Subscriptions", icon: "play.tv.fill", parent: "wants"),
        TransactionCategory(id: "travel", name: "Travel", icon: "airplane", parent: "wants"),
        TransactionCategory(id: "hobbies", name: "Hobbies & Leisure", icon: "paintpalette.fill", parent: "wants"),
    ]

    static var needsCategories: [TransactionCategory] { all.filter { $0.parent == "needs" } }
    static var wantsCategories: [TransactionCategory] { all.filter { $0.parent == "wants" } }

    static func parent(for subcategory: String) -> String? {
        all.first(where: { $0.name == subcategory })?.parent
    }
}
