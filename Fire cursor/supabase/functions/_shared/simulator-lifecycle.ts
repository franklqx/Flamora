export type SimulatorLifecyclePhase =
  | 'accumulating'
  | 'fire_reached'
  | 'withdrawing'
  | 'depleted'

export interface SimulatorLifecyclePoint {
  age: number
  year: number
  net_worth: number
  phase: SimulatorLifecyclePhase
}

export interface SimulatorLifecycleResult {
  path: SimulatorLifecyclePoint[]
  portfolio_depletion_age: number | null
}

export interface SimulatorLifecycleInput {
  currentAge: number
  currentYear?: number
  currentNetWorth: number
  monthlySavings: number
  annualRealReturn: number
  retirementSpendingMonthly: number
  fireNumber: number
  endAge?: number
}

export const SIMULATOR_LIFECYCLE_END_AGE = 90

export function generateSimulatorLifecycle(input: SimulatorLifecycleInput): SimulatorLifecycleResult {
  const currentAge = Math.max(0, Math.floor(input.currentAge))
  const endAge = Math.max(currentAge, input.endAge ?? SIMULATOR_LIFECYCLE_END_AGE)
  const currentYear = input.currentYear ?? new Date().getFullYear()
  const monthlyRate = Math.max(0, input.annualRealReturn) / 12
  const monthlySavings = Math.max(0, input.monthlySavings)
  const retirementSpendingMonthly = Math.max(0, input.retirementSpendingMonthly)
  const fireNumber = Math.max(1, input.fireNumber)
  const totalMonths = Math.max(0, (endAge - currentAge) * 12)

  let portfolio = Math.max(0, input.currentNetWorth)
  let fireReachedMonth: number | null = portfolio >= fireNumber ? 0 : null
  let depletionMonth: number | null = null

  const path: SimulatorLifecyclePoint[] = [
    {
      age: currentAge,
      year: currentYear,
      net_worth: Math.round(portfolio),
      phase: portfolio >= fireNumber ? 'fire_reached' : 'accumulating',
    },
  ]

  for (let month = 1; month <= totalMonths; month++) {
    const isWithdrawing = fireReachedMonth != null

    if (portfolio <= 0 && isWithdrawing) {
      portfolio = 0
    } else if (isWithdrawing) {
      portfolio = portfolio * (1 + monthlyRate) - retirementSpendingMonthly
    } else {
      portfolio = portfolio * (1 + monthlyRate) + monthlySavings
    }

    if (portfolio <= 0) {
      portfolio = 0
      if (depletionMonth == null && isWithdrawing) depletionMonth = month
    }

    if (fireReachedMonth == null && portfolio >= fireNumber) {
      fireReachedMonth = month
    }

    if (month % 12 === 0) {
      const age = currentAge + month / 12
      path.push({
        age,
        year: currentYear + month / 12,
        net_worth: Math.round(portfolio),
        phase: phaseForMonth(month, fireReachedMonth, depletionMonth),
      })
    }
  }

  return {
    path,
    portfolio_depletion_age: depletionMonth == null
      ? null
      : Math.ceil(currentAge + depletionMonth / 12),
  }
}

function phaseForMonth(
  month: number,
  fireReachedMonth: number | null,
  depletionMonth: number | null
): SimulatorLifecyclePhase {
  if (depletionMonth != null && month >= depletionMonth) return 'depleted'
  if (fireReachedMonth == null || month < fireReachedMonth) return 'accumulating'
  if (month <= fireReachedMonth + 12) return 'fire_reached'
  return 'withdrawing'
}
