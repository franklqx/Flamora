// supabase/functions/_shared/fire-math.ts
//
// Shared FIRE date computation utility.
// Used by: get-active-fire-goal, generate-plans, apply-selected-plan, preview-simulator

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
 * @param annualReturnRate Nominal or real annual return rate (e.g. 0.07)
 * @param currentAge       Optional — enables fireAge output
 */
export function computeFireDate(
  currentNetWorth: number,
  fireNumber: number,
  monthlySavings: number,
  annualReturnRate: number = 0.07,
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
  withdrawalRate: number = 0.04
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
