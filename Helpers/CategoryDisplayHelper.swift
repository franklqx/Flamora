//
//  CategoryDisplayHelper.swift
//  Flamora app
//
//  Centralized category display names and emoji mappings.
//  Converts raw Plaid PFC / subcategory field names into human-readable labels.
//

import Foundation

enum CategoryDisplay {

    // MARK: - Display Name

    /// Converts a raw category/subcategory field name (e.g. "RENT_AND_UTILITIES_RENT")
    /// into a human-readable label (e.g. "Rent").
    static func displayName(_ raw: String) -> String {
        // 1. Try exact match first
        if let exact = exactNames[raw.uppercased()] {
            return exact
        }

        // 2. Try prefix match (longest prefix wins)
        let upper = raw.uppercased()
        for (prefix, name) in prefixNames.sorted(by: { $0.key.count > $1.key.count }) {
            if upper.hasPrefix(prefix) {
                return name
            }
        }

        // 3. Fallback: replace underscores, title-case
        return raw
            .replacingOccurrences(of: "_", with: " ")
            .localizedCapitalized
    }

    /// Exact raw-name → display-name mapping (uppercased keys).
    private static let exactNames: [String: String] = [
        // ── Rent & Utilities ──
        "RENT_AND_UTILITIES_RENT":                "Rent",
        "RENT_AND_UTILITIES_GAS_AND_ELECTRICITY": "Electricity & Gas",
        "RENT_AND_UTILITIES_ELECTRIC":            "Electricity",
        "RENT_AND_UTILITIES_WATER":               "Water",
        "RENT_AND_UTILITIES_SEWAGE_AND_WASTE":    "Sewage & Waste",
        "RENT_AND_UTILITIES_INTERNET_AND_CABLE":  "Internet & Cable",
        "RENT_AND_UTILITIES_TELEPHONE":           "Phone",
        "RENT_AND_UTILITIES_OTHER_UTILITIES":     "Other Utilities",

        // ── Transportation ──
        "TRANSPORTATION_CAR_INSURANCE":           "Car Insurance",
        "TRANSPORTATION_GAS":                     "Gas",
        "TRANSPORTATION_PARKING":                 "Parking",
        "TRANSPORTATION_PUBLIC_TRANSIT":           "Public Transit",
        "TRANSPORTATION_RIDESHARE":               "Rideshare",
        "TRANSPORTATION_TAXIS":                   "Taxis",
        "TRANSPORTATION_TOLLS":                   "Tolls",
        "TRANSPORTATION_OTHER_TRANSPORTATION":    "Other Transport",

        // ── Food & Drink ──
        "FOOD_AND_DRINK_GROCERIES":               "Groceries",
        "FOOD_AND_DRINK_RESTAURANT":              "Dining Out",
        "FOOD_AND_DRINK_COFFEE":                  "Coffee",
        "FOOD_AND_DRINK_FAST_FOOD":               "Fast Food",
        "FOOD_AND_DRINK_DELIVERY":                "Food Delivery",
        "FOOD_AND_DRINK_BAR":                     "Bars & Drinks",
        "FOOD_AND_DRINK_OTHER_FOOD_AND_DRINK":    "Other Food",

        // ── Entertainment ──
        "ENTERTAINMENT_MUSIC":                    "Music",
        "ENTERTAINMENT_MOVIES_AND_TV":            "Movies & TV",
        "ENTERTAINMENT_GAMES":                    "Games",
        "ENTERTAINMENT_SPORTING_EVENTS":          "Sports Events",
        "ENTERTAINMENT_OTHER_ENTERTAINMENT":      "Other Entertainment",

        // ── Shopping ──
        "GENERAL_MERCHANDISE_CLOTHING":           "Clothing",
        "GENERAL_MERCHANDISE_ELECTRONICS":        "Electronics",
        "GENERAL_MERCHANDISE_SPORTING_GOODS":     "Sporting Goods",
        "GENERAL_MERCHANDISE_BOOKSTORES":         "Books",
        "GENERAL_MERCHANDISE_OTHER":              "General Shopping",

        // ── Personal Care & Health ──
        "PERSONAL_CARE_GYMS_AND_FITNESS":         "Gym & Fitness",
        "PERSONAL_CARE_HAIR_AND_BEAUTY":          "Hair & Beauty",
        "PERSONAL_CARE_LAUNDRY_AND_DRY_CLEANING": "Laundry",
        "PERSONAL_CARE_OTHER_PERSONAL_CARE":      "Personal Care",
        "MEDICAL_HEALTH_INSURANCE":               "Health Insurance",
        "MEDICAL_PRESCRIPTIONS":                  "Prescriptions",
        "MEDICAL_DOCTOR":                         "Doctor",
        "MEDICAL_DENTIST":                        "Dentist",
        "MEDICAL_OTHER_MEDICAL":                  "Medical",

        // ── Loans & Debt ──
        "LOAN_PAYMENTS_STUDENT_LOAN":             "Student Loan",
        "LOAN_PAYMENTS_CAR_PAYMENT":              "Car Payment",
        "LOAN_PAYMENTS_CREDIT_CARD_PAYMENT":      "Credit Card Payment",
        "LOAN_PAYMENTS_MORTGAGE":                 "Mortgage",
        "LOAN_PAYMENTS_OTHER_PAYMENT":            "Loan Payment",

        // ── Insurance ──
        "INSURANCE_AUTO":                         "Auto Insurance",
        "INSURANCE_HEALTH":                       "Health Insurance",
        "INSURANCE_LIFE":                         "Life Insurance",
        "INSURANCE_HOME":                         "Home Insurance",
        "INSURANCE_OTHER_INSURANCE":              "Other Insurance",

        // ── Travel ──
        "TRAVEL_FLIGHTS":                         "Flights",
        "TRAVEL_LODGING":                         "Hotels & Lodging",
        "TRAVEL_RENTAL_CARS":                     "Rental Cars",
        "TRAVEL_OTHER_TRAVEL":                    "Other Travel",

        // ── Subscriptions ──
        "SUBSCRIPTION":                           "Subscriptions",
        "SUBSCRIPTION_STREAMING":                 "Streaming",
        "SUBSCRIPTION_SOFTWARE":                  "Software",
        "SUBSCRIPTION_OTHER":                     "Other Subscriptions",

        // ── Top-level categories (flexible subcategories) ──
        "FOOD_AND_DRINK":                         "Food & Drink",
        "ENTERTAINMENT":                          "Entertainment",
        "GENERAL_MERCHANDISE":                    "Shopping",
        "TRANSPORTATION":                         "Transportation",
        "RENT_AND_UTILITIES":                     "Rent & Utilities",
        "PERSONAL_CARE":                          "Personal Care",
        "MEDICAL":                                "Medical",
        "LOAN_PAYMENTS":                          "Loans",
        "INSURANCE":                              "Insurance",
        "TRAVEL":                                 "Travel",
        "RECREATION":                             "Recreation",
        "HOME_IMPROVEMENT":                       "Home Improvement",
        "PETS":                                   "Pets",
        "CHILDCARE":                              "Childcare",
        "EDUCATION":                              "Education",
        "CHARITABLE_DONATIONS":                   "Donations",
        "GOVERNMENT_AND_NON_PROFIT":              "Government & Fees",
        "TRANSFER":                               "Transfers",
        "OTHER":                                  "Other",
        "OTHER_NEEDS":                            "Other Needs",
        "OTHER_WANTS":                            "Other Wants",
    ]

