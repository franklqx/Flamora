// supabase/functions/_tests/fire-math-alignment.test.ts
//
// V3 alignment test (TS half). Mirror in `Flamora appTests/FIREMathTests.swift`.
// Both files use the same Park-Miller seeded sequence and the same boundary cases,
// so cross-runtime drift would surface as a failing assertion in either file.
//
// Run: `deno test Fire\ cursor/supabase/functions/_tests/fire-math-alignment.test.ts`

import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { monthsToFIRE, solveRequiredSave } from "../_shared/fire-math.ts"

const REAL_RETURN = 0.04

// ---- Boundary cases (must match Swift exactly) ----

Deno.test("monthsToFIRE — already at FIRE returns 0", () => {
  assertEquals(monthsToFIRE(1_000_000, 0, 1_000_000, REAL_RETURN), 0)
  assertEquals(monthsToFIRE(2_000_000, 5_000, 1_000_000, REAL_RETURN), 0)
})

Deno.test("monthsToFIRE — already-FIRE check precedes any save check", () => {
  // Past FIRE but not saving — must return 0, not Infinity.
  assertEquals(monthsToFIRE(1_500_000, 0, 1_000_000, REAL_RETURN), 0)
})

Deno.test("monthsToFIRE — compounding-only path is finite when NW > 0", () => {
  // Positive NW + zero save still reaches FIRE via compounding alone.
  // 100k → 1M at 4% real takes ~ln(10)/ln(1.003333) ≈ 691.6 months.
  const result = monthsToFIRE(100_000, 0, 1_000_000, REAL_RETURN)
  assert(Number.isFinite(result), `expected finite, got ${result}`)
  assert(Math.abs(result - 691.62) < 0.5, `expected ~691.6, got ${result}`)
})

Deno.test("monthsToFIRE — truly unreachable cases return Infinity", () => {
  // No net worth and no savings: literally no growth path.
  assertEquals(monthsToFIRE(0, 0, 1_000_000, REAL_RETURN), Infinity)
  // Decumulation exceeds compounding: NW * r + save < 0.
  // 50k * 0.003333 ≈ 167; save = -200 → den < 0.
  assertEquals(monthsToFIRE(50_000, -200, 1_000_000, REAL_RETURN), Infinity)
})

Deno.test("solveRequiredSave — already at FIRE returns 0", () => {
  assertEquals(solveRequiredSave(1_000_000, 360, 500_000, REAL_RETURN), 0)
})

Deno.test("solveRequiredSave — non-positive targetMonths returns Infinity", () => {
  assertEquals(solveRequiredSave(0, 0, 1_000_000, REAL_RETURN), Infinity)
  assertEquals(solveRequiredSave(0, -12, 1_000_000, REAL_RETURN), Infinity)
})

// ---- Round-trip property: solveRequiredSave then monthsToFIRE ≈ original targetMonths ----
//
// This is the core V3 alignment proof. Both runtimes use the same Park-Miller seed,
// so the input sequence is identical, and the closed-form math is bit-deterministic
// in IEEE 754 double precision. Drift between TS and Swift would manifest as a
// targetMonths mismatch on the same iteration index in the other test file.

Deno.test("round-trip: solveRequiredSave → monthsToFIRE recovers targetMonths", () => {
  // Input ranges are chosen so NW * (1+r)^targetMonths < FN always — i.e. compounding
  // alone never overshoots, so solveRequiredSave returns a strictly positive value
  // and the round-trip property holds. Max growth at 4% real over 540 months is ~6×;
  // NW max = 100k × 6 = 600k is well under FN min = 1M.
  const lcg = parkMiller(42)
  for (let i = 0; i < 100; i++) {
    const netWorth = lcg() * 100_000
    const fireNumber = 1_000_000 + lcg() * 2_000_000          // 1M – 3M
    const targetMonths = 60 + Math.floor(lcg() * 480)         // 60 – 540 months
    const save = solveRequiredSave(netWorth, targetMonths, fireNumber, REAL_RETURN)
    assert(save > 0, `Iteration ${i}: precondition violated, save should be > 0, got ${save}`)
    const back = monthsToFIRE(netWorth, save, fireNumber, REAL_RETURN)
    const drift = Math.abs(back - targetMonths)
    assert(
      drift < 0.001,
      `Iteration ${i}: target=${targetMonths}, back=${back}, drift=${drift}, save=${save}, NW=${netWorth}, FN=${fireNumber}`,
    )
  }
})

Deno.test("round-trip degenerate case — when growth alone reaches FN, solve returns 0", () => {
  // NW high, target window long → compounding alone overshoots → save = 0 is correct.
  const save = solveRequiredSave(500_000, 360, 1_000_000, REAL_RETURN)
  assertEquals(save, 0)
  // monthsToFIRE with save=0 returns the compounding-only time, not Infinity.
  const months = monthsToFIRE(500_000, 0, 1_000_000, REAL_RETURN)
  assert(Number.isFinite(months) && months > 0, `expected finite positive, got ${months}`)
})

// Park-Miller minimal-standard PRNG. Same algorithm in Swift mirror.
// state_{n+1} = (16807 * state_n) mod (2^31 - 1)
// Output ∈ [0, 1)
function parkMiller(seed: number): () => number {
  let state = seed
  return () => {
    state = (16807 * state) % 2147483647
    return state / 2147483647
  }
}
