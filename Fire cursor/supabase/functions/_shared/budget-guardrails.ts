// supabase/functions/_shared/budget-guardrails.ts
//
// V3 Budget Module — single source of truth for plan-generation guardrails.
// Used by: generate-plans (V3), Step 5 custom slider rules.
//
// Tunable here ONLY. Do not inline these values elsewhere.

export const GUARDRAILS = {
  /** Groceries floor as a fraction of historical groceries spend.
   *  40% is treated as compressible (eat-out → home cook); 60% is the unbreakable floor. */
  groceriesFloorRatio: 0.60,

  /** "Comfortable" plan keeps 85% of compressible discretionary spend. */
  comfortableDiscretionaryKeep: 0.85,

  /** "Accelerated" plan keeps 30% of wants. */
  aggressiveWantsKeep: 0.30,

  /** Hard cap on any plan's savings rate, regardless of feasibility. */
  maxSavingsRateCap: 0.65,

  /** Custom slider lower bound. Range is [min(floor, maxFeasibleSave), maxFeasibleSave].
   *  Hidden entirely for deficit users. */
  minSavingsRateFloor: 0.05,

  /** Real return assumption (7% nominal − 3% inflation). Mirrored in
   *  fire-assumptions.ts as REAL_ANNUAL_RETURN — keep in sync. */
  realReturn: 0.04,

  /** Gap window separating closest_near from closest_far in the primary plan. */
  nearTargetWindowMonths: 36,

  /** Minimum target window. T_months below this is treated as "target too soon"
   *  and short-circuited in computeBudgetPlans (UI Step 4 slider lower bound is currentAge+1
   *  but this is the backend defensive floor). */
  minTargetWindowMonths: 12,

  /** Plan dedupe: drop alt plan if monthly save differs by less than this from primary. */
  meaningfulSaveDiffDollars: 150,

  /** Plan dedupe: drop alt plan if FIRE age differs by less than this from primary. */
  meaningfulFireAgeDiffYears: 1,

  /** Custom slider hidden when (hi - lo) is narrower than this. */
  customSliderMinRangeDollars: 50,

  /** Uncategorized cashflow noise threshold — silent below this fraction of total spend. */
  uncategorizedSilentThreshold: 0.05,

  /** Uncategorized → top-of-page banner above this fraction. */
  uncategorizedBannerThreshold: 0.15,
} as const

export type Guardrails = typeof GUARDRAILS
