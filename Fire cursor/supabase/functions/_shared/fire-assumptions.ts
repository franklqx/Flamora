// supabase/functions/_shared/fire-assumptions.ts
//
// Single source of truth for FIRE projection assumptions.
// Change here → all server-side edge functions update automatically.
//
// Nominal vs Real usage convention:
//   REAL_ANNUAL_RETURN  → "can we retire / how much do we need to save?" (feasibility)
//   NOMINAL_ANNUAL_RETURN → "what will the portfolio look like in $?" (display projections)

export const ASSUMPTIONS = {
  /** 60/40 portfolio nominal annual return (conservative estimate). */
  NOMINAL_ANNUAL_RETURN: 0.07,
  /** Real return after 3% inflation. Used for all feasibility / required-savings math. */
  REAL_ANNUAL_RETURN: 0.04,
  /** Trinity Study safe withdrawal rate. */
  WITHDRAWAL_RATE: 0.04,
  /** Long-run US CPI estimate. */
  INFLATION_RATE: 0.03,
} as const
