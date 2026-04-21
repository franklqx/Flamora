// supabase/functions/_shared/fire-math.ts
//
// Shared FIRE date computation utility.
// Used by: get-active-fire-goal, generate-plans, apply-selected-plan, preview-simulator

import { ASSUMPTIONS } from './fire-assumptions.ts'

export interface FireDateResult {
  yearsRemaining: number        // 0 if already at FIRE
  fireDate: string              // "Mar 2042"
  fireAge: number | null        // null if currentAge not provided
}

const MONTH_NAMES = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
const MAX_MONTHS = 600          // 50-year ceiling

/**
 * Compute the projected FIRE arrival date using month-by-month compound growth.
 *
 * @param currentNetWorth  Current total net worth ($ amount)
 * @param fireNumber       Target FIRE number (25× annual spending rule by default)
 * @param monthlySavings   Net monthly contribution (savings + investment contribution)
 * @param annualReturnRate Annual return rate — use REAL for feasibility, NOMINAL for display projections
 * @param currentAge       Optional — enables fireAge output
 */
export function computeFireDate(
  currentNetWorth: number,
  fireNumber: number,
  monthlySavings: number,
  annualReturnRate: number = ASSUMPTIONS.REAL_ANNUAL_RETURN,
  currentAge?: number
): FireDateResult {
  // Already at or past FIRE
  if (currentNetWorth >= fireNumber) {
    return {
      yearsRemaining: 0,
      fireDate: arrivalDateFromMonths(0),
      fireAge: currentAge ?? null,
    }
  }

  // Can't reach FIRE with zero / negative savings
  if (monthlySavings <= 0) {
    return {
      yearsRemaining: 99,
      fireDate: 'Unknown',
      fireAge: null,
    }
  }

  const monthlyRate = annualReturnRate / 12
  let portfolio = currentNetWorth
  let months = 0

  while (portfolio < fireNumber && months < MAX_MONTHS) {
    portfolio = portfolio * (1 + monthlyRate) + monthlySavings
    months++
  }

  const yearsRemaining = Math.ceil(months / 12)
  return {
    yearsRemaining,
    fireDate: arrivalDateFromMonths(months),
    fireAge: currentAge != null ? currentAge + yearsRemaining : null,
  }
}

/**
 * Compute the FIRE number from desired monthly retirement spending.
 * Default: 25× annual spending (4% safe withdrawal rate).
 */
export function computeFireNumber(
  retirementSpendingMonthly: number,
  withdrawalRate: number = ASSUMPTIONS.WITHDRAWAL_RATE
): number {
  const annualSpending = retirementSpendingMonthly * 12
  return Math.round(annualSpending / withdrawalRate)
}

/**
 * One-line progress status copy for Hero.
 */
export function getProgressStatus(progressPct: number, onTrack: boolean): string {
  if (progressPct >= 90) return "You're almost there. Keep going."
  if (progressPct >= 60) return "Strong progress. Your path is working."
  if (progressPct >= 30 && onTrack) return "Your current path is improving."
  if (progressPct >= 30) return "You're building momentum."
  if (progressPct >= 10) return "Early days. Every month counts."
  return "Your FIRE journey starts here."
}

/**
 * Positioning copy for Steady / Recommended / Accelerate plans.
 */
export function getPositioningCopy(planType: 'steady' | 'recommended' | 'accelerate'): string {
  switch (planType) {
    case 'steady':      return 'Closest to how you live today.'
    case 'recommended': return 'A realistic step that moves FIRE meaningfully closer.'
    case 'accelerate':  return 'The fastest path, with real tradeoffs.'
  }
}

/**
 * Build a concise tradeoff note for a plan.
 * e.g. "+$420/mo saved. FIRE 3.2 years sooner."
 */
export function buildTradeoffNote(
  extraPerMonth: number,
  baselineYearsRemaining: number,
  planYearsRemaining: number
): string {
  const yearsSaved = baselineYearsRemaining - planYearsRemaining

  if (extraPerMonth <= 0) {
    return planYearsRemaining < 99
      ? `No extra savings needed. FIRE in ~${planYearsRemaining} years.`
      : 'Based on your current savings rate.'
  }

  const extraFmt = `+$${Math.round(extraPerMonth).toLocaleString()}/mo`

  if (yearsSaved <= 0) {
    return `${extraFmt} more saved. Builds a stronger safety margin.`
  }

  const yearsLabel = yearsSaved === 1 ? '1 year sooner' : `${yearsSaved} years sooner`
  return `${extraFmt} more saved. FIRE ${yearsLabel}.`
}

