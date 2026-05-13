//
//  NumberFormatter+App.swift
//  Meridian
//
//  Shared number and date formatting utilities.
//  Replaces duplicated compactCurrency() in legacy Home shell and formatCurrency() in SimulatorView.
//

import Foundation

// MARK: - NumberFormatter

extension NumberFormatter {

    /// Compact dollar string: $1.2M / $34K / $890
    static func compactCurrency(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000    { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    /// Full currency string with no decimals: $12,345
    /// Used by SimulatorView slider labels and Home prototype cards.
    /// Named `appCurrency` (not `currency`) to avoid clashing with Foundation `NumberFormatter` APIs.
    static func appCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - DateFormatter

extension DateFormatter {

    /// Returns current month as "yyyy-MM" (e.g. "2026-04").
    static var currentMonthString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }
}
