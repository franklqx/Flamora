// Helpers/FIREMath.swift
//
// V3 Budget Module — closed-form FIRE math.
// Mirrors `Fire cursor/supabase/functions/_shared/fire-math.ts` (monthsToFIRE / solveRequiredSave).
// Keep both files byte-for-byte equivalent; covered by V3 alignment tests
// (fire-math-alignment.test.ts on Deno side, FIREMathTests.swift on iOS side).

import Foundation

enum FIREMath {

    /// Months to reach `fireNumber` from `netWorth`, contributing `monthlySave` per month
    /// at `annualRealReturn` (e.g. 0.04). Closed-form solution of FV(n) = fireNumber.
    ///
    /// Boundary handling:
    ///   - `netWorth >= fireNumber` → 0 (already there)
    ///   - Otherwise the math handles save = 0 correctly via compounding alone:
    ///     when `den = netWorth * r > 0`, result = ln(FV/PV) / ln(1+r).
    ///   - `den <= 0` → `.infinity` (no growth path: zero NW & no save, or
    ///     decumulation exceeds compounding). Rigorous "unreachable" predicate.
    ///
    /// NOTE: An earlier draft short-circuited `monthlySave <= 0 → .infinity`. That was
    /// wrong for users with positive net worth who stop saving — compounding alone
    /// still reaches FIRE in finite time.
    static func monthsToFIRE(
        netWorth: Double,
        monthlySave: Double,
        fireNumber: Double,
        annualRealReturn: Double
    ) -> Double {
        if netWorth >= fireNumber { return 0 }
        let r = annualRealReturn / 12
        let num = fireNumber * r + monthlySave
        let den = netWorth * r + monthlySave
        if den <= 0 { return .infinity }
        if num <= 0 { return .infinity }
        return log(num / den) / log(1 + r)
    }

    /// Required monthly save to reach `fireNumber` in exactly `targetMonths` months,
    /// starting from `netWorth` at `annualRealReturn`. Closed-form inverse of FV.
    ///
    /// Returns 0 if already at FIRE. Returns `.infinity` if `targetMonths` is non-positive
    /// (window invalid — caller should treat as "target unreachable").
    static func solveRequiredSave(
        netWorth: Double,
        targetMonths: Double,
        fireNumber: Double,
        annualRealReturn: Double
    ) -> Double {
        if netWorth >= fireNumber { return 0 }
        if targetMonths <= 0 { return .infinity }
        let r = annualRealReturn / 12
        let growth = pow(1 + r, targetMonths)
        let num = (fireNumber - netWorth * growth) * r
        let den = growth - 1
        return max(0, num / den)
    }
}