    /// Prefix-based fallback mapping (uppercased prefixes).
    private static let prefixNames: [String: String] = [
        "RENT_AND_UTILITIES":   "Utilities",
        "FOOD_AND_DRINK":       "Food & Drink",
        "TRANSPORTATION":       "Transportation",
        "ENTERTAINMENT":        "Entertainment",
        "GENERAL_MERCHANDISE":  "Shopping",
        "PERSONAL_CARE":        "Personal Care",
        "MEDICAL":              "Medical",
        "LOAN_PAYMENTS":        "Loan Payment",
        "INSURANCE":            "Insurance",
        "TRAVEL":               "Travel",
        "SUBSCRIPTION":         "Subscription",
    ]

    // MARK: - Emoji

    /// Returns an emoji icon for the given raw category/subcategory name.
    static func emoji(_ raw: String) -> String {
        let lower = raw.lowercased()

        if lower.contains("rent") || lower.contains("mortgage")     { return "🏠" }
        if lower.contains("insurance")                              { return "🛡️" }
        if lower.contains("loan") || lower.contains("debt") ||
           lower.contains("credit_card_payment")                    { return "💳" }
        if lower.contains("car_payment") || lower.contains("auto")
            && !lower.contains("insurance")                         { return "🚗" }
        if lower.contains("gas_and_electric") ||
           lower.contains("electric") || lower.contains("water") ||
           lower.contains("sewage") || lower.contains("other_utilities") { return "⚡" }
        if lower.contains("phone") || lower.contains("internet") ||
           lower.contains("telecom") || lower.contains("telephone") ||
           lower.contains("cable")                                  { return "📱" }
        if lower.contains("groceries") || lower.contains("grocery") { return "🛒" }
        if lower.contains("dining") || lower.contains("restaurant") ||
           lower.contains("food_and_drink") || lower.contains("fast_food") ||
           lower.contains("delivery") || lower.contains("bar")     { return "🍽️" }
        if lower.contains("coffee")                                 { return "☕" }
        if lower.contains("entertainment") || lower.contains("streaming") ||
           lower.contains("movies")                                 { return "🎬" }
        if lower.contains("music")                                  { return "🎵" }
        if lower.contains("games")                                  { return "🎮" }
        if lower.contains("shopping") || lower.contains("retail") ||
           lower.contains("clothing") || lower.contains("merchandise") { return "🛍️" }
        if lower.contains("electronics")                            { return "💻" }
        if lower.contains("fitness") || lower.contains("gym") ||
           lower.contains("health")                                 { return "🏋️" }
        if lower.contains("hair") || lower.contains("beauty")      { return "💇" }
        if lower.contains("travel") || lower.contains("vacation") ||
           lower.contains("flight") || lower.contains("lodging")    { return "✈️" }
        if lower.contains("rideshare") || lower.contains("uber") ||
           lower.contains("lyft") || lower.contains("taxi")        { return "🚕" }
        if lower.contains("transit") || lower.contains("transport") { return "🚇" }
        if lower.contains("gas") || lower.contains("parking") ||
           lower.contains("tolls")                                  { return "⛽" }
        if lower.contains("subscription")                           { return "📦" }
        if lower.contains("education") || lower.contains("book")   { return "📚" }
        if lower.contains("pet")                                    { return "🐾" }
        if lower.contains("child")                                  { return "👶" }
        if lower.contains("donat")                                  { return "❤️" }
        if lower.contains("doctor") || lower.contains("medical") ||
           lower.contains("dentist") || lower.contains("prescription") { return "🏥" }
        if lower.contains("home_improvement")                       { return "🔨" }
        if lower.contains("recreation") || lower.contains("sporting_event") { return "⚽" }

        return "💰"
    }
}
