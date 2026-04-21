// supabase/functions/_shared/spending-stats-core.ts
//
// V3 Budget Module — pure spending-stats algorithm.
// All logic that does not touch auth/db/HTTP lives here so V1 fixtures can
// drive it without spinning up Supabase. The handler in
// `calculate-spending-stats/index.ts` is responsible for I/O only.
//
// Mirrors the V3 plan in `~/.claude/plans/budget-plan-budget-plan-gentle-blossom.md`:
//   - B1: deficit detection + savings rate clamped to ≥ 0
//   - B3: monthly_breakdown rows tagged complete/incomplete (no synthetic fill-in)
//   - B5: no 40/60 manual fallback — caller must provide transactions
//   - B7: median + MAD outlier separation, avgMonthlyExpense uses regular-only median
//   - B8: returns canonical breakdown only; ceiling/save commitments live in generate-plans
//   - essentialFloor = rent + utilities + transportation + medical + groceries × 0.6
//
// Inputs are deliberately denormalized (already-fetched plain objects) so this
// module has no dependency on Supabase types or HTTP runtime.

import {
  ALL_CANONICAL_IDS,
  CANONICAL_PARENT,
  type CanonicalId,
  mapPlaidToCanonical,
} from './plaid-to-canonical.ts'
import { GUARDRAILS } from './budget-guardrails.ts'

// ============================================================
// Public types
// ============================================================

export interface InputTransaction {
  amount: number              // Plaid sign convention: outflow > 0, inflow < 0
  date: string                // ISO yyyy-mm-dd
  name?: string | null
  pfc_primary?: string | null
  pfc_detailed?: string | null
  flamora_category?: string | null      // legacy, ignored when canonical maps
  flamora_subcategory?: string | null   // legacy, ignored when canonical maps
}

export interface SpendingStatsOptions {
  /** Inclusive earliest month in window, e.g. "2025-11". Used to detect missing months. */
  windowStartMonth: string
  /** Inclusive latest month in window, e.g. "2026-04". */
  windowEndMonth: string
  /** Override outlier MAD multiplier (default 3). */
  outlierMadMultiplier?: number
}

export interface CanonicalBreakdownItem {
  canonicalId: CanonicalId | 'uncategorized'
  parent: 'needs' | 'wants' | 'uncategorized'
  avgMonthly: number
  transactionCount: number
}

export interface OneTimeTransaction {
  amount: number
  date: string
  name: string | null
  pfcDetailed: string | null
  canonicalId: CanonicalId | 'uncategorized'
}

export interface MonthlyBreakdownRow {
  month: string                          // "yyyy-mm"
  status: 'complete' | 'incomplete'
  income: number
  needsSpend: number
  wantsSpend: number
  uncategorizedSpend: number
  totalSpend: number
  savings: number
}

export interface SpendingStatsResult {
  // Core monthly figures (regular-only, median-based)
  avgMonthlyIncome: number
  avgMonthlyExpense: number              // median of monthly regular spend
  avgMonthlySavings: number              // income - expense (may be negative)

  // B1: deficit handling
  hasDeficit: boolean
  deficitAmount: number                  // 0 unless deficit
  currentSavingsRate: number             // clamped to [0, 1]

  // V3 Step 5 inputs
  essentialFloor: number
  avgWants: number

  // Canonical category breakdown (10 + uncategorized)
  canonicalBreakdown: CanonicalBreakdownItem[]
  uncategorizedShareOfSpend: number      // 0..1 (avg-monthly basis)

  // B7: outlier separation
  oneTimeTransactions: OneTimeTransaction[]
  outlierThreshold: number               // dollar threshold used (median + 3·MAD)

  // B3: window coverage
  monthlyBreakdown: MonthlyBreakdownRow[]
  monthsAnalyzed: number                 // count of "complete" months
  monthsInWindow: number                 // total months in [start, end]

  // Bookkeeping
  totalRegularTransactions: number
  totalOneTimeTransactions: number
}

// ============================================================
// Helpers
// ============================================================

function getMonthKey(dateStr: string): string {
  return dateStr.substring(0, 7)
}

