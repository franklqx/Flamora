// supabase/functions/_shared/plaid-to-canonical.ts
//
// V3 Budget Module — Plaid Personal Finance Category (PFC) → 10 canonical mapping.
// Single source of truth for category routing in calculate-spending-stats and
// generate-plans. Mirrors the 10 canonical categories defined in
// `Models/TransactionCategoryCatalog.swift` on the iOS side.
//
// Mapping precedence:
//   1. detailed override (PFC_DETAILED_OVERRIDES)  — most specific
//   2. primary mapping  (PFC_PRIMARY_TO_CANONICAL)
//   3. uncategorized                               — never silently coerced to wants
//
// `null` returns mean "do not include in spend totals" (income, transfers, fees).

export type CanonicalId =
  | 'rent'
  | 'utilities'
  | 'transportation'
  | 'medical'
  | 'groceries'
  | 'dining_out'
  | 'shopping'
  | 'subscriptions'
  | 'travel'
  | 'entertainment'

export type CanonicalParent = 'needs' | 'wants'

export const CANONICAL_PARENT: Record<CanonicalId, CanonicalParent> = {
  rent: 'needs',
  utilities: 'needs',
  transportation: 'needs',
  medical: 'needs',
  groceries: 'needs',
  dining_out: 'wants',
  shopping: 'wants',
  subscriptions: 'wants',
  travel: 'wants',
  entertainment: 'wants',
}

export const ALL_CANONICAL_IDS: CanonicalId[] = [
  'rent', 'utilities', 'transportation', 'medical', 'groceries',
  'dining_out', 'shopping', 'subscriptions', 'travel', 'entertainment',
]

const PFC_PRIMARY_TO_CANONICAL: Record<string, CanonicalId | null> = {
  RENT_AND_UTILITIES: 'rent',          // detailed will route utilities subtypes
  FOOD_AND_DRINK: 'dining_out',        // detailed will route GROCERIES → groceries
  TRANSPORTATION: 'transportation',
  MEDICAL: 'medical',
  PERSONAL_CARE: 'medical',
  GENERAL_MERCHANDISE: 'shopping',
  HOME_IMPROVEMENT: 'shopping',
  ENTERTAINMENT: 'entertainment',
  TRAVEL: 'travel',
  GENERAL_SERVICES: 'subscriptions',
  LOAN_PAYMENTS: 'transportation',     // student/auto loan default; mortgage overridden below
  GOVERNMENT_AND_NON_PROFIT: 'medical',

  // Excluded from spend totals — income, transfers, fees
  INCOME: null,
  TRANSFER_IN: null,
  TRANSFER_OUT: null,
  BANK_FEES: null,
}

const PFC_DETAILED_OVERRIDES: Record<string, CanonicalId> = {
  // Food
  FOOD_AND_DRINK_GROCERIES: 'groceries',

  // Utilities (default rent-and-utilities primary → 'rent', so reroute the utility subtypes)
  RENT_AND_UTILITIES_GAS_AND_ELECTRICITY: 'utilities',
  RENT_AND_UTILITIES_INTERNET_AND_CABLE: 'utilities',
  RENT_AND_UTILITIES_TELEPHONE: 'utilities',
  RENT_AND_UTILITIES_WATER: 'utilities',
  RENT_AND_UTILITIES_SEWAGE_AND_WASTE_MANAGEMENT: 'utilities',
  RENT_AND_UTILITIES_OTHER_UTILITIES: 'utilities',
  RENT_AND_UTILITIES_RENT: 'rent',

  // Mortgage routes to rent (housing essential), not LOAN_PAYMENTS default 'transportation'
  LOAN_PAYMENTS_MORTGAGE_PAYMENT: 'rent',

  // General services subtypes
  GENERAL_SERVICES_SUBSCRIPTIONS: 'subscriptions',
}

/**
 * Map a Plaid PFC primary + detailed pair to a canonical id.
 *
 * Returns:
 *   - CanonicalId : transaction belongs in spend totals
 *   - null         : transaction excluded from spend (income/transfer/fee)
 *   - 'uncategorized' as a sentinel: transaction is spend but no mapping found
 *
 * Caller treats `null` as "skip" and 'uncategorized' as "include in spend, bucket separately".
 */
export function mapPlaidToCanonical(
  primary: string | null,
  detailed: string | null,
): CanonicalId | 'uncategorized' | null {
  if (detailed && detailed in PFC_DETAILED_OVERRIDES) {
    return PFC_DETAILED_OVERRIDES[detailed]
  }
  if (primary && primary in PFC_PRIMARY_TO_CANONICAL) {
    return PFC_PRIMARY_TO_CANONICAL[primary]   // may be null (excluded)
  }
  return 'uncategorized'
}
