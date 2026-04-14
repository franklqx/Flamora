// Models/FIREAssumptions.swift
//
// Single source of truth for FIRE projection assumptions on the iOS side.
// Mirrors `_shared/fire-assumptions.ts` — keep the two files in sync when values change.
//
// Nominal vs Real usage convention:
//   realAnnualReturn    → "can we retire / how much to save?" (feasibility, PMT preview)
//   nominalAnnualReturn → "what will the portfolio look like in $?" (display projections)

enum FIREAssumptions {
    /// 60/40 portfolio nominal annual return (conservative estimate).
    static let nominalAnnualReturn: Double = 0.07
    /// Real return after 3 % inflation. Used for all feasibility / required-savings math.
    static let realAnnualReturn: Double    = 0.04
    /// Trinity Study safe withdrawal rate.
    static let withdrawalRate: Double      = 0.04
    /// Long-run US CPI estimate.
    static let inflationRate: Double       = 0.03
}