/**
 * Generate annual net-worth snapshots for the simulator graph.
 */
export function generateGraphSeries(
  currentNetWorth: number,
  monthlySavings: number,
  annualReturnRate: number,
  horizonYears: number
): Array<{ year: number; net_worth: number }> {
  const monthlyRate = annualReturnRate / 12
  const currentYear = new Date().getFullYear()
  const points: Array<{ year: number; net_worth: number }> = []
  let portfolio = currentNetWorth

  for (let y = 0; y <= horizonYears; y++) {
    points.push({ year: currentYear + y, net_worth: Math.round(portfolio) })
    for (let m = 0; m < 12; m++) {
      portfolio = portfolio * (1 + monthlyRate) + monthlySavings
    }
  }

  return points
}

// ---- Internal helpers ----

function arrivalDateFromMonths(monthsFromNow: number): string {
  const d = new Date()
  d.setMonth(d.getMonth() + monthsFromNow)
  return `${MONTH_NAMES[d.getMonth()]} ${d.getFullYear()}`
}

// ============================================================================
// V3 Budget Module — closed-form FIRE math
// ============================================================================
//
// Used by: generate-plans (V3 rewrite), Step 5/6 ETA, iOS FIREMath.swift mirror.
//
// Why a second pair of functions instead of refactoring computeFireDate:
//   - computeFireDate uses iterative monthly compounding with a 600-month ceiling and
//     returns formatted strings for the legacy 3-plan UI. Many callers depend on it.
//   - V3 needs a numeric months-to-FIRE for math composition and a closed-form
//     solveRequiredSave for the inverse direction. Closed-form is also faster.
//   - Once V3 ships and legacy callers migrate, computeFireDate can be retired.
//
// Cross-runtime alignment: mirror in Helpers/FIREMath.swift; covered by
// _tests/fire-math-alignment.test.ts and FlamoraTests/FIREMathTests.swift.

/**
 * Months to reach `fireNumber` from `netWorth`, contributing `monthlySave` per month
 * at `annualRealReturn` (e.g. 0.04). Closed-form solution of FV(n) = fireNumber.
 *
 * Boundary handling:
 *   - `netWorth >= fireNumber` → 0 (already there)
 *   - Otherwise the math handles save = 0 correctly via compounding alone:
 *     when `den = netWorth * r > 0`, result = ln(FV/PV) / ln(1+r).
 *   - `den <= 0` → Infinity (no growth path: zero NW & no save, or decumulation
 *     exceeds compounding). This is the rigorous "unreachable" predicate.
 *
 * NOTE: An earlier draft short-circuited `monthlySave <= 0 → Infinity`. That was
 * wrong for users with positive net worth who stop saving — compounding alone
 * still reaches FIRE in finite time. The `den <= 0` check covers the truly
 * impossible cases.
 */
export function monthsToFIRE(
  netWorth: number,
  monthlySave: number,
  fireNumber: number,
  annualRealReturn: number
): number {
  if (netWorth >= fireNumber) return 0
  const r = annualRealReturn / 12
  const num = fireNumber * r + monthlySave
  const den = netWorth * r + monthlySave
  if (den <= 0) return Infinity
  if (num <= 0) return Infinity  // pathological: save so negative that even FV*r can't offset
  return Math.log(num / den) / Math.log(1 + r)
}

/**
 * Required monthly save to reach `fireNumber` in exactly `targetMonths` months,
 * starting from `netWorth` at `annualRealReturn`. Closed-form inverse of FV.
 *
 * Returns 0 if already at FIRE. Returns Infinity if targetMonths is non-positive
 * (window invalid — caller should treat as "target unreachable").
 */
export function solveRequiredSave(
  netWorth: number,
  targetMonths: number,
  fireNumber: number,
  annualRealReturn: number
): number {
  if (netWorth >= fireNumber) return 0
  if (targetMonths <= 0) return Infinity
  const r = annualRealReturn / 12
  const growth = Math.pow(1 + r, targetMonths)
  const num = (fireNumber - netWorth * growth) * r
  const den = growth - 1
  return Math.max(0, num / den)
}
