// supabase/functions/_tests/plan-generation.test.ts
//
// V4 regression suite for the V3 plan generator.
// Locks the contract from budget-plan-budget-plan-gentle-blossom.md:
//   - exact / closest_near / closest_far / already_fire truthfulness
//   - deficit and target-too-soon short-circuits
//   - dedupe of near-identical alternative plans
//   - custom slider bounds / hidden cases

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  computeBudgetPlans,
  deriveCustomSliderRange,
  type PlanInput,
} from '../_shared/plan-generator.ts'

function makeInput(overrides: Partial<PlanInput> = {}): PlanInput {
  return {
    targetAge: 50,
    currentAge: 30,
    netWorth: 150_000,
    avgIncome: 6_000,
    avgSpend: 3_000,
    essentialFloor: 1_800,
    avgWants: 1_200,
    retirementSpending: 2_500,
    currentMonthlySave: 3_000,
    withdrawalRate: 0.04,
    realReturn: 0.04,
    ...overrides,
  }
}

Deno.test('target feasible, primary is exact and returns dynamic alternatives', () => {
  const plans = computeBudgetPlans(makeInput())
  assertEquals(plans[0].feasibility, 'exact')
  assert(plans.length >= 2)
  assert(plans.length <= 3)
})

Deno.test('easy target: lifestyle plan that beats target is labeled as early, not still hitting', () => {
  const input = makeInput({
    targetAge: 40,
    currentAge: 28,
    netWorth: 250_000,
    avgIncome: 10_000,
    avgSpend: 2_447,
    essentialFloor: 3_500,
    avgWants: 0,
    retirementSpending: 3_550,
    currentMonthlySave: 7_553,
  })
  const plans = computeBudgetPlans(input)
  const primary = plans[0]
  const lifestyle = plans.find((plan) => plan.anchor === 'lifestyle')

  assertEquals(primary.feasibility, 'exact')
  assertEquals(primary.fireAge, input.targetAge)
  assert(lifestyle, 'expected a lifestyle alternative')
  assert(lifestyle.monthlySave > primary.monthlySave)
  assert(lifestyle.fireAge < input.targetAge)
  assert(lifestyle.badge?.includes('before target'))
  assert(!lifestyle.badge?.includes('Still'))
})

Deno.test('target infeasible due to guardrails returns closest_* primary', () => {
  const plans = computeBudgetPlans(makeInput({
    targetAge: 35,
    netWorth: 10_000,
    avgIncome: 4_000,
    avgSpend: 2_500,
    essentialFloor: 1_800,
    avgWants: 700,
    retirementSpending: 2_500,
  }))

  assert(plans[0].feasibility === 'closest_near' || plans[0].feasibility === 'closest_far')
  assertEquals(plans[0].monthlySave, 2_200)
})

Deno.test('already at FIRE short-circuits to one already_fire plan', () => {
  const plans = computeBudgetPlans(makeInput({
    netWorth: 1_000_000,
    retirementSpending: 2_500,
  }))

  assertEquals(plans.length, 1)
  assertEquals(plans[0].feasibility, 'already_fire')
  assertEquals(plans[0].monthlySave, 0)
  assertEquals(plans[0].fireAgeMonths, 0)
})

Deno.test('deficit short-circuits to one closest_far plan with save = 0', () => {
  const plans = computeBudgetPlans(makeInput({
    netWorth: 0,
    avgIncome: 1_500,
    avgSpend: 2_500,
    essentialFloor: 1_800,
    avgWants: 700,
    retirementSpending: 2_000,
  }))

  assertEquals(plans.length, 1)
  assertEquals(plans[0].feasibility, 'closest_far')
  assertEquals(plans[0].reason, 'deficit')
  assertEquals(plans[0].monthlySave, 0)
})

Deno.test('targetAge <= currentAge non-deficit returns target_too_soon with max feasible save', () => {
  const plans = computeBudgetPlans(makeInput({
    targetAge: 30,
    avgIncome: 4_000,
    avgSpend: 2_600,
    essentialFloor: 1_800,
    avgWants: 800,
    retirementSpending: 2_200,
  }))

  assertEquals(plans.length, 1)
  assertEquals(plans[0].feasibility, 'closest_far')
  assertEquals(plans[0].reason, 'target_too_soon')
  assertEquals(plans[0].monthlySave, 2_200)
})

Deno.test('overlapping alternatives dedupe to fewer than three plans', () => {
  const plans = computeBudgetPlans(makeInput({
    avgIncome: 4_000,
    avgSpend: 1_850,
    essentialFloor: 1_800,
    avgWants: 50,
    retirementSpending: 1_800,
  }))

  assert(plans.length < 3, `expected dedupe to collapse plans, got ${plans.length}`)
})