/**
 * Enumerate every month in the inclusive window so missing months can be marked
 * `incomplete` instead of silently dropped. Both bounds are "yyyy-mm".
 */
function enumerateMonths(startMonth: string, endMonth: string): string[] {
  const [sy, sm] = startMonth.split('-').map(Number)
  const [ey, em] = endMonth.split('-').map(Number)
  const out: string[] = []
  let y = sy
  let m = sm
  while (y < ey || (y === ey && m <= em)) {
    out.push(`${y}-${String(m).padStart(2, '0')}`)
    m += 1
    if (m > 12) { m = 1; y += 1 }
  }
  return out
}

function median(values: number[]): number {
  if (values.length === 0) return 0
  const sorted = [...values].sort((a, b) => a - b)
  const mid = Math.floor(sorted.length / 2)
  return sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
}

/**
 * Median Absolute Deviation. Used as a robust scale estimator for outlier
 * detection — much less sensitive to the very outliers we want to flag than
 * standard deviation would be.
 */
function mad(values: number[]): number {
  if (values.length === 0) return 0
  const med = median(values)
  return median(values.map(v => Math.abs(v - med)))
}

// ============================================================
// Core function
// ============================================================

/**
 * Compute V3 spending stats from a flat list of transactions.
 *
 * Sign convention: caller passes Plaid-style amounts (outflow > 0, inflow < 0).
 * The function classifies each txn into one of:
 *   - income (pfc_primary INCOME or amount < 0 with non-TRANSFER pfc)
 *   - excluded (TRANSFER_*, BANK_FEES, LOAN_PAYMENTS_CREDIT_CARD_PAYMENT)
 *   - regular spend (mapped to canonical)
 *   - one-time spend (separated by MAD outlier rule on per-txn amounts)
 *   - uncategorized spend (no PFC mapping; counted in totals, surfaced separately)
 */
