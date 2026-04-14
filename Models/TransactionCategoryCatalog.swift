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
        TransactionCategory(id: "groceries", name: "Groceries", icon: "cart.fill", parent: "needs"),
        TransactionCategory(id: "utilities", name: "Utilities", icon: "bolt.fill", parent: "needs"),
        TransactionCategory(id: "transportation", name: "Transportation", icon: "car.fill", parent: "needs"),
        TransactionCategory(id: "medical", name: "Health & Fitness", icon: "cross.case.fill", parent: "needs"),
        TransactionCategory(id: "dining_out", name: "Dining & Social", icon: "fork.knife", parent: "wants"),
        TransactionCategory(id: "shopping", name: "Shopping", icon: "bag.fill", parent: "wants"),
        TransactionCategory(id: "subscriptions", name: "Subscriptions", icon: "play.tv.fill", parent: "wants"),
        TransactionCategory(id: "travel", name: "Travel", icon: "airplane", parent: "wants"),
        TransactionCategory(id: "entertainment", name: "Hobbies & Leisure", icon: "paintpalette.fill", parent: "wants"),
    ]

    static var needsCategories: [TransactionCategory] { all.filter { $0.parent == "needs" } }
    static var wantsCategories: [TransactionCategory] { all.filter { $0.parent == "wants" } }

    /// Curated manual-review chips do not cover every raw backend key, so aliases collapse multiple
    /// stored keys into a smaller user-facing set.
    private static let rawToCanonicalAliases: [String: String] = [
        "rent": "rent",
        "rent_and_housing": "rent",
        "groceries": "groceries",
        "grocery": "groceries",
        "utilities": "utilities",
        "utility": "utilities",
        "internet": "utilities",
        "phone": "utilities",
        "transportation": "transportation",
        "rideshare": "transportation",
        "insurance": "transportation",
        "loan_payment": "transportation",
        "medical": "medical",
        "health_fitness": "medical",
        "health_and_fitness": "medical",
        "dining_out": "dining_out",
        "shopping": "shopping",
        "subscriptions": "subscriptions",
        "travel": "travel",
        "entertainment": "entertainment",
        "hobbies_leisure": "entertainment",
        "hobbies_and_leisure": "entertainment",
        // Plaid / backend loose keys — map to utilities (needs) so canonical parent + icon resolve;
        // badge color still falls back to `transaction.category` when unknown (see TransactionRow).
        "service": "utilities",
        "services": "utilities",
        "general_services": "utilities",
        "professional_services": "utilities",
        "business_services": "utilities",
        "home_services": "utilities",
    ]

    static func parent(forStoredSubcategory subcategory: String) -> String? {
        guard let canonical = canonicalSubcategory(fromStored: subcategory) else { return nil }
        return all.first(where: { $0.id == canonical })?.parent
    }

    static func parent(forDisplayedSubcategory name: String) -> String? {
        all.first(where: { $0.name == name })?.parent
    }

    static func id(forDisplayedSubcategory name: String) -> String? {
        all.first(where: { $0.name == name })?.id
    }

    static func canonicalSubcategory(fromStored raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if all.contains(where: { $0.id == normalized }) {
            return normalized
        }
        return rawToCanonicalAliases[normalized]
    }

    static func category(forStoredSubcategory raw: String?) -> TransactionCategory? {
        guard let canonical = canonicalSubcategory(fromStored: raw) else { return nil }
        return all.first(where: { $0.id == canonical })
    }

    static func displayName(forStoredSubcategory raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if let category = category(forStoredSubcategory: raw) {
            return category.name
        }
        return CategoryDisplay.displayName(raw)
    }

    static func icon(forStoredSubcategory raw: String?) -> String? {
        category(forStoredSubcategory: raw)?.icon
    }

    static func parent(for subcategory: String) -> String? {
        if let displayMatch = all.first(where: { $0.name == subcategory }) {
            return displayMatch.parent
        }
        return parent(forStoredSubcategory: subcategory)
    }
}