Deno.test('custom slider range clamps to [min(5%, maxFeasible), maxFeasible]', () => {
  const input = makeInput({
    avgIncome: 2_000,
    avgSpend: 1_950,
    essentialFloor: 1_910,
    avgWants: 40,
    retirementSpending: 1_700,
  })
  const plans = computeBudgetPlans(input)
  const slider = deriveCustomSliderRange(input, plans[0])

  assertEquals(slider.isAvailable, false)
  assertEquals(slider.minMonthlySave, null)
  assertEquals(slider.maxMonthlySave, null)
})

Deno.test('already_fire hides custom slider', () => {
  const input = makeInput({
    netWorth: 2_000_000,
    retirementSpending: 2_000,
  })
  const plans = computeBudgetPlans(input)
  const slider = deriveCustomSliderRange(input, plans[0])

  assertEquals(plans[0].feasibility, 'already_fire')
  assertEquals(slider.isAvailable, false)
  assertEquals(slider.minMonthlySave, null)
  assertEquals(slider.maxMonthlySave, null)
})

// ---- Invariants: locks contracts the UI + backend rely on ----

Deno.test('invariant: savingsRate × avgIncome ≈ monthlySave for every plan', () => {
  const inputs: PlanInput[] = [
    makeInput(),                                            // exact
    makeInput({ targetAge: 35, avgIncome: 4_000, avgSpend: 2_500, essentialFloor: 1_800, avgWants: 700 }),   // closest_*
    makeInput({ avgIncome: 4_000, avgSpend: 1_850, essentialFloor: 1_800, avgWants: 50 }),                   // dedupe
  ]
  for (const input of inputs) {
    const plans = computeBudgetPlans(input)
    for (const plan of plans) {
      if (plan.feasibility === 'already_fire') continue
      const derived = plan.savingsRate * input.avgIncome
      const diff = Math.abs(derived - plan.monthlySave)
      assert(
        diff < 1e-6,
        `plan ${plan.label}: savingsRate×income (${derived}) !== monthlySave (${plan.monthlySave})`,
      )
    }
  }
})

Deno.test('invariant: monthlySpendCeiling + monthlySave ≈ avgIncome (non already_fire)', () => {
  const plans = computeBudgetPlans(makeInput())
  for (const plan of plans) {
    if (plan.feasibility === 'already_fire') continue
    const sum = plan.monthlySpendCeiling + plan.monthlySave
    const diff = Math.abs(sum - 6_000)
    assert(diff < 1e-6, `${plan.label}: ceiling+save ${sum} != income 6000`)
  }
})

Deno.test('invariant: fireNumber === retirementSpending × 12 / withdrawalRate', () => {
  const input = makeInput({ retirementSpending: 4_200, withdrawalRate: 0.04 })
  const plans = computeBudgetPlans(input)
  const expected = 4_200 * 12 / 0.04    // 1_260_000
  assertEquals(plans[0].fireNumber, expected)
})

Deno.test('high-earner + $1.5M NW + $5k retirementSpending → already_fire', () => {
  // Mirrors high-earner-near-fire fixture: avgIncome 15k, spend 4.5k,
  // essentialFloor 3080, avgWants 1100, retirementSpending 5k → FN = $1.5M.
  const plans = computeBudgetPlans(makeInput({
    currentAge: 40,
    targetAge: 55,
    netWorth: 1_500_000,
    avgIncome: 15_000,
    avgSpend: 4_500,
    essentialFloor: 3_080,
    avgWants: 1_100,
    retirementSpending: 5_000,
  }))
  assertEquals(plans.length, 1)
  assertEquals(plans[0].feasibility, 'already_fire')
  assertEquals(plans[0].monthlySave, 0)
  assertEquals(plans[0].fireAgeMonths, 0)
  assertEquals(plans[0].fireNumber, 1_500_000)
})

Deno.test('invariant: closest_* primary uses maxFeasibleSave = min(income − floor, income × 65%)', () => {
  // Tight cap path: income − floor = 2200, income × 65% = 2600 → cap = 2200 (essentials_floor).
  let plans = computeBudgetPlans(makeInput({
    targetAge: 35,
    netWorth: 10_000,
    avgIncome: 4_000,
    avgSpend: 2_500,
    essentialFloor: 1_800,
    avgWants: 700,
    retirementSpending: 2_500,
  }))
  assertEquals(plans[0].monthlySave, 2_200)
  assertEquals(plans[0].limitReason, 'essentials_floor')

  // Cap path: income − floor = 4000, income × 65% = 3250 → cap = 3250 (savings_rate_cap).
  plans = computeBudgetPlans(makeInput({
    targetAge: 35,
    netWorth: 10_000,
    avgIncome: 5_000,
    avgSpend: 1_500,
    essentialFloor: 1_000,
    avgWants: 500,
    retirementSpending: 4_000,
  }))
  assertEquals(plans[0].monthlySave, 3_250)
  assertEquals(plans[0].limitReason, 'savings_rate_cap')
})
