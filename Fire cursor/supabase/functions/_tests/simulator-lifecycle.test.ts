import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { generateSimulatorLifecycle } from '../_shared/simulator-lifecycle.ts'

Deno.test('simulator lifecycle withdraws after FIRE instead of continuing contributions', () => {
  const result = generateSimulatorLifecycle({
    currentAge: 40,
    currentYear: 2026,
    currentNetWorth: 1_500_000,
    monthlySavings: 10_000,
    annualRealReturn: 0.04,
    retirementSpendingMonthly: 5_000,
    fireNumber: 1_500_000,
    endAge: 42,
  })

  assertEquals(result.path[0].phase, 'fire_reached')
  assertEquals(result.path[1].phase, 'fire_reached')
  assert(result.path[1].net_worth < 1_500_000 + 120_000, 'monthly savings should not continue after FIRE')
})

Deno.test('simulator lifecycle records depletion age when retirement spending is too high', () => {
  const result = generateSimulatorLifecycle({
    currentAge: 60,
    currentYear: 2026,
    currentNetWorth: 300_000,
    monthlySavings: 0,
    annualRealReturn: 0.02,
    retirementSpendingMonthly: 20_000,
    fireNumber: 300_000,
    endAge: 90,
  })

  assert(result.portfolio_depletion_age != null, 'expected portfolio depletion age')
  assert(result.path.some((point) => point.phase === 'depleted'), 'expected depleted phase in path')
})

Deno.test('simulator lifecycle stays accumulating when FIRE is not reached', () => {
  const result = generateSimulatorLifecycle({
    currentAge: 30,
    currentYear: 2026,
    currentNetWorth: 0,
    monthlySavings: 100,
    annualRealReturn: 0.04,
    retirementSpendingMonthly: 8_000,
    fireNumber: 2_400_000,
    endAge: 35,
  })

  assertEquals(result.portfolio_depletion_age, null)
  assert(result.path.every((point) => point.phase === 'accumulating'))
})
