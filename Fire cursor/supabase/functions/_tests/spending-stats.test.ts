// supabase/functions/_tests/spending-stats.test.ts
//
// V1 fixture suite for the V3 spending-stats core. Each fixture freezes a
// realistic input scenario; assertions encode the contract from
// `~/.claude/plans/budget-plan-budget-plan-gentle-blossom.md` § V1.
//
// Run: `deno test Fire\ cursor/supabase/functions/_tests/spending-stats.test.ts --allow-read`

import { assert, assertEquals, assertAlmostEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { computeSpendingStats, type InputTransaction } from "../_shared/spending-stats-core.ts"

interface Fixture {
  windowStartMonth: string
  windowEndMonth: string
  comment?: string
  transactions: InputTransaction[]
}

async function loadFixture(name: string): Promise<Fixture> {
  const path = new URL(`./fixtures/${name}.json`, import.meta.url)
  const text = await Deno.readTextFile(path)
  return JSON.parse(text) as Fixture
}

function getCanonical(result: ReturnType<typeof computeSpendingStats>, id: string) {
  const item = result.canonicalBreakdown.find(c => c.canonicalId === id)
  if (!item) throw new Error(`canonical id ${id} missing from breakdown`)
  return item
}

// ---- normal-6mo: every figure precisely matches by-hand calculation ----

Deno.test("normal-6mo: avgIncome / avgExpense / savings exact", async () => {
  const fx = await loadFixture("normal-6mo")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertEquals(r.avgMonthlyIncome, 5000)
  assertEquals(r.avgMonthlyExpense, 2500)        // rent 1500 + util 100 + groc 400 + dining 300 + shop 200
  assertEquals(r.avgMonthlySavings, 2500)
  assertAlmostEquals(r.currentSavingsRate, 0.5, 1e-9)
  assertEquals(r.hasDeficit, false)
  assertEquals(r.deficitAmount, 0)
  assertEquals(r.monthsAnalyzed, 6)
  assertEquals(r.monthsInWindow, 6)
})

Deno.test("normal-6mo: canonical breakdown by category", async () => {
  const fx = await loadFixture("normal-6mo")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertAlmostEquals(getCanonical(r, "rent").avgMonthly, 1500, 1e-9)
  assertAlmostEquals(getCanonical(r, "utilities").avgMonthly, 100, 1e-9)
  assertAlmostEquals(getCanonical(r, "groceries").avgMonthly, 400, 1e-9)
  assertAlmostEquals(getCanonical(r, "dining_out").avgMonthly, 300, 1e-9)
  assertAlmostEquals(getCanonical(r, "shopping").avgMonthly, 200, 1e-9)
  assertEquals(getCanonical(r, "uncategorized").avgMonthly, 0)
})

Deno.test("normal-6mo: essentialFloor = rent + util + transportation + medical + groceries × 0.6", async () => {
  const fx = await loadFixture("normal-6mo")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  // 1500 + 100 + 0 + 0 + 400*0.6 = 1840
  assertAlmostEquals(r.essentialFloor, 1840, 1e-9)
  assertAlmostEquals(r.avgWants, 500, 1e-9)
})

Deno.test("normal-6mo: per-category MAD = 0 → no one-time outliers", async () => {
  const fx = await loadFixture("normal-6mo")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertEquals(r.oneTimeTransactions.length, 0)
  assertEquals(r.totalRegularTransactions, 30)
})

// ---- deficit: hasDeficit + clamped rate ----

Deno.test("deficit: hasDeficit=true, savings rate clamped to 0", async () => {
  const fx = await loadFixture("deficit")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertEquals(r.avgMonthlyIncome, 2000)
  assertEquals(r.avgMonthlyExpense, 3000)
  assertEquals(r.avgMonthlySavings, -1000)
  assertEquals(r.hasDeficit, true)
  assertEquals(r.deficitAmount, 1000)
  assertEquals(r.currentSavingsRate, 0)         // clamped — never negative
})

// ---- one-large-purchase: exactly one outlier ----

Deno.test("one-large-purchase: oneTimeTransactions.length == 1, regular avg unaffected", async () => {
  const fx = await loadFixture("one-large-purchase")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertEquals(r.oneTimeTransactions.length, 1)
  assertEquals(r.oneTimeTransactions[0].amount, 3000)
  assertEquals(r.oneTimeTransactions[0].canonicalId, "travel")
  // The vacation must NOT contribute to the regular monthly aggregate.
  // Regular spend per month = 80+100+120+100 = 400 → median = 400.
  assertEquals(r.avgMonthlyExpense, 400)
})

// ---- missing-month: B3 status flag ----

Deno.test("missing-month: gaps marked incomplete, monthsAnalyzed = 4", async () => {
  const fx = await loadFixture("missing-month")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  const byMonth = Object.fromEntries(r.monthlyBreakdown.map(m => [m.month, m.status]))
  assertEquals(byMonth["2025-11"], "complete")
  assertEquals(byMonth["2025-12"], "incomplete")
  assertEquals(byMonth["2026-01"], "complete")
  assertEquals(byMonth["2026-02"], "incomplete")
  assertEquals(byMonth["2026-03"], "complete")
  assertEquals(byMonth["2026-04"], "complete")
  assertEquals(r.monthsAnalyzed, 4)
  assertEquals(r.monthsInWindow, 6)
})

Deno.test("missing-month: averages use only complete months", async () => {
  const fx = await loadFixture("missing-month")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  // 4 complete months, each: income 4000, spend 1500+400 = 1900
  assertEquals(r.avgMonthlyIncome, 4000)
  assertEquals(r.avgMonthlyExpense, 1900)
})

// ---- zero-income: must not crash, hasDeficit=true ----

Deno.test("zero-income: returns without crashing, hasDeficit=true", async () => {
  const fx = await loadFixture("zero-income")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertEquals(r.avgMonthlyIncome, 0)
  assertEquals(r.avgMonthlyExpense, 1800)        // rent 1500 + groc 300
  assertEquals(r.hasDeficit, true)
  assertEquals(r.deficitAmount, 1800)
  assertEquals(r.currentSavingsRate, 0)          // income=0 → rate=0 (no division)
})

// ---- all-uncategorized: not silently coerced to wants ----

Deno.test("all-uncategorized: every spend lands in uncategorized bucket, NOT wants", async () => {
  const fx = await loadFixture("all-uncategorized")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  // Per month: 4 × $200 = $800 spend → all uncategorized
  assertEquals(getCanonical(r, "uncategorized").avgMonthly, 800)
  // None of the 10 canonicals received any of it
  for (const id of [
    "rent","utilities","transportation","medical","groceries",
    "dining_out","shopping","subscriptions","travel","entertainment",
  ]) {
    assertEquals(getCanonical(r, id).avgMonthly, 0, `${id} should be 0 — uncategorized must not bleed into wants`)
  }
  assertEquals(r.avgWants, 0)
  assertAlmostEquals(r.uncategorizedShareOfSpend, 1.0, 1e-9)
})

// ---- guardrail: round-trip over canonical breakdown ----

Deno.test("breakdown invariant: Σ(canonical avgMonthly) == avgMonthlyExpense within rounding (normal-6mo)", async () => {
  const fx = await loadFixture("normal-6mo")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  const sum = r.canonicalBreakdown.reduce((s, c) => s + c.avgMonthly, 0)
  assertAlmostEquals(sum, r.avgMonthlyExpense, 1e-9)
})

// ---- high-earner-near-fire: mirrors a high-income comfortable spender ----

Deno.test("high-earner-near-fire: income/expense/savings exact", async () => {
  const fx = await loadFixture("high-earner-near-fire")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertEquals(r.avgMonthlyIncome, 15000)
  // 2000 rent + 200 util + 400 transp + 800 groc + 500 dining + 300 shop + 100 subs + 200 ent = 4500
  assertEquals(r.avgMonthlyExpense, 4500)
  assertEquals(r.avgMonthlySavings, 10500)
  assertAlmostEquals(r.currentSavingsRate, 0.7, 1e-9)
  assertEquals(r.hasDeficit, false)
})

Deno.test("high-earner-near-fire: essentialFloor + avgWants", async () => {
  const fx = await loadFixture("high-earner-near-fire")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  // 2000 + 200 + 400 + 0 + 800*0.6 = 3080
  assertAlmostEquals(r.essentialFloor, 3080, 1e-9)
  // 500 + 300 + 100 + 0 + 200 = 1100
  assertAlmostEquals(r.avgWants, 1100, 1e-9)
})

Deno.test("high-earner-near-fire: canonical breakdown (wants split across 4 subcategories)", async () => {
  const fx = await loadFixture("high-earner-near-fire")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertAlmostEquals(getCanonical(r, "rent").avgMonthly, 2000, 1e-9)
  assertAlmostEquals(getCanonical(r, "utilities").avgMonthly, 200, 1e-9)
  assertAlmostEquals(getCanonical(r, "transportation").avgMonthly, 400, 1e-9)
  assertAlmostEquals(getCanonical(r, "groceries").avgMonthly, 800, 1e-9)
  assertAlmostEquals(getCanonical(r, "dining_out").avgMonthly, 500, 1e-9)
  assertAlmostEquals(getCanonical(r, "shopping").avgMonthly, 300, 1e-9)
  assertAlmostEquals(getCanonical(r, "subscriptions").avgMonthly, 100, 1e-9)
  assertAlmostEquals(getCanonical(r, "entertainment").avgMonthly, 200, 1e-9)
  // Not observed in this fixture:
  assertEquals(getCanonical(r, "medical").avgMonthly, 0)
  assertEquals(getCanonical(r, "travel").avgMonthly, 0)
  assertEquals(getCanonical(r, "uncategorized").avgMonthly, 0)
})

// ---- wants-heavy: verifies avgWants sums across all 5 wants subcategories ----

Deno.test("wants-heavy: avgWants = dining + shopping + subs + travel + entertainment", async () => {
  const fx = await loadFixture("wants-heavy")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  // 600 + 500 + 120 + 200 + 250 = 1670
  assertAlmostEquals(r.avgWants, 1670, 1e-9)
  assertAlmostEquals(getCanonical(r, "dining_out").avgMonthly, 600, 1e-9)
  assertAlmostEquals(getCanonical(r, "shopping").avgMonthly, 500, 1e-9)
  assertAlmostEquals(getCanonical(r, "subscriptions").avgMonthly, 120, 1e-9)
  assertAlmostEquals(getCanonical(r, "travel").avgMonthly, 200, 1e-9)
  assertAlmostEquals(getCanonical(r, "entertainment").avgMonthly, 250, 1e-9)
})

Deno.test("wants-heavy: essentialFloor uses only needs categories", async () => {
  const fx = await loadFixture("wants-heavy")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  // 800 + 100 + 150 + 50 + 400*0.6 = 1340
  assertAlmostEquals(r.essentialFloor, 1340, 1e-9)
})

// ---- big-rent-plus-travel: per-category MAD guards recurring large rent ----

Deno.test("big-rent-plus-travel: recurring $3000 rent NOT flagged as one-time", async () => {
  const fx = await loadFixture("big-rent-plus-travel")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  const rentOutliers = r.oneTimeTransactions.filter(t => t.canonicalId === "rent")
  assertEquals(rentOutliers.length, 0, "rent must never appear in oneTimeTransactions when fully recurring")
  // Rent's per-category MAD is 0 → threshold Infinity → rent stays in regular aggregates.
  assertAlmostEquals(getCanonical(r, "rent").avgMonthly, 3000, 1e-9)
})

Deno.test("big-rent-plus-travel: single $4000 travel IS flagged via global-threshold fallback", async () => {
  const fx = await loadFixture("big-rent-plus-travel")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  assertEquals(r.oneTimeTransactions.length, 1)
  assertEquals(r.oneTimeTransactions[0].amount, 4000)
  assertEquals(r.oneTimeTransactions[0].canonicalId, "travel")
  // Travel is excluded from regular aggregates → avgMonthly = 0 despite the large one-off.
  assertEquals(getCanonical(r, "travel").avgMonthly, 0)
})

Deno.test("big-rent-plus-travel: regular monthly spend unaffected by the one-off travel", async () => {
  const fx = await loadFixture("big-rent-plus-travel")
  const r = computeSpendingStats(fx.transactions, {
    windowStartMonth: fx.windowStartMonth,
    windowEndMonth: fx.windowEndMonth,
  })
  // Every month: 3000 rent + 150 util + 400 groc = 3550. Median = 3550.
  assertEquals(r.avgMonthlyExpense, 3550)
  assertEquals(r.avgMonthlyIncome, 6000)
  assertEquals(r.avgMonthlySavings, 2450)
  // essentialFloor = 3000 + 150 + 0 + 0 + 400*0.6 = 3390
  assertAlmostEquals(r.essentialFloor, 3390, 1e-9)
})

// ---- guardrail: monthly_breakdown rows sum-of-spend matches segment fields ----

Deno.test("monthly_breakdown invariant: needsSpend + wantsSpend + uncategorizedSpend == totalSpend per row", async () => {
  for (const name of [
    "normal-6mo","deficit","one-large-purchase","missing-month","zero-income","all-uncategorized",
    "high-earner-near-fire","wants-heavy","big-rent-plus-travel",
  ]) {
    const fx = await loadFixture(name)
    const r = computeSpendingStats(fx.transactions, {
      windowStartMonth: fx.windowStartMonth,
      windowEndMonth: fx.windowEndMonth,
    })
    for (const row of r.monthlyBreakdown) {
      const sum = row.needsSpend + row.wantsSpend + row.uncategorizedSpend
      assert(
        Math.abs(sum - row.totalSpend) < 1e-9,
        `${name} ${row.month}: segments ${sum} != totalSpend ${row.totalSpend}`,
      )
    }
  }
})