export function computeSpendingStats(
  transactions: InputTransaction[],
  options: SpendingStatsOptions,
): SpendingStatsResult {
  const monthsInWindow = enumerateMonths(options.windowStartMonth, options.windowEndMonth)
  const monthCount = monthsInWindow.length
  const madMultiplier = options.outlierMadMultiplier ?? 3

  // ---------- 1. Partition into income / spend / excluded ----------

  type ClassifiedTxn = InputTransaction & {
    canonical: CanonicalId | 'uncategorized'
    month: string
  }

  const incomeTxns: InputTransaction[] = []
  const spendTxns: ClassifiedTxn[] = []

  for (const txn of transactions) {
    const month = getMonthKey(txn.date)
    const primary = txn.pfc_primary || null
    const detailed = txn.pfc_detailed || null

    // Skip credit card payment double-count: the underlying merchant charges
    // are already counted on the credit card account.
    if (detailed === 'LOAN_PAYMENTS_CREDIT_CARD_PAYMENT') continue

    // Income classification:
    //   - explicit INCOME primary with positive amount, OR
    //   - any negative amount that isn't a transfer-in (Plaid puts payroll deposits as negative)
    const isIncome =
      (primary === 'INCOME' && txn.amount > 0) ||
      (txn.amount < 0 && primary !== 'TRANSFER_IN' && primary !== 'TRANSFER_OUT')
    if (isIncome) {
      incomeTxns.push(txn)
      continue
    }

    // Skip non-spend categories
    if (primary === 'TRANSFER_IN' || primary === 'TRANSFER_OUT' || primary === 'BANK_FEES') continue

    // Anything left should be a spend; require positive amount
    if (txn.amount <= 0) continue

    const canonical = mapPlaidToCanonical(primary, detailed)
    if (canonical === null) continue   // mapper says "exclude from spend"
    spendTxns.push({ ...txn, canonical, month })
  }

  // ---------- 2. Income aggregation (monthly) ----------

  const incomeByMonth = new Map<string, number>()
  for (const txn of incomeTxns) {
    const m = getMonthKey(txn.date)
    incomeByMonth.set(m, (incomeByMonth.get(m) || 0) + Math.abs(txn.amount))
  }

  // ---------- 3. Outlier separation — per-category MAD (B7) ----------
  //
  // Global MAD on all txn amounts flags recurring rent as one-time because
  // rent dwarfs dining/groceries in scale (see V6.4 fixtures:
  // monthly-rent-increase must NOT flag the new rent; one-vacation MUST flag
  // the $3k travel txn even though it shares a category with $50 cabs).
  //
  // Fix: group by canonical category, compute median + k·MAD of that
  // category's per-txn amounts. A txn is one-time iff it exceeds its own
  // category's threshold. Categories with < 3 observations fall back to the
  // global MAD threshold so a one-off vacation in a category that's never
  // recurred still gets flagged.
  //
  // We report a representative threshold in the result (max across
  // categories) for debug/visualization; per-category thresholds are not
  // exposed.

  const byCanonical = new Map<CanonicalId | 'uncategorized', ClassifiedTxn[]>()
  for (const t of spendTxns) {
    const arr = byCanonical.get(t.canonical) || []
    arr.push(t)
    byCanonical.set(t.canonical, arr)
  }

  // Global fallback threshold: catches one-off large purchases in categories
  // that don't have enough samples for per-category MAD (e.g. a single
  // $3,000 vacation in a user with no other travel history). Per-category
  // MAD takes precedence when the category has ≥ 4 observations.
  const allAmounts = spendTxns.map(t => t.amount)
  const globalMedian = median(allAmounts)
  const globalMad = mad(allAmounts)
  const globalThreshold = globalMad > 0 ? globalMedian + madMultiplier * globalMad : Infinity

  const regular: ClassifiedTxn[] = []
  const oneTime: ClassifiedTxn[] = []
  let maxThresholdSeen = 0

  for (const [, txns] of byCanonical) {
    const amounts = txns.map(t => t.amount)
    let threshold: number
    if (amounts.length >= 3) {
      const catMedian = median(amounts)
      const catMad = mad(amounts)
      threshold = catMad > 0 ? catMedian + madMultiplier * catMad : Infinity
    } else {
      threshold = globalThreshold
    }
    if (Number.isFinite(threshold)) maxThresholdSeen = Math.max(maxThresholdSeen, threshold)
    for (const t of txns) {
      if (t.amount > threshold) oneTime.push(t)
      else regular.push(t)
    }
  }
  const outlierThreshold = maxThresholdSeen

  // ---------- 4. Per-month aggregates from regular spend ----------

  const regularSpendByMonth = new Map<string, {
    needs: number; wants: number; uncategorized: number
  }>()
  for (const m of monthsInWindow) {
    regularSpendByMonth.set(m, { needs: 0, wants: 0, uncategorized: 0 })
  }
  for (const t of regular) {
    const slot = regularSpendByMonth.get(t.month)
    if (!slot) continue   // outside window; shouldn't happen if caller filtered
    if (t.canonical === 'uncategorized') {
      slot.uncategorized += t.amount
    } else {
      const parent = CANONICAL_PARENT[t.canonical]
      if (parent === 'needs') slot.needs += t.amount
      else slot.wants += t.amount
    }
  }

  // ---------- 5. Monthly breakdown rows (B3 status flag) ----------
  //
  // A month is "complete" iff at least one regular spend or income transaction
  // was observed. Months with neither are "incomplete" — caller must not treat
  // those as zero-spend months when averaging.

  const observedMonths = new Set<string>()
  for (const t of regular) observedMonths.add(t.month)
  for (const t of incomeTxns) observedMonths.add(getMonthKey(t.date))

  const monthlyBreakdown: MonthlyBreakdownRow[] = monthsInWindow.map(month => {
    const slot = regularSpendByMonth.get(month) || { needs: 0, wants: 0, uncategorized: 0 }
    const totalSpend = slot.needs + slot.wants + slot.uncategorized
    const income = incomeByMonth.get(month) || 0
    const status = observedMonths.has(month) ? 'complete' : 'incomplete'
    return {
      month,
      status,
      income,
      needsSpend: slot.needs,
      wantsSpend: slot.wants,
      uncategorizedSpend: slot.uncategorized,
      totalSpend,
      savings: income - totalSpend,
    }
  })

  const completeMonths = monthlyBreakdown.filter(m => m.status === 'complete')
  const monthsAnalyzed = completeMonths.length || 1   // avoid div-by-zero downstream

  // ---------- 6. Median monthly aggregates ----------
  //
  // Use median of completeMonths (not mean) — robust to single bad months.
  // This is the V3 contract: avgMonthlyExpense = median(monthlyTotals of regular txns).

  const avgMonthlyIncome = median(completeMonths.map(m => m.income))
  const avgMonthlyExpense = median(completeMonths.map(m => m.totalSpend))
  const avgMonthlySavings = avgMonthlyIncome - avgMonthlyExpense

  // ---------- 7. B1 deficit + clamped savings rate ----------

  // hasDeficit fires whenever spending exceeds income, including zero-income
  // users (per V1 zero-income fixture: "不崩, hasDeficit: true"). The all-zero
  // case (no spend either) stays false.
  const hasDeficit = avgMonthlySavings < 0
  const deficitAmount = hasDeficit ? Math.abs(avgMonthlySavings) : 0
  const currentSavingsRate = avgMonthlyIncome > 0
    ? Math.max(0, avgMonthlySavings / avgMonthlyIncome)
    : 0

  // ---------- 8. Canonical breakdown (10 + uncategorized) ----------

  const sumByCanonical = new Map<CanonicalId | 'uncategorized', { total: number; count: number }>()
  for (const t of regular) {
    const cur = sumByCanonical.get(t.canonical) || { total: 0, count: 0 }
    cur.total += t.amount
    cur.count += 1
    sumByCanonical.set(t.canonical, cur)
  }

  const canonicalBreakdown: CanonicalBreakdownItem[] = []
  for (const id of ALL_CANONICAL_IDS) {
    const slot = sumByCanonical.get(id) || { total: 0, count: 0 }
    canonicalBreakdown.push({
      canonicalId: id,
      parent: CANONICAL_PARENT[id],
      avgMonthly: slot.total / monthsAnalyzed,
      transactionCount: slot.count,
    })
  }
  const uncatSlot = sumByCanonical.get('uncategorized') || { total: 0, count: 0 }
  canonicalBreakdown.push({
    canonicalId: 'uncategorized',
    parent: 'uncategorized',
    avgMonthly: uncatSlot.total / monthsAnalyzed,
    transactionCount: uncatSlot.count,
  })

  const totalAvgSpendFromCanonical = canonicalBreakdown.reduce((s, c) => s + c.avgMonthly, 0)
  const uncategorizedShareOfSpend = totalAvgSpendFromCanonical > 0
    ? (uncatSlot.total / monthsAnalyzed) / totalAvgSpendFromCanonical
    : 0

  // ---------- 9. essentialFloor + avgWants ----------

  const avgByCanonical = new Map<CanonicalId | 'uncategorized', number>()
  for (const item of canonicalBreakdown) avgByCanonical.set(item.canonicalId, item.avgMonthly)

  const essentialFloor =
    (avgByCanonical.get('rent') || 0) +
    (avgByCanonical.get('utilities') || 0) +
    (avgByCanonical.get('transportation') || 0) +
    (avgByCanonical.get('medical') || 0) +
    (avgByCanonical.get('groceries') || 0) * GUARDRAILS.groceriesFloorRatio

  const avgWants = canonicalBreakdown
    .filter(c => c.parent === 'wants')
    .reduce((s, c) => s + c.avgMonthly, 0)

  // ---------- 10. Assemble ----------

  return {
    avgMonthlyIncome,
    avgMonthlyExpense,
    avgMonthlySavings,
    hasDeficit,
    deficitAmount,
    currentSavingsRate,
    essentialFloor,
    avgWants,
    canonicalBreakdown,
    uncategorizedShareOfSpend,
    oneTimeTransactions: oneTime.map(t => ({
      amount: t.amount,
      date: t.date,
      name: t.name ?? null,
      pfcDetailed: t.pfc_detailed ?? null,
      canonicalId: t.canonical,
    })),
    outlierThreshold: Number.isFinite(outlierThreshold) ? outlierThreshold : 0,
    monthlyBreakdown,
    monthsAnalyzed,
    monthsInWindow: monthCount,
    totalRegularTransactions: regular.length,
    totalOneTimeTransactions: oneTime.length,
  }
}
