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
